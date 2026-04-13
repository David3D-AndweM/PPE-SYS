import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_bloc.dart';
import '../../../injection.dart';
import '../../my_ppe/data/ppe_repository.dart';
import '../data/picking_repository.dart';

/// Priority order for sorting items in the list.
int _statusPriority(String? status) {
  switch (status) {
    case 'expired':       return 0;
    case 'expiring_soon': return 1;
    case 'valid':         return 2;
    default:              return 3;
  }
}

Color _statusColor(String? status) {
  switch (status) {
    case 'expired':       return Colors.red;
    case 'expiring_soon': return Colors.orange;
    case 'valid':         return Colors.green;
    default:              return Colors.grey;
  }
}

String _statusLabel(String? status) {
  switch (status) {
    case 'expired':       return 'EXPIRED';
    case 'expiring_soon': return 'EXPIRING';
    case 'valid':         return 'VALID';
    default:              return '';
  }
}

class CreateSlipScreen extends StatefulWidget {
  const CreateSlipScreen({super.key});

  @override
  State<CreateSlipScreen> createState() => _CreateSlipScreenState();
}

class _CreateSlipScreenState extends State<CreateSlipScreen> {
  String _requestType = 'expiry';
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  bool _loading = true;
  String? _loadError;

  /// Full PPE catalogue from /ppe/items/
  List<Map<String, dynamic>> _catalogue = [];

  /// Employee's current PPE status: ppe_item_id → assignment map
  Map<String, Map<String, dynamic>> _myStatus = {};

  /// Selected quantities: ppe_item_id → qty
  final Map<String, int> _quantities = {};

