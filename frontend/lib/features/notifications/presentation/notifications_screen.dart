import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_bloc.dart';
import '../../../core/websocket/ws_service.dart';
import '../../../injection.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    sl<WsService>().resetBadge();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { _notifications = await sl<NotificationsRepository>().getNotifications(); }
    catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    await sl<NotificationsRepository>().markAllRead();
    _load();
  }

  void _navigateForNotification(BuildContext context, String type) {
    final auth = context.read<AuthBloc>().state;
    final role = auth is AuthAuthenticated ? auth.primaryRole : 'Employee';

    switch (type) {
      case 'approval':
        context.go('/approvals');
      case 'expiry':
      case 'compliance':
        if (role == 'Employee') {
          context.go('/my-ppe');
        } else {
          context.go('/compliance');
        }
      case 'stock':
        if (role == 'Admin' || role == 'Store') {
          context.go('/admin/inventory');
        }
      default:
        break;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'expiry': return Icons.timer_off;
      case 'approval': return Icons.approval;
      case 'stock': return Icons.inventory;
      case 'compliance': return Icons.warning;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? const Center(child: Text('No notifications.'))
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (_, i) {
                        final n = _notifications[i];
                        final isRead = n['is_read'] == true;
                        return ListTile(
                          tileColor: isRead ? null : Colors.blue.shade50,
                          leading: Icon(_iconFor(n['notification_type'] ?? ''),
                              color: isRead ? Colors.grey : Colors.blue),
                          title: Text(n['title'] ?? '',
                              style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                          subtitle: Text(n['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Text(
                            (n['created_at'] ?? '').toString().length >= 10
                                ? n['created_at'].toString().substring(0, 10)
                                : '',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          onTap: () {
                            if (!isRead) {
                              sl<NotificationsRepository>().markRead(n['id']);
                              setState(() => n['is_read'] = true);
                            }
                            _navigateForNotification(
                              context,
                              n['notification_type'] as String? ?? '',
                            );
                          },
                        );
                      },
                    ),
            ),
    );
  }
}
