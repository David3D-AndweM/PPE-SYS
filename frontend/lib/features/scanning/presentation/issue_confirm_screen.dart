import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
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
  bool _loadingWarehouses = true;
  List<Map<String, dynamic>> _warehouses = [];
  String? _selectedWarehouseId;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    try {
      final resp = await sl<ApiClient>().get(Endpoints.warehouses);
      final results = ((resp.data as Map)['results'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _warehouses = results;
        if (results.isNotEmpty) _selectedWarehouseId = results.first['id'] as String;
        _loadingWarehouses = false;
      });
    } catch (_) {
      setState(() => _loadingWarehouses = false);
    }
  }

  Future<void> _confirmIssue() async {
    if (_selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a warehouse before issuing.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _issuing = true);
    try {
      await sl<ScanRepository>().finalizeIssue(
        slipId: widget.slipData['id'] as String,
        warehouseId: _selectedWarehouseId!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PPE issued successfully!'), backgroundColor: Colors.green),
        );
        context.go('/store/scan');
      }
    } catch (e) {
      setState(() => _issuing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Issue failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slip = widget.slipData;
    final items = (slip['items'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Issue')),
      body: _loadingWarehouses
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Employee card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Employee', style: Theme.of(context).textTheme.labelSmall),
                          Text(slip['employee_name'] ?? '', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('Mine #: ${slip['mine_number'] ?? ''}'),
                          Text('Dept: ${slip['department_name'] ?? ''}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Items
                  Text('Items to Issue', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  ...items.map((item) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.security, color: Colors.blue),
                        title: Text(item['ppe_item_name'] ?? ''),
                        trailing: Text('× ${item['quantity']}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      )),
                  const SizedBox(height: 16),

                  // Warehouse selector
                  Text('Issue From Warehouse', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _warehouses.isEmpty
                      ? const Text('No warehouses available.', style: TextStyle(color: Colors.red))
                      : DropdownButtonFormField<String>(
                          value: _selectedWarehouseId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: _warehouses
                              .map((w) => DropdownMenuItem<String>(
                                    value: w['id'] as String,
                                    child: Text(w['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedWarehouseId = v),
                        ),
                  const Spacer(),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_issuing || _selectedWarehouseId == null) ? null : _confirmIssue,
                      icon: _issuing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(_issuing ? 'Issuing...' : 'Confirm & Issue PPE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