  static const _requestTypes = [
    ('expiry',  'Expired / Expiring',  Icons.timer_off_outlined,   Colors.red),
    ('lost',    'Lost / Misplaced',    Icons.search_off_outlined,   Colors.orange),
    ('damaged', 'Damaged',             Icons.build_outlined,        Colors.amber),
    ('new',     'New / First Issue',   Icons.add_circle_outline,    Colors.blue),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final repo = sl<PpeRepository>();
      final List<List<Map<String, dynamic>>> results = await Future.wait([
        repo.getPpeItems(),
        repo.getMyPpe(),
      ]);

      final catalogue = results[0];
      final myPpe     = results[1];

      // Build status lookup: ppe_item_id → assignment data
      final statusMap = <String, Map<String, dynamic>>{};
      for (final a in myPpe) {
        final itemId = a['ppe_item'] as String?;
        if (itemId != null) statusMap[itemId] = a;
      }

      // Initialise quantities to 0
      final quantities = <String, int>{};
      for (final item in catalogue) {
        quantities[item['id'] as String] = 0;
      }

      setState(() {
        _catalogue  = catalogue;
        _myStatus   = statusMap;
        _quantities.addAll(quantities);
        _loading    = false;
      });

      // Auto-select expired/expiring items for the default 'expiry' type
      _applySmartSelection();
    } catch (e) {
      setState(() { _loading = false; _loadError = e.toString(); });
    }
  }

  /// For 'expiry' type: pre-select everything expired or expiring.
  /// For manual types (lost/damaged/new): clear all — user chooses.
  void _applySmartSelection() {
    setState(() {
      for (final item in _catalogue) {
        final id     = item['id'] as String;
        // Manual selection is only relevant for exception flows.
        // For expiry/new requests the backend generates items automatically.
        if (_requestType == 'lost' || _requestType == 'damaged') {
          _quantities[id] = 0;
        } else {
          // Keep quantities cleared to avoid implying that UI selection is used.
          _quantities[id] = 0;
        }
      }
    });
  }

  void _onTypeChanged(String type) {
    setState(() => _requestType = type);
    _applySmartSelection();
  }

  List<Map<String, dynamic>> get _sortedItems {
    final items = List<Map<String, dynamic>>.from(_catalogue);
    items.sort((a, b) {
      final sa = _statusPriority(_myStatus[a['id']]?['status'] as String?);
      final sb = _statusPriority(_myStatus[b['id']]?['status'] as String?);
      if (sa != sb) return sa.compareTo(sb);
      // Within same priority: critical items first
      final ca = (a['is_critical'] == true) ? 0 : 1;
      final cb = (b['is_critical'] == true) ? 0 : 1;
      return ca.compareTo(cb);
    });
    return items;
  }

  int get _selectedCount => _quantities.values.where((q) => q > 0).length;

  int get _autoDetectedCount {
    if (_requestType != 'expiry') return 0;
    return _myStatus.values.where((a) {
      final s = a['status'] as String?;
      return s == 'expired' || s == 'expiring_soon';
    }).length;
  }

  bool get _isExceptionFlow => _requestType == 'lost' || _requestType == 'damaged';

  List<Map<String, dynamic>> get _selectedItems => _quantities.entries
      .where((e) => e.value > 0)
      .map((e) => {'ppe_item_id': e.key, 'quantity': e.value})
      .toList();

  void _increment(String id) => setState(() {
        _quantities[id] = (_quantities[id] ?? 0) + 1;
        if (_quantities[id]! > 10) _quantities[id] = 10;
      });

  void _decrement(String id) => setState(() {
        _quantities[id] = (_quantities[id] ?? 0) - 1;
        if (_quantities[id]! < 0) _quantities[id] = 0;
      });

  Future<void> _submit() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated || auth.employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Your account is not linked to an employee record.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _submitting = true);
    try {
      // For standard flows, rely on backend to generate the due items.
      if (_requestType == 'expiry' || _requestType == 'new') {
        await sl<PickingRepository>().autoCreateSlip(
          employeeId: auth.employeeId!,
          requestType: _requestType,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      } else {
        if (_selectedCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Select at least one item before submitting.'),
            backgroundColor: Colors.orange,
          ));
          return;
        }
        await sl<PickingRepository>().createSlip({
          'employee_id': auth.employeeId,
          'request_type': _requestType,
          'notes': _notesCtrl.text.trim(),
          'items': _selectedItems,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request submitted — awaiting approval.'),
          backgroundColor: Colors.green,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Replacement')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Failed to load PPE data', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }

    final sorted = _sortedItems;

    return Scaffold(
      appBar: AppBar(title: const Text('Request PPE Replacement')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [

          // ── Smart detection banner (expiry mode only) ────────────────────
          if (_requestType == 'expiry' && _autoDetectedCount > 0)
            _SmartBanner(
              count: _autoDetectedCount,
              myStatus: _myStatus,
              catalogue: _catalogue,
            ),
          if (_requestType == 'expiry' && _autoDetectedCount == 0 && _myStatus.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text(
                  'All your PPE is current — no expired items detected.',
                  style: TextStyle(fontSize: 13),
                )),
              ]),
            ),

          // ── Request Type ─────────────────────────────────────────────────
          Text('What happened?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...(_requestTypes.map((t) {
            final selected = _requestType == t.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => _onTypeChanged(t.$1),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? t.$4 : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                    color: selected ? t.$4.withValues(alpha: 0.08) : null,
                  ),
                  child: Row(children: [
                    Icon(t.$3, color: selected ? t.$4 : Colors.grey, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      t.$2,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? t.$4 : null,
                      ),
                    ),
                    if (t.$1 == 'expiry' && _autoDetectedCount > 0) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_autoDetectedCount due',
                          style: const TextStyle(color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            );
          })),

          const SizedBox(height: 20),

          // ── Items list ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (_requestType == 'expiry' || _requestType == 'new')
                    ? 'Items will be generated automatically'
                    : 'Select Items',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (_isExceptionFlow && _selectedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_selectedCount selected',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: sorted.asMap().entries.map((entry) {
                final i    = entry.key;
                final item = entry.value;
                final id   = item['id'] as String;
                final qty  = _quantities[id] ?? 0;
                final isCritical = item['is_critical'] == true;
                final assignment = _myStatus[id];
                final status     = assignment?['status'] as String?;
                final expiry     = assignment?['expiry_date'] as String?;
                final isAutoSelected = _requestType == 'expiry' &&
                    (status == 'expired' || status == 'expiring_soon');

                return Column(children: [
                  if (i > 0) const Divider(height: 1),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    color: isAutoSelected
                        ? _statusColor(status).withValues(alpha: 0.06)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [

                        // Left: name, tags, expiry
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Flexible(
                                  child: Text(
                                    item['name'] ?? '',
                                    style: TextStyle(
                                      fontWeight: qty > 0 ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isCritical) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('CRITICAL',
                                        style: TextStyle(fontSize: 9,
                                            color: Colors.red.shade800,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ]),
                              const SizedBox(height: 2),
                              Row(children: [
                                Text(
                                  (item['category'] ?? '').toString().toUpperCase(),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                                // Show status badge if we have data
                                if (status != null && status != 'valid') ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: _statusColor(status).withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      _statusLabel(status),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: _statusColor(status),
                                      ),
                                    ),
                                  ),
                                ],
                              ]),
                              if (expiry != null && (status == 'expired' || status == 'expiring_soon'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Text(
                                    status == 'expired'
                                        ? 'Expired: $expiry'
                                        : 'Expires: $expiry',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _statusColor(status),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Right: stepper
                        if (_isExceptionFlow)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              iconSize: 22,
                              color: qty > 0 ? Colors.red.shade400 : Colors.grey.shade300,
                              onPressed: qty > 0 ? () => _decrement(id) : null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                            SizedBox(
                              width: 30,
                              child: Text(
                                '$qty',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: qty > 0 ? FontWeight.bold : FontWeight.normal,
                                  color: qty > 0
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              iconSize: 22,
                              color: qty < 10
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                              onPressed: qty < 10 ? () => _increment(id) : null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                          ])
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              (status == 'expired' || status == 'expiring_soon' || status == 'pending_issue')
                                  ? 'DUE'
                                  : 'OK',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (status == 'expired' || status == 'expiring_soon' || status == 'pending_issue')
                                    ? Colors.red.shade700
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // ── Notes ────────────────────────────────────────────────────────
          TextFormField(
            controller: _notesCtrl,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: _requestType == 'lost'
                  ? 'e.g. Left hard hat underground, unable to retrieve'
                  : _requestType == 'damaged'
                      ? 'e.g. Harness webbing torn during confined space entry'
                      : 'Any additional information for the approver',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // ── Submit ───────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: (_submitting || (_isExceptionFlow && _selectedCount == 0))
                  ? null
                  : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text(
                _submitting
                    ? 'Submitting...'
                    : (_requestType == 'expiry' || _requestType == 'new')
                        ? 'Submit Smart Request'
                        : 'Submit Request ($_selectedCount item${_selectedCount == 1 ? '' : 's'})',
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),

          if (_isExceptionFlow && _selectedCount == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                (_requestType == 'expiry' || _requestType == 'new')
                    ? 'This request is generated automatically from your PPE status and department rules.'
                    : 'Adjust quantities above to enable submit.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Smart detection banner ────────────────────────────────────────────────

class _SmartBanner extends StatelessWidget {
  final int count;
  final Map<String, Map<String, dynamic>> myStatus;
  final List<Map<String, dynamic>> catalogue;

  const _SmartBanner({
    required this.count,
    required this.myStatus,
    required this.catalogue,
  });

  @override
  Widget build(BuildContext context) {
    // Collect the names of detected items
    final detectedNames = <String>[];
    for (final item in catalogue) {
      final id     = item['id'] as String;
      final status = myStatus[id]?['status'] as String?;
      if (status == 'expired' || status == 'expiring_soon') {
        detectedNames.add(item['name'] as String? ?? '');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count item${count == 1 ? '' : 's'} detected as due for renewal',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade800,
                fontSize: 13,
              ),
            ),
          ),
        ]),
        if (detectedNames.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            detectedNames.join(' · '),
            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Submitting will create a smart request. The backend generates the slip items automatically from your PPE status and department rules.',
          style: TextStyle(fontSize: 12, color: Colors.red.shade600),
        ),
      ]),
    );
  }
}
