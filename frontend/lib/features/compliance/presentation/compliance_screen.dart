import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/widgets/ppe_status_badge.dart';
import '../../../injection.dart';
import '../../my_ppe/data/ppe_repository.dart';

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({super.key});
  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  // Each entry: employee map + 'assignments' key → List<Map>
  List<Map<String, dynamic>> _employees = [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team Compliance')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _employees.isEmpty
                  ? const Center(child: Text('No employees found.'))
                  : ListView.builder(
                      itemCount: _employees.length,
                      itemBuilder: (_, i) {
                        final emp = _employees[i];
                        final assignments =
                            (emp['assignments'] as List).cast<Map<String, dynamic>>();
                        final dotColor = _statusDotColor(assignments);

                        return ExpansionTile(
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
                                    border: Border.all(color: Colors.white, width: 1.5),
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
                                        PpeStatusBadge(
                                            status: a['status'] ?? ''),
                                      ],
                                    ),
                                  );
                                }).toList(),
                        );
                      },
                    ),
            ),
    );
  }
}
