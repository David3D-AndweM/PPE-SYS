import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../injection.dart';

class AdminPpeCatalogueScreen extends StatefulWidget {
  const AdminPpeCatalogueScreen({super.key});

  @override
  State<AdminPpeCatalogueScreen> createState() => _AdminPpeCatalogueScreenState();
}

class _AdminPpeCatalogueScreenState extends State<AdminPpeCatalogueScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await sl<ApiClient>().get(Endpoints.ppeItems);
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _items = (data['results'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load PPE catalogue: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDetail(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item['name'] ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('Category', (item['category'] ?? '').toString().toUpperCase()),
            _DetailRow('Validity (days)', '${item['default_validity_days'] ?? 'N/A'}'),
            _DetailRow(
              'Serial Tracking',
              item['requires_serial_tracking'] == true ? 'Yes' : 'No',
            ),
            _DetailRow('Critical', item['is_critical'] == true ? 'Yes' : 'No'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddItemSheet() {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final validityCtrl = TextEditingController();
    bool isCritical = false;

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
              Text('Add PPE Item', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: validityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Validity Days (leave blank for N/A)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: isCritical,
                    onChanged: (v) => setSheetState(() => isCritical = v ?? false),
                  ),
                  const Text('Critical PPE'),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    try {
                      await sl<ApiClient>().post(Endpoints.ppeItems, data: {
                        'name': nameCtrl.text.trim(),
                        'category': categoryCtrl.text.trim(),
                        if (validityCtrl.text.trim().isNotEmpty)
                          'default_validity_days': int.tryParse(validityCtrl.text.trim()),
                        'is_critical': isCritical,
                      });
                      if (mounted) {
                        Navigator.of(sheetCtx).pop();
                        _load();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Add Item'),
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
      appBar: AppBar(title: const Text('PPE Catalogue')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? const Center(child: Text('No PPE items found.'))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = _items[i];
                        final isCritical = item['is_critical'] == true;
                        final category = (item['category'] ?? '').toString().toUpperCase();
                        return ListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text(item['name'] ?? '')),
                              if (isCritical)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'CRITICAL',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              Chip(
                                label: Text(category, style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              if (item['default_validity_days'] != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${item['default_validity_days']}d',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showDetail(item),
                        );
                      },
                    ),
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
