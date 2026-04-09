import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../injection.dart';
import '../data/scan_repository.dart';

class IssueConfirmScreen extends StatefulWidget {
  final Map<String, dynamic> slipData;
  const IssueConfirmScreen({super.key, required this.slipData});

  @override
  State<IssueConfirmScreen> createState() => _IssueConfirmScreenState();
}

class _IssueConfirmScreenState extends State<IssueConfirmScreen> {
  bool _issuing = false;
  // In a real app, the warehouse would be selected from a dropdown
  // populated from the /inventory/warehouses/ endpoint.
  // For scaffolding, we use the first warehouse from slip items.
  String? get _warehouseId {
    final items = widget.slipData['items'] as List?;
    if (items == null || items.isEmpty) return null;
    return items.first['warehouse'] as String?;
  }

  Future<void> _confirmIssue() async {
    final warehouseId = _warehouseId;
    if (warehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No warehouse assigned to this slip.')),
      );
      return;
    }

    setState(() => _issuing = true);
    try {
      await sl<ScanRepository>().finalizeIssue(
        slipId: widget.slipData['id'] as String,
        warehouseId: warehouseId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PPE issued successfully!'), backgroundColor: Colors.green),
        );
        context.go('/store/scan');
      }
    } catch (e) {
      setState(() => _issuing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Issue failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slip = widget.slipData;
    final items = (slip['items'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Issue')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Employee', style: Theme.of(context).textTheme.labelSmall),
                    Text(slip['employee_name'] ?? '', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Mine: ${slip['mine_number'] ?? ''}'),
                    Text('Dept: ${slip['department_name'] ?? ''}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Items to Issue', style: Theme.of(context).textTheme.titleSmall),
            ...items.map((item) => ListTile(
              leading: const Icon(Icons.security, color: Colors.blue),
              title: Text(item['ppe_item_name'] ?? ''),
              trailing: Text('× ${item['quantity']}'),
            )),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _issuing ? null : _confirmIssue,
                icon: _issuing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle),
                label: Text(_issuing ? 'Issuing...' : 'Confirm & Issue PPE'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
