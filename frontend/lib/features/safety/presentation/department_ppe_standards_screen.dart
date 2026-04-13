import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../injection.dart';

class DepartmentPpeStandardsScreen extends StatefulWidget {
  const DepartmentPpeStandardsScreen({super.key});

  @override
  State<DepartmentPpeStandardsScreen> createState() =>
      _DepartmentPpeStandardsScreenState();
}

class _DepartmentPpeStandardsScreenState
    extends State<DepartmentPpeStandardsScreen> {
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _ppeItems = [];
  final Map<String, Map<String, dynamic>> _requirementsByPpeItem = {};
  final Map<String, _DraftRequirement> _draftByPpeItem = {};
  final Set<String> _dirtyPpeItemIds = {};
  String? _selectedDepartmentId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        sl<ApiClient>().get(Endpoints.departments),
        sl<ApiClient>().get(Endpoints.ppeItems),
      ]);

      final departmentsData = results[0].data as Map<String, dynamic>;
      final ppeData = results[1].data as Map<String, dynamic>;

      final departments =
          (departmentsData['results'] as List).cast<Map<String, dynamic>>();
      final ppeItems =
          (ppeData['results'] as List).cast<Map<String, dynamic>>();

      setState(() {
        _departments = departments;
        _ppeItems = ppeItems;
        _selectedDepartmentId =
            departments.isNotEmpty ? departments.first['id'] as String : null;
      });

      if (_selectedDepartmentId != null) {
        await _loadRequirementsForDepartment(_selectedDepartmentId!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load standards data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadRequirementsForDepartment(String departmentId) async {
    try {
      final response = await sl<ApiClient>().get(
        Endpoints.ppeRequirements,
        queryParams: {'department': departmentId},
      );
      final data = response.data as Map<String, dynamic>;
      final requirements =
          (data['results'] as List).cast<Map<String, dynamic>>();

      _requirementsByPpeItem
        ..clear()
        ..addEntries(
          requirements.map((r) => MapEntry(r['ppe_item'] as String, r)),
        );
      _resetDraftFromCurrentRequirements();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load department requirements: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetDraftFromCurrentRequirements() {
    _draftByPpeItem.clear();
    _dirtyPpeItemIds.clear();
    for (final item in _ppeItems) {
      final ppeItemId = item['id'] as String;
      final existing = _requirementsByPpeItem[ppeItemId];
      _draftByPpeItem[ppeItemId] = _DraftRequirement(
        isRequired: (existing?['is_required'] as bool?) ?? false,
        quantity: ((existing?['quantity'] as int?) ?? 1).clamp(1, 999),
      );
    }
  }

  Future<void> _saveBulk() async {
    if (_selectedDepartmentId == null || _dirtyPpeItemIds.isEmpty) return;
    setState(() => _saving = true);
    try {
      final departmentId = _selectedDepartmentId!;
      final sortedDirtyIds = _dirtyPpeItemIds.toList()..sort();
      for (final ppeItemId in sortedDirtyIds) {
        final existing = _requirementsByPpeItem[ppeItemId];
        final draft = _draftByPpeItem[ppeItemId];
        if (draft == null) continue;
        final payload = {
          'department': departmentId,
          'ppe_item': ppeItemId,
          'is_required': draft.isRequired,
          'quantity': draft.quantity < 1 ? 1 : draft.quantity,
        };
        if (existing != null) {
          await sl<ApiClient>().patch(
            Endpoints.ppeRequirementDetail(existing['id'] as String),
            data: payload,
          );
        } else {
          await sl<ApiClient>().post(Endpoints.ppeRequirements, data: payload);
        }
      }

      await _loadRequirementsForDepartment(_selectedDepartmentId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${sortedDirtyIds.length} PPE standard changes'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save requirement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _updateDraft(String ppeItemId, bool isRequired, int quantity) {
    final next = _DraftRequirement(
      isRequired: isRequired,
      quantity: quantity < 1 ? 1 : quantity,
    );
    _draftByPpeItem[ppeItemId] = next;

    final existing = _requirementsByPpeItem[ppeItemId];
    final originalRequired = (existing?['is_required'] as bool?) ?? false;
    final originalQuantity = (existing?['quantity'] as int?) ?? 1;
    final isDirty = next.isRequired != originalRequired ||
        next.quantity != originalQuantity;
    if (isDirty) {
      _dirtyPpeItemIds.add(ppeItemId);
    } else {
      _dirtyPpeItemIds.remove(ppeItemId);
    }
    setState(() {});
  }

  Future<void> _pickDepartment() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DepartmentPickerSheet(
        departments: _departments,
        selectedDepartmentId: _selectedDepartmentId,
      ),
    );
    if (picked == null || picked == _selectedDepartmentId) return;
    setState(() => _selectedDepartmentId = picked);
    await _loadRequirementsForDepartment(picked);
  }

  Future<void> _copyFromAnotherDepartment() async {
    if (_selectedDepartmentId == null) return;
    final sourceDepartmentId = await showDialog<String>(
      context: context,
      builder: (_) => _CopyFromDepartmentDialog(
        departments: _departments,
        currentDepartmentId: _selectedDepartmentId!,
      ),
    );
    if (sourceDepartmentId == null) return;

    setState(() => _saving = true);
    try {
      final response = await sl<ApiClient>().get(
        Endpoints.ppeRequirements,
        queryParams: {'department': sourceDepartmentId},
      );
      final data = response.data as Map<String, dynamic>;
      final requirements =
          (data['results'] as List).cast<Map<String, dynamic>>();
      final sourceMap = <String, Map<String, dynamic>>{
        for (final r in requirements) r['ppe_item'] as String: r,
      };

      for (final item in _ppeItems) {
        final ppeItemId = item['id'] as String;
        final sourceReq = sourceMap[ppeItemId];
        _updateDraft(
          ppeItemId,
          (sourceReq?['is_required'] as bool?) ?? false,
          (sourceReq?['quantity'] as int?) ?? 1,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Copied standards into draft. Tap Save All to persist.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy standards: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic>? get _selectedDepartment {
    final id = _selectedDepartmentId;
    if (id == null) return null;
    for (final d in _departments) {
      if (d['id'] == id) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Department PPE Standards')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _departments.isEmpty
              ? const Center(
                  child: Text(
                    'No departments available for your role.\n'
                    'Ask admin to assign your department scope.',
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDepartment,
                              icon: const Icon(Icons.apartment_outlined),
                              label: Text(
                                _selectedDepartment == null
                                    ? 'Select Department'
                                    : '${_selectedDepartment!['name']}'
                                        ' (${_selectedDepartment!['site_name'] ?? 'Site'})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed:
                                _saving ? null : _copyFromAnotherDepartment,
                            icon: const Icon(Icons.content_copy_outlined),
                            label: const Text('Copy'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            '${_dirtyPpeItemIds.length} unsaved change(s)',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: (_saving || _dirtyPpeItemIds.isEmpty)
                                ? null
                                : _saveBulk,
                            icon: const Icon(Icons.save),
                            label: const Text('Save All'),
                          ),
                        ],
                      ),
                    ),
                    if (_saving) const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _ppeItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final item = _ppeItems[i];
                          final ppeItemId = item['id'] as String;
                          final draft = _draftByPpeItem[ppeItemId] ??
                              const _DraftRequirement(
                                isRequired: false,
                                quantity: 1,
                              );
                          return _RequirementCard(
                            title: item['name'] as String? ?? 'PPE Item',
                            category: item['category'] as String? ?? '',
                            isRequired: draft.isRequired,
                            quantity: draft.quantity,
                            isDirty: _dirtyPpeItemIds.contains(ppeItemId),
                            onChanged: (requiredValue, quantityValue) =>
                                _updateDraft(
                              ppeItemId,
                              requiredValue,
                              quantityValue,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _RequirementCard extends StatefulWidget {
  final String title;
  final String category;
  final bool isRequired;
  final int quantity;
  final bool isDirty;
  final void Function(bool isRequired, int quantity) onChanged;

  const _RequirementCard({
    required this.title,
    required this.category,
    required this.isRequired,
    required this.quantity,
    required this.isDirty,
    required this.onChanged,
  });

  @override
  State<_RequirementCard> createState() => _RequirementCardState();
}

class _RequirementCardState extends State<_RequirementCard> {
  late bool _isRequired;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _isRequired = widget.isRequired;
    _quantity = widget.quantity < 1 ? 1 : widget.quantity;
  }

  @override
  void didUpdateWidget(covariant _RequirementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRequired != widget.isRequired ||
        oldWidget.quantity != widget.quantity) {
      _isRequired = widget.isRequired;
      _quantity = widget.quantity < 1 ? 1 : widget.quantity;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              widget.category.toUpperCase(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Required'),
                Switch(
                  value: _isRequired,
                  onChanged: (v) {
                    setState(() => _isRequired = v);
                    widget.onChanged(_isRequired, _quantity);
                  },
                ),
                const Spacer(),
                IconButton(
                  onPressed: _quantity > 1
                      ? () {
                          setState(() => _quantity--);
                          widget.onChanged(_isRequired, _quantity);
                        }
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('Qty $_quantity'),
                IconButton(
                  onPressed: () {
                    setState(() => _quantity++);
                    widget.onChanged(_isRequired, _quantity);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                widget.isDirty ? 'Modified' : 'Saved',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isDirty ? Colors.orange.shade800 : Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> departments;
  final String? selectedDepartmentId;

  const _DepartmentPickerSheet({
    required this.departments,
    required this.selectedDepartmentId,
  });

  @override
  State<_DepartmentPickerSheet> createState() => _DepartmentPickerSheetState();
}

class _DepartmentPickerSheetState extends State<_DepartmentPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.departments.where((d) {
      final name = (d['name'] ?? '').toString().toLowerCase();
      final site = (d['site_name'] ?? '').toString().toLowerCase();
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return name.contains(q) || site.contains(q);
    }).toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search department',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final d = filtered[i];
                  final id = d['id'] as String;
                  final selected = id == widget.selectedDepartmentId;
                  return ListTile(
                    selected: selected,
                    leading: Icon(
                      selected ? Icons.radio_button_checked : Icons.apartment,
                    ),
                    title: Text(d['name'] as String? ?? 'Department'),
                    subtitle: Text(d['site_name'] as String? ?? 'Site'),
                    onTap: () => Navigator.pop(context, id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyFromDepartmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> departments;
  final String currentDepartmentId;

  const _CopyFromDepartmentDialog({
    required this.departments,
    required this.currentDepartmentId,
  });

  @override
  State<_CopyFromDepartmentDialog> createState() =>
      _CopyFromDepartmentDialogState();
}

class _CopyFromDepartmentDialogState extends State<_CopyFromDepartmentDialog> {
  String _query = '';
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final candidates = widget.departments.where((d) {
      final id = d['id'] as String;
      if (id == widget.currentDepartmentId) return false;
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      final name = (d['name'] ?? '').toString().toLowerCase();
      final site = (d['site_name'] ?? '').toString().toLowerCase();
      return name.contains(q) || site.contains(q);
    }).toList();

    return AlertDialog(
      title: const Text('Copy Standards From'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search source department',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: ListView.builder(
                itemCount: candidates.length,
                itemBuilder: (_, i) {
                  final d = candidates[i];
                  final id = d['id'] as String;
                  final selected = _selectedId == id;
                  return ListTile(
                    selected: selected,
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    onTap: () => setState(() => _selectedId = id),
                    title: Text(d['name'] as String? ?? 'Department'),
                    subtitle: Text(d['site_name'] as String? ?? 'Site'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedId == null
              ? null
              : () => Navigator.pop(context, _selectedId),
          child: const Text('Copy'),
        ),
      ],
    );
  }
}

class _DraftRequirement {
  final bool isRequired;
  final int quantity;

  const _DraftRequirement({required this.isRequired, required this.quantity});
}
