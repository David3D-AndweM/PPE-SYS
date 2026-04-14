import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ppe_status_badge.dart';
import '../../../injection.dart';
import '../data/ppe_repository.dart';

class MyPpeScreen extends StatefulWidget {
  const MyPpeScreen({super.key});

  @override
  State<MyPpeScreen> createState() => _MyPpeScreenState();
}

class _MyPpeScreenState extends State<MyPpeScreen> {
  List<Map<String, dynamic>> _assignments = [];
  Map<String, dynamic>? _compliance;
  String? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = sl<PpeRepository>();
      final assignments = await repo.getMyPpe();
      Map<String, dynamic>? compliance;
      try {
        compliance = await repo.getComplianceSummary();
      } catch (_) {
        compliance = _buildComplianceFallback(assignments);
      }
      setState(() {
        _assignments = assignments;
        _compliance = compliance;
        _loadError = null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Map<String, dynamic> _buildComplianceFallback(
    List<Map<String, dynamic>> assignments,
  ) {
    int valid = 0, expiring = 0, expired = 0, pending = 0;
    for (final item in assignments) {
      final status = item['status'] as String? ?? '';
      if (status == 'valid') valid++;
      if (status == 'expiring_soon') expiring++;
      if (status == 'expired') expired++;
      if (status == 'pending_issue') pending++;
    }
    final first = assignments.isNotEmpty ? assignments.first : <String, dynamic>{};
    return {
      'employee_name': first['employee_name'],
      'mine_number': first['mine_number'],
      'department_name': first['department_name'],
      'site_name': first['site_name'],
      'total': assignments.length,
      'valid': valid,
      'expiring_soon': expiring,
      'expired': expired,
      'pending_issue': pending,
      'is_compliant': expired == 0 && expiring == 0 && pending == 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My PPE'),
        actions: const [],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/my-ppe/slips/create?type=expiry'),
        icon: const Icon(Icons.add),
        label: const Text('Request Replacement'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 34),
                        const SizedBox(height: 8),
                        const Text('Unable to load your PPE details'),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  if (_compliance != null) _EmployeeContextSliver(data: _compliance!),
                  if (_compliance != null) _ComplianceSummarySliver(data: _compliance!),
                  if (_assignments.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No PPE has been assigned to you yet.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  SliverList.builder(
                    itemCount: _assignments.length,
                    itemBuilder: (_, i) => _PpeCard(data: _assignments[i]),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ComplianceSummarySliver extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ComplianceSummarySliver({required this.data});

  @override
  Widget build(BuildContext context) {
    final isCompliant = data['is_compliant'] == true;
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompliant ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompliant ? Colors.green : Colors.red,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCompliant ? Icons.check_circle : Icons.warning,
              color: isCompliant ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCompliant ? 'Fully Compliant' : 'Action Required',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCompliant ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                  Text(
                    '${data['valid']} valid · ${data['expiring_soon']} expiring · ${data['expired']} expired',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeContextSliver extends StatelessWidget {
  final Map<String, dynamic> data;
  const _EmployeeContextSliver({required this.data});

  @override
  Widget build(BuildContext context) {
    final dept = (data['department_name'] as String?) ?? 'Unassigned';
    final site = (data['site_name'] as String?) ?? 'Unknown site';
    final mine = (data['mine_number'] as String?) ?? '-';
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Department: $dept', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Site: $site · Mine No: $mine', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push('/my-ppe/slips/create?type=expiry'),
                  icon: const Icon(Icons.autorenew),
                  label: const Text('Replacement'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/my-ppe/slips/create?type=lost'),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Lost PPE Claim'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PpeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PpeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.statusColor(data['status'] ?? '').withValues(alpha: 0.15),
          child: Icon(
            Icons.security,
            color: AppTheme.statusColor(data['status'] ?? ''),
          ),
        ),
        title: Text(data['ppe_item_name'] ?? ''),
        subtitle: Text(
          data['issue_date'] != null
              ? 'Issued: ${data['issue_date']} · Expires: ${data['expiry_date'] ?? '-'}'
              : 'Not yet issued',
        ),
        trailing: PpeStatusBadge(status: data['status'] ?? ''),
      ),
    );
  }
}
