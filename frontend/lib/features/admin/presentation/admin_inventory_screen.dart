// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../injection.dart';

class AdminInventoryScreen extends StatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  State<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends State<AdminInventoryScreen> {
  List<Map<String, dynamic>> _stock = [];
  List<Map<String, dynamic>> _ppeItems = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        sl<ApiClient>().get(Endpoints.stock),
        sl<ApiClient>().get(Endpoints.ppeItems),
        sl<ApiClient>().get(Endpoints.warehouses),
      ]);
      setState(() {
        _stock = ((results[0].data as Map)['results'] as List).cast<Map<String, dynamic>>();
        _ppeItems = ((results[1].data as Map)['results'] as List).cast<Map<String, dynamic>>();
        _warehouses = ((results[2].data as Map)['results'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load inventory: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showReceiveStockSheet() {
    String? selectedPpeItemId;
    String? selectedWarehouseId;
    final qtyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Receive Stock', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedPpeItemId,
                decoration: const InputDecoration(labelText: 'PPE Item'),
                items: _ppeItems
                    .map((item) => DropdownMenuItem<String>(
                          value: item['id'] as String,
                          child: Text(item['name'] ?? ''),
                        ))
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedPpeItemId = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedWarehouseId,
                decoration: const InputDecoration(labelText: 'Warehouse'),
                items: _warehouses
                    .map((w) => DropdownMenuItem<String>(
                          value: w['id'] as String,
                          child: Text(w['name'] ?? ''),
                        ))
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedWarehouseId = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedPpeItemId == null || selectedWarehouseId == null) return;
                    final qty = int.tryParse(qtyCtrl.text.trim());
                    if (qty == null || qty <= 0) return;
                    try {
                      await sl<ApiClient>().post(
                        '${Endpoints.stock}receive/',
                        data: {
                          'ppe_item': selectedPpeItemId,
                          'warehouse': selectedWarehouseId,
                          'quantity': qty,
                        },
                      );
                      if (!mounted || !sheetCtx.mounted) return;
                      Navigator.of(sheetCtx).pop();
                      _load();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Stock received successfully.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted || !sheetCtx.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('Receive'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReceiveStockSheet,
        icon: const Icon(Icons.add),
        label: const Text('Receive Stock'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _stock.isEmpty
                  ? const Center(child: Text('No stock records found.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStatePropertyAll(
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          columns: const [
                            DataColumn(label: Text('PPE Item')),
                            DataColumn(label: Text('Warehouse')),
                            DataColumn(label: Text('In Stock'), numeric: true),
                            DataColumn(label: Text('Reorder Level'), numeric: true),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: _stock.map((row) {
                            final qty = (row['quantity_available'] as num?)?.toInt() ?? 0;
                            final reorder = (row['reorder_level'] as num?)?.toInt() ?? 0;
                            final isLow = qty <= reorder;
                            return DataRow(
                              color: WidgetStatePropertyAll(
                                isLow ? Colors.amber.shade50 : null,
                              ),
                              cells: [
                                DataCell(Text(row['ppe_item_name'] ?? row['ppe_item'] ?? '')),
                                DataCell(Text(row['warehouse_name'] ?? row['warehouse'] ?? '')),
                                DataCell(Text('$qty')),
                                DataCell(Text('$reorder')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isLow ? Colors.amber.shade100 : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isLow ? 'Low Stock' : 'OK',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isLow ? Colors.amber.shade800 : Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
    );
  }
}
