import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../injection.dart';

class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  bool _exporting = false;
  bool _filterExpanded = false;

  DateTimeRange? _dateRange;
  String? _selectedEntityType;

  static const _entityTypes = [
    'PickingSlip',
    'Approval',
    'User',
    'EmployeePPE',
    'PPEItem',
    'Department',
    'StockTransaction',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _buildQueryParams() {
    final params = <String, dynamic>{};
    if (_dateRange != null) {
      params['from'] = DateFormat('yyyy-MM-dd').format(_dateRange!.start);
      params['to'] = DateFormat('yyyy-MM-dd').format(_dateRange!.end);
    }
    if (_selectedEntityType != null) {
      params['entity_type'] = _selectedEntityType;
    }
    return params;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await sl<ApiClient>().get(
        Endpoints.auditLogs,
        queryParams: _buildQueryParams(),
      );
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _logs = (data['results'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load audit logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final response = await sl<ApiClient>().get(
        Endpoints.auditLogsExport,
        queryParams: _buildQueryParams(),
      );

      // Response body is a CSV string from the streaming backend.
      final csvContent = response.data?.toString() ?? '';
      if (csvContent.isEmpty) {
        throw Exception('Server returned empty export.');
      }

      final dir = await getTemporaryDirectory();
      final filename =
          'audit_log_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csvContent);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv', name: filename)],
        subject: 'PPE System Audit Log Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      helpText: 'Filter audit log date range',
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      await _load();
    }
  }

  void _clearFilters() {
    setState(() {
      _dateRange = null;
      _selectedEntityType = null;
    });
    _load();
  }

  IconData _iconForAction(String action) {
    final a = action.toLowerCase();
    if (a.contains('creat') || a.contains('add')) return Icons.add_circle_outline;
    if (a.contains('updat') || a.contains('edit') || a.contains('patch')) {
      return Icons.edit_outlined;
    }
    if (a.contains('delet') || a.contains('remov')) return Icons.delete_outline;
    if (a.contains('approv')) return Icons.check_circle_outline;
    if (a.contains('reject')) return Icons.cancel_outlined;
    if (a.contains('issu')) return Icons.inventory_2_outlined;
    if (a.contains('scan')) return Icons.qr_code_scanner;
    if (a.contains('login') || a.contains('logout')) return Icons.login_outlined;
    if (a.contains('password') || a.contains('reset')) return Icons.lock_reset_outlined;
    return Icons.history;
  }

  Color _colorForAction(String action) {
    final a = action.toLowerCase();
    if (a.contains('creat') || a.contains('add')) return Colors.green;
    if (a.contains('updat') || a.contains('edit') || a.contains('patch')) {
      return Colors.blue;
    }
    if (a.contains('delet') || a.contains('remov')) return Colors.red;
    if (a.contains('approv') || a.contains('issu')) return Colors.teal;
    if (a.contains('reject')) return Colors.orange;
    if (a.contains('scan')) return Colors.purple;
    return Colors.grey;
  }

  bool get _hasActiveFilters => _dateRange != null || _selectedEntityType != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              child: const Icon(Icons.filter_list_outlined),
            ),
            tooltip: 'Filters',
            onPressed: () => setState(() => _filterExpanded = !_filterExpanded),
          ),
          _exporting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Export CSV',
                  onPressed: _exportCsv,
                ),
        ],
      ),
      body: Column(
        children: [
          if (_filterExpanded) _FilterBar(
            dateRange: _dateRange,
            selectedEntityType: _selectedEntityType,
            entityTypes: _entityTypes,
            onPickDateRange: _pickDateRange,
            onEntityTypeChanged: (v) {
              setState(() => _selectedEntityType = v);
              _load();
            },
            onClear: _hasActiveFilters ? _clearFilters : null,
          ),
          if (_hasActiveFilters)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt,
                    size: 14,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _filterSummary(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _logs.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('No audit records found.'),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _logs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final log = _logs[i];
                              final action = (log['action'] ?? '').toString();
                              final entityType = (log['entity_type'] ?? '').toString();
                              final userName =
                                  log['user_name'] ?? log['user_email'] ?? 'System';
                              final timestamp = (log['timestamp'] ?? '').toString();
                              final dateStr = timestamp.length >= 16
                                  ? '${timestamp.substring(0, 10)}\n${timestamp.substring(11, 16)}'
                                  : timestamp.substring(0, timestamp.length.clamp(0, 10));

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: _colorForAction(action).withValues(alpha: 0.12),
                                  child: Icon(
                                    _iconForAction(action),
                                    size: 18,
                                    color: _colorForAction(action),
                                  ),
                                ),
                                title: Text(
                                  _formatAction(action),
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  '$userName · $entityType',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  dateStr,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    height: 1.4,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatAction(String action) {
    return action
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _filterSummary() {
    final parts = <String>[];
    if (_dateRange != null) {
      final fmt = DateFormat('MMM d');
      parts.add('${fmt.format(_dateRange!.start)} – ${fmt.format(_dateRange!.end)}');
    }
    if (_selectedEntityType != null) parts.add(_selectedEntityType!);
    return 'Filtered: ${parts.join(', ')} · ${_logs.length} record(s)';
  }
}

class _FilterBar extends StatelessWidget {
  final DateTimeRange? dateRange;
  final String? selectedEntityType;
  final List<String> entityTypes;
  final VoidCallback onPickDateRange;
  final ValueChanged<String?> onEntityTypeChanged;
  final VoidCallback? onClear;

  const _FilterBar({
    required this.dateRange,
    required this.selectedEntityType,
    required this.entityTypes,
    required this.onPickDateRange,
    required this.onEntityTypeChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Records',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickDateRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    dateRange != null
                        ? '${fmt.format(dateRange!.start)} – ${fmt.format(dateRange!.end)}'
                        : 'Date range',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: selectedEntityType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Entity type',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All types'),
                    ),
                    ...entityTypes.map(
                      (t) => DropdownMenuItem<String?>(
                        value: t,
                        child: Text(t, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: onEntityTypeChanged,
                ),
              ),
            ],
          ),
          if (onClear != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClear,
                child: const Text('Clear all filters'),
              ),
            ),
        ],
      ),
    );
  }
}
