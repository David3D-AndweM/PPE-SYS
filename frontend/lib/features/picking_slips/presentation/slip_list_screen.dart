import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../injection.dart';
import '../data/picking_repository.dart';

class SlipListScreen extends StatefulWidget {
  const SlipListScreen({super.key});
  @override
  State<SlipListScreen> createState() => _SlipListScreenState();
}

class _SlipListScreenState extends State<SlipListScreen> {
  List<Map<String, dynamic>> _slips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _slips = await sl<PickingRepository>().getSlips();
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My PPE Requests')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/my-ppe/slips/create'),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _slips.isEmpty
                  ? const Center(child: Text('No requests found.'))
                  : ListView.builder(
                      itemCount: _slips.length,
                      itemBuilder: (_, i) {
                        final slip = _slips[i];
                        return ListTile(
                          title: Text(() {
                            final s = (slip['slip_number'] ?? slip['id'] ?? '').toString();
                            return 'Request #${s.length > 8 ? s.substring(0, 8) : s}';
                          }()),
                          subtitle: Text('${slip['request_type']} · ${slip['created_at']?.toString().substring(0, 10)}'),
                          trailing: _StatusChip(status: slip['status'] ?? ''),
                          onTap: () => context.push('/my-ppe/slips/${slip['id']}'),
                        );
                      },
                    ),
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get _color {
    switch (status) {
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'issued': return Colors.blue;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
      backgroundColor: _color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
