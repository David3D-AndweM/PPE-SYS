import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_bloc.dart';
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
      final results = await Future.wait([
        repo.getMyPpe(),
        repo.getComplianceSummary(),
      ]);
      setState(() {
        _assignments = results[0] as List<Map<String, dynamic>>;
        _compliance = results[1] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My PPE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/my-ppe/slips/create'),
        icon: const Icon(Icons.add),
        label: const Text('Request Replacement'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  if (_compliance != null) _ComplianceSummarySliver(data: _compliance!),
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

class _PpeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PpeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.statusColor(data['status'] ?? '').withOpacity(0.15),
          child: Icon(
            Icons.security,
            color: AppTheme.statusColor(data['status'] ?? ''),
          ),
        ),
        title: Text(data['ppe_item_name'] ?? ''),
        subtitle: Text(
          data['expiry_date'] != null
              ? 'Expires: ${data['expiry_date']}'
              : 'Not yet issued',
        ),
        trailing: PpeStatusBadge(status: data['status'] ?? ''),
      ),
    );
  }
}
