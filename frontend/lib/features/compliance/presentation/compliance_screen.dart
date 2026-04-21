import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/widgets/ppe_status_badge.dart';
import '../../../injection.dart';
import '../../approvals/data/approvals_repository.dart';
import '../../my_ppe/data/ppe_repository.dart';

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({super.key});
  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _pendingClaims = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await sl<ApiClient>().get(Endpoints.employees);
      final data = response.data as Map<String, dynamic>;
      final employees =
          (data['results'] as List).cast<Map<String, dynamic>>();
      final approvals = await sl<ApprovalsRepository>().getPendingApprovals();
      final pendingClaims = approvals.where((approval) {
        final type = (approval['slip_request_type'] ?? '').toString();
        return type == 'lost' || type == 'damaged';
      }).toList();

      // Load each employee's PPE assignments in parallel
      final assignmentLists = await Future.wait(
        employees.map((emp) async {
          try {
            return await sl<PpeRepository>()
                .getEmployeeAssignments(emp['id'] as String);
          } catch (_) {
            return <Map<String, dynamic>>[];
          }
        }),
      );

      final enriched = List<Map<String, dynamic>>.generate(employees.length, (i) {
        return {
          ...employees[i],
          'assignments': assignmentLists[i],
        };
      });

      // Non-compliant first: any expired/expiring_soon assignment → sort to top
      enriched.sort((a, b) {
        final aScore = _complianceScore(a['assignments'] as List);
        final bScore = _complianceScore(b['assignments'] as List);
        return aScore.compareTo(bScore);
      });

      setState(() {
        _employees = enriched;
        _pendingClaims = pendingClaims;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  /// Lower score = worse compliance (sorts first)
  int _complianceScore(List assignments) {
    if (assignments.any((a) => a['status'] == 'expired')) return 0;
    if (assignments.any((a) => a['status'] == 'expiring_soon')) return 1;
    return 2;
  }

  Color _statusDotColor(List assignments) {
    if (assignments.any((a) => a['status'] == 'expired')) return Colors.red;
    if (assignments.any((a) => a['status'] == 'expiring_soon')) return Colors.orange;
    return Colors.green;
  }

  int get _expiredEmployees => _employees
      .where((emp) => _complianceScore((emp['assignments'] as List)) == 0)
      .length;

  int get _expiringSoonEmployees => _employees
      .where((emp) => _complianceScore((emp['assignments'] as List)) == 1)
      .length;

  int get _compliantEmployees => _employees
      .where((emp) => _complianceScore((emp['assignments'] as List)) == 2)
      .length;

  int get _compliancePercent {
    if (_employees.isEmpty) return 0;
    return (_compliantEmployees / _employees.length * 100).round();
  }

  String _dateOnly(dynamic raw) {
    final text = (raw ?? '').toString();
    return text.length >= 10 ? text.substring(0, 10) : text;
  }

  @override
  Widget build(BuildContext context) {
    final departmentNames = _employees
        .map((e) => (e['department_name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Home'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Team Operations and Claims',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Department(s)',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            departmentNames.isEmpty
                                ? 'No managed department found.'
                                : departmentNames.join(', '),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Compliant',
                          value: '$_compliancePercent%',
                          icon: Icons.verified_outlined,
                          color: _compliancePercent == 100
                              ? Colors.green
                              : _compliancePercent >= 60
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          title: 'Team Size',
                          value: _employees.length.toString(),
                          icon: Icons.people,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          title: 'Expired',
                          value: _expiredEmployees.toString(),
                          icon: Icons.warning_amber_rounded,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          title: 'Expiring',
                          value: _expiringSoonEmployees.toString(),
                          icon: Icons.schedule,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Team PPE Status',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (_employees.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('No employees found under your department.'),
                      ),
                    )
                  else
                    ..._employees.map((emp) {
                      final assignments =
                          (emp['assignments'] as List).cast<Map<String, dynamic>>();
                      final dotColor = _statusDotColor(assignments);
                      final empId = emp['id'] as String? ?? '';
                      final empName = emp['full_name'] as String? ?? '';
                      return ExpansionTile(
                        trailing: IconButton(
                          tooltip: 'View gap analysis',
                          icon: const Icon(Icons.analytics_outlined, size: 20),
                          onPressed: empId.isEmpty
                              ? null
                              : () => context.go(
                                    '/compliance/gap-analysis/$empId?name=${Uri.encodeComponent(empName)}',
                                  ),
                        ),
                        leading: Stack(
                          children: [
                            const CircleAvatar(child: Icon(Icons.person)),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: dotColor,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          emp['full_name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          '${emp['mine_number'] ?? ''} · ${emp['department_name'] ?? ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        children: assignments.isEmpty
                            ? [
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  child: Text(
                                    'No PPE assigned.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ]
                            : assignments.map((a) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              a['ppe_item_name'] ?? '',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500),
                                            ),
                                            if (a['expiry_date'] != null)
                                              Text(
                                                'Expires: ${a['expiry_date']}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey),
                                              ),
                                          ],
                                        ),
                                      ),
                                      PpeStatusBadge(status: a['status'] ?? ''),
                                    ],
                                  ),
                                );
                              }).toList(),
                      );
                    }),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lost/Damaged Submissions',
                        style:
                            TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      TextButton.icon(
                        onPressed: () => context.go('/approvals'),
                        icon: const Icon(Icons.fact_check),
                        label: const Text('Open Approvals'),
                      ),
                    ],
                  ),
                  if (_pendingClaims.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('No pending lost/damaged submissions.'),
                      ),
                    )
                  else
                    ..._pendingClaims.map((claim) {
                      final type = (claim['slip_request_type'] ?? '').toString();
                      return Card(
                        child: ListTile(
                          isThreeLine: true,
                          leading: Icon(
                            type == 'lost'
                                ? Icons.report_problem_outlined
                                : Icons.build_circle_outlined,
                          ),
                          title: Text(claim['slip_employee_name'] ?? 'Employee'),
                          subtitle: Text(
                            '${claim['slip_department_name'] ?? ''} · ${claim['slip_mine_number'] ?? ''}\n'
                            'Submitted: ${_dateOnly(claim['created_at'])} · Items: ${claim['slip_item_count'] ?? 0}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Open this approval',
                            onPressed: () => context.go('/approvals?focus=${claim['id']}'),
                            icon: const Icon(Icons.arrow_forward_ios_rounded),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
