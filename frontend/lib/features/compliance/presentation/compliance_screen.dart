import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../injection.dart';

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({super.key});
  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await sl<ApiClient>().get(Endpoints.employees);
      final data = response.data as Map<String, dynamic>;
      _employees = (data['results'] as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    setState(() => _loading = false);
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
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(emp['full_name'] ?? ''),
                          subtitle: Text('${emp['mine_number']} · ${emp['department_name']}'),
                          trailing: Chip(
                            label: Text(emp['status'] ?? ''),
                            backgroundColor: emp['status'] == 'active'
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
