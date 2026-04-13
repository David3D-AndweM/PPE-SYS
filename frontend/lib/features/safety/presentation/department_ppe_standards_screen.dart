import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../injection.dart';

class DepartmentPpeStandardsScreen extends StatefulWidget {
  const DepartmentPpeStandardsScreen({super.key});

  @override
  State<DepartmentPpeStandardsScreen> createState() =>
      _DepartmentPpeStandardsScreenState();
}

class _DepartmentPpeStandardsScreenState
    extends State<DepartmentPpeStandardsScreen> {
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _ppeItems = [];
  final Map<String, Map<String, dynamic>> _requirementsByPpeItem = {};
  String? _selectedDepartmentId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        sl<ApiClient>().get(Endpoints.departments),
        sl<ApiClient>().get(Endpoints.ppeItems),
      ]);

      final departmentsData = results[0].data as Map<String, dynamic>;
      final ppeData = results[1].data as Map<String, dynamic>;

      final departments =
          (departmentsData['results'] as List).cast<Map<String, dynamic>>();
      final ppeItems =
          (ppeData['results'] as List).cast<Map<String, dynamic>>();

      setState(() {
        _departments = departments;
        _ppeItems = ppeItems;
        _selectedDepartmentId =
            departments.isNotEmpty ? departments.first['id'] as String : null;
      });

      if (_selectedDepartmentId != null) {
        await _loadRequirementsForDepartment(_selectedDepartmentId!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load standards data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadRequirementsForDepartment(String departmentId) async {
    try {
      final response = await sl<ApiClient>().get(
        Endpoints.ppeRequirements,
        queryParams: {'department': departmentId},
      );
      final data = response.data as Map<String, dynamic>;
      final requirements =
          (data['results'] as List).cast<Map<String, dynamic>>();

      _requirementsByPpeItem
        ..clear()
        ..addEntries(
          requirements.map((r) => MapEntry(r['ppe_item'] as String, r)),
        );
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load department requirements: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveRequirement({
    required String departmentId,
    required String ppeItemId,
    required bool isRequired,
    required int quantity,
  }) async {
    setState(() => _saving = true);
    try {
      final existing = _requirementsByPpeItem[ppeItemId];
      final payload = {
        'department': departmentId,
        'ppe_item': ppeItemId,
        'is_required': isRequired,
        'quantity': quantity < 1 ? 1 : quantity,
      };

      if (existing != null) {
        await sl<ApiClient>().patch(
            Endpoints.ppeRequirementDetail(existing['id'] as String),
            data: payload);
      } else {
        await sl<ApiClient>().post(Endpoints.ppeRequirements, data: payload);
      }

      await _loadRequirementsForDepartment(departmentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department PPE standard saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save requirement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Department PPE Standards')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _departments.isEmpty
              ? const Center(
                  child: Text(
                    'No departments available for your role.\n'
                    'Ask admin to assign your department scope.',
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_selectedDepartmentId),
                        initialValue: _selectedDepartmentId,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                        items: _departments.map((d) {
                          return DropdownMenuItem<String>(
                            value: d['id'] as String,
                            child: Text(
                              '${d['name']}'
                              ' (${d['site_name'] ?? 'Site'})',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          setState(() => _selectedDepartmentId = value);
                          await _loadRequirementsForDepartment(value);
                        },
                      ),
                    ),
                    if (_saving) const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _ppeItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final item = _ppeItems[i];
                          final ppeItemId = item['id'] as String;
                          final existing = _requirementsByPpeItem[ppeItemId];
                          final currentRequired =
                              (existing?['is_required'] as bool?) ?? false;
                          final currentQty =
                              (existing?['quantity'] as int?) ?? 1;
                          return _RequirementCard(
                            title: item['name'] as String? ?? 'PPE Item',
                            category: item['category'] as String? ?? '',
                            initialRequired: currentRequired,
                            initialQuantity: currentQty,
                            onSave: (requiredValue, quantityValue) {
                              if (_selectedDepartmentId == null) return;
                              _saveRequirement(
                                departmentId: _selectedDepartmentId!,
                                ppeItemId: ppeItemId,
                                isRequired: requiredValue,
                                quantity: quantityValue,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _RequirementCard extends StatefulWidget {
  final String title;
  final String category;
  final bool initialRequired;
  final int initialQuantity;
  final void Function(bool isRequired, int quantity) onSave;

  const _RequirementCard({
    required this.title,
    required this.category,
    required this.initialRequired,
    required this.initialQuantity,
    required this.onSave,
  });

  @override
  State<_RequirementCard> createState() => _RequirementCardState();
}

class _RequirementCardState extends State<_RequirementCard> {
  late bool _isRequired;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _isRequired = widget.initialRequired;
    _quantity = widget.initialQuantity < 1 ? 1 : widget.initialQuantity;
  }

  @override
  void didUpdateWidget(covariant _RequirementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRequired != widget.initialRequired ||
        oldWidget.initialQuantity != widget.initialQuantity) {
      _isRequired = widget.initialRequired;
      _quantity = widget.initialQuantity < 1 ? 1 : widget.initialQuantity;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              widget.category.toUpperCase(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Required'),
                Switch(
                  value: _isRequired,
                  onChanged: (v) => setState(() => _isRequired = v),
                ),
                const Spacer(),
                IconButton(
                  onPressed:
                      _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('Qty $_quantity'),
                IconButton(
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => widget.onSave(_isRequired, _quantity),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
