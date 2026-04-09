import 'package:flutter/material.dart';
import '../../../injection.dart';
import '../data/approvals_repository.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});
  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  List<Map<String, dynamic>> _approvals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _approvals = await sl<ApprovalsRepository>().getPendingApprovals();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _action(String id, bool approve) async {
    String comment = '';
    if (!approve) {
      final ctrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Reason for Rejection'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Enter reason...')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reject')),
          ],
        ),
      );
      if (confirmed != true) return;
      comment = ctrl.text;
    }

    try {
      final repo = sl<ApprovalsRepository>();
      if (approve) {
        await repo.approve(id);
      } else {
        await repo.reject(id, comment: comment);
      }
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Approvals')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _approvals.isEmpty
                  ? const Center(child: Text('No pending approvals.'))
                  : ListView.builder(
                      itemCount: _approvals.length,
                      itemBuilder: (_, i) {
                        final a = _approvals[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a['slip_employee_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('Role required: ${a['required_role']}'),
                                Text('Created: ${(a['created_at'] ?? '').toString().substring(0, 10)}'),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _action(a['id'], false),
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      label: const Text('Reject', style: TextStyle(color: Colors.red)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _action(a['id'], true),
                                      icon: const Icon(Icons.check),
                                      label: const Text('Approve'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
