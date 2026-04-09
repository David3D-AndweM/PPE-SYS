import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await sl<ApiClient>().get(Endpoints.auditLogs);
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _logs = (data['results'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load audit logs: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  IconData _iconForAction(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE': return Icons.add_circle_outline;
      case 'UPDATE': return Icons.edit_outlined;
      case 'DELETE': return Icons.delete_outline;
      case 'APPROVE': return Icons.check_circle_outline;
      case 'REJECT': return Icons.cancel_outlined;
      default: return Icons.history;
    }
  }

  Color _colorForAction(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE': return Colors.green;
      case 'UPDATE': return Colors.blue;
      case 'DELETE': return Colors.red;
      case 'APPROVE': return Colors.teal;
      case 'REJECT': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _logs.isEmpty
                  ? const Center(child: Text('No audit records found.'))
                  : ListView.separated(
                      itemCount: _logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final log = _logs[i];
                        final action = (log['action'] ?? '').toString();
                        final entityType = (log['entity_type'] ?? '').toString();
                        final userName = log['user_name'] ?? log['user'] ?? 'System';
                        final createdAt = (log['created_at'] ?? '').toString();
                        final dateStr = createdAt.length >= 10
                            ? createdAt.substring(0, 10)
                            : createdAt;

                        return ListTile(
                          leading: Icon(
                            _iconForAction(action),
                            color: _colorForAction(action),
                          ),
                          title: Text(
                            '$action — $entityType',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(userName.toString()),
                          trailing: Text(
                            dateStr,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
