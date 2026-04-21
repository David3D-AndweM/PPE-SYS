import 'package:flutter/material.dart';
import '../../../injection.dart';
import '../data/approvals_repository.dart';

class ApprovalsScreen extends StatefulWidget {
  final String? initialApprovalId;

  const ApprovalsScreen({super.key, this.initialApprovalId});
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
      final loaded = await sl<ApprovalsRepository>().getPendingApprovals();
      if (widget.initialApprovalId != null && widget.initialApprovalId!.isNotEmpty) {
        loaded.sort((a, b) {
          final aFocused = a['id'] == widget.initialApprovalId;
          final bFocused = b['id'] == widget.initialApprovalId;
          if (aFocused == bFocused) return 0;
          return aFocused ? -1 : 1;
        });
      }
      _approvals = loaded;
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _action(String id, bool approve) async {
    String comment = '';
    if (!approve) {
      final ctrl = TextEditingController();
      const quickReasons = [
        'We have enough.',
        'Insufficient evidence provided.',
        'Use existing issued PPE first.',
      ];
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Reason for Rejection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quickReasons
                    .map(
                      (reason) => ActionChip(
                        label: Text(reason),
                        onPressed: () => ctrl.text = reason,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration:
                    const InputDecoration(hintText: 'Enter reason...'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reject')),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Department Submissions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _approvals.isEmpty
                  ? const Center(child: Text('No pending submissions.'))
                  : ListView.builder(
                      itemCount: _approvals.length,
                      itemBuilder: (_, i) {
                        final a = _approvals[i];
                        final isFocused = widget.initialApprovalId != null &&
                            a['id'] == widget.initialApprovalId;
                        final requestType =
                            (a['slip_request_type'] ?? '').toString();
                        final isClaim =
                            requestType == 'lost' || requestType == 'damaged';
                        return Card(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: isFocused
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: isFocused ? 1.5 : 0,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a['slip_employee_name'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (isClaim)
                                      Chip(
                                        label: Text(requestType.toUpperCase()),
                                        avatar: Icon(
                                          requestType == 'lost'
                                              ? Icons.report_problem_outlined
                                              : Icons.build_circle_outlined,
                                          size: 18,
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  '${a['slip_department_name'] ?? ''} · ${a['slip_mine_number'] ?? ''}',
                                ),
                                Text('Role required: ${a['required_role']}'),
                                Text(
                                  'Submitted: ${(a['created_at'] ?? '').toString().substring(0, 10)} · Items: ${a['slip_item_count'] ?? 0}',
                                ),
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
