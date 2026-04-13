import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

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
  List<Map<String, dynamic>> _sites = [];

  final Map<String, Map<String, dynamic>> _requirementsByPpeItem = {};
  final Map<String, Map<String, dynamic>> _configsByPpeItem = {};
  final Map<String, _DraftRequirement> _draftByPpeItem = {};
  final Set<String> _dirtyPpeItemIds = {};

  String? _selectedDepartmentId;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      final responses = await Future.wait([
        sl<ApiClient>().get(Endpoints.departments),
        sl<ApiClient>().get(Endpoints.ppeItems),
        sl<ApiClient>().get(Endpoints.sites),
      ]);

      final departments = ((responses[0].data as Map<String, dynamic>)['results']
              as List)
          .cast<Map<String, dynamic>>();
      final ppeItems = ((responses[1].data as Map<String, dynamic>)['results']
              as List)
          .cast<Map<String, dynamic>>();
      final sites = ((responses[2].data as Map<String, dynamic>)['results']
              as List)
          .cast<Map<String, dynamic>>();

      setState(() {
        _departments = departments;
        _ppeItems = ppeItems;
        _sites = sites;
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
          content: Text('Failed to load data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRequirementsForDepartment(String departmentId) async {
    try {
      final responses = await Future.wait([
        sl<ApiClient>().get(
          Endpoints.ppeRequirements,
          queryParams: {'department': departmentId},
        ),
        sl<ApiClient>().get(
          Endpoints.ppeConfigurations,
          queryParams: {'scope_type': 'department'},
        ),
      ]);

      final requirements = ((responses[0].data as Map<String, dynamic>)['results']
              as List)
          .cast<Map<String, dynamic>>();
      final allConfigs = ((responses[1].data as Map<String, dynamic>)['results']
              as List)
          .cast<Map<String, dynamic>>();
      final configs = allConfigs
          .where((c) => (c['scope_id'] as String?) == departmentId)
          .toList();

      _requirementsByPpeItem
        ..clear()
        ..addEntries(
          requirements.map((r) => MapEntry(r['ppe_item'] as String, r)),
        );
      _configsByPpeItem
        ..clear()
        ..addEntries(configs.map((c) => MapEntry(c['ppe_item'] as String, c)));
      _resetDraftFromServer();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load department PPE: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetDraftFromServer() {
    _draftByPpeItem.clear();
    _dirtyPpeItemIds.clear();
    for (final item in _ppeItems) {
      final id = item['id'] as String;
      final req = _requirementsByPpeItem[id];
      final cfg = _configsByPpeItem[id];
      final defaultValidity = (item['default_validity_days'] as int?) ?? 365;
      _draftByPpeItem[id] = _DraftRequirement(
        isRequired: (req?['is_required'] as bool?) ?? false,
        quantity: ((req?['quantity'] as int?) ?? 1).clamp(1, 999),
        validityDays:
            ((cfg?['validity_days'] as int?) ?? defaultValidity).clamp(1, 3650),
      );
    }
  }

  void _updateDraft(
    String ppeItemId,
    bool isRequired,
    int quantity,
    int validityDays,
  ) {
    final next = _DraftRequirement(
      isRequired: isRequired,
      quantity: quantity < 1 ? 1 : quantity,
      validityDays: validityDays < 1 ? 1 : validityDays,
    );
    _draftByPpeItem[ppeItemId] = next;

    final req = _requirementsByPpeItem[ppeItemId];
    final cfg = _configsByPpeItem[ppeItemId];
    final item = _ppeItems.firstWhere((e) => e['id'] == ppeItemId);
    final defaultValidity = (item['default_validity_days'] as int?) ?? 365;
    final isDirty = next.isRequired != ((req?['is_required'] as bool?) ?? false) ||
        next.quantity != ((req?['quantity'] as int?) ?? 1) ||
        next.validityDays != ((cfg?['validity_days'] as int?) ?? defaultValidity);
    if (isDirty) {
      _dirtyPpeItemIds.add(ppeItemId);
    } else {
      _dirtyPpeItemIds.remove(ppeItemId);
    }
    setState(() {});
  }

  Future<void> _saveAllDepartmentPpeChanges() async {
    if (_selectedDepartmentId == null || _dirtyPpeItemIds.isEmpty) return;
    setState(() => _saving = true);
    try {
      final departmentId = _selectedDepartmentId!;
      final changed = _dirtyPpeItemIds.toList()..sort();
      for (final ppeItemId in changed) {
        final draft = _draftByPpeItem[ppeItemId];
        if (draft == null) continue;
        final req = _requirementsByPpeItem[ppeItemId];
        final cfg = _configsByPpeItem[ppeItemId];

        final reqPayload = {
          'department': departmentId,
          'ppe_item': ppeItemId,
          'is_required': draft.isRequired,
          'quantity': draft.quantity,
        };
        if (req != null) {
          await sl<ApiClient>().patch(
            Endpoints.ppeRequirementDetail(req['id'] as String),
            data: reqPayload,
          );
        } else {
          await sl<ApiClient>().post(Endpoints.ppeRequirements, data: reqPayload);
        }

        final cfgPayload = {
          'ppe_item': ppeItemId,
          'scope_type': 'department',
          'scope_id': departmentId,
          'validity_days': draft.validityDays,
        };
        if (cfg != null) {
          await sl<ApiClient>().patch(
            Endpoints.ppeConfigurationDetail(cfg['id'] as String),
            data: cfgPayload,
          );
        } else {
          await sl<ApiClient>().post(Endpoints.ppeConfigurations, data: cfgPayload);
        }
      }

      await _loadRequirementsForDepartment(departmentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${changed.length} change(s)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Map<String, dynamic>> _assignedPpeItemsForSelectedDepartment() {
    if (_selectedDepartmentId == null) return const [];
    final ids = <String>{..._requirementsByPpeItem.keys, ..._configsByPpeItem.keys};
    for (final id in _dirtyPpeItemIds) {
      final draft = _draftByPpeItem[id];
      if (draft != null && draft.isRequired) ids.add(id);
    }
    return _ppeItems.where((item) => ids.contains(item['id'] as String)).toList();
  }

  Future<void> _pickDepartment() async {
    if (_departments.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DepartmentPickerSheet(
        departments: _departments,
        selectedDepartmentId: _selectedDepartmentId,
      ),
    );
    if (picked == null || picked == _selectedDepartmentId) return;
    setState(() => _selectedDepartmentId = picked);
    await _loadRequirementsForDepartment(picked);
  }

  Future<void> _addPpeToSelectedDepartment() async {
    if (_selectedDepartmentId == null) return;
    final assignedIds = <String>{..._requirementsByPpeItem.keys, ..._configsByPpeItem.keys};
    final candidates =
        _ppeItems.where((item) => !assignedIds.contains(item['id'] as String)).toList();
    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All PPE items already assigned')),
      );
      return;
    }

    String? selectedId = candidates.first['id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: const Text('Add PPE to Department'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedId,
            items: candidates
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item['id'] as String,
                    child: Text(item['name'] as String? ?? 'PPE Item'),
                  ),
                )
                .toList(),
            onChanged: (v) => setDialog(() => selectedId = v),
            decoration: const InputDecoration(labelText: 'PPE Item'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selectedId == null) return;

    final item = _ppeItems.firstWhere((e) => e['id'] == selectedId);
    final defaultValidity = (item['default_validity_days'] as int?) ?? 365;
    _updateDraft(selectedId!, true, 1, defaultValidity);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added in draft. Click Save All.')),
    );
  }

  Future<void> _removePpeFromDepartment(String ppeItemId) async {
    if (_selectedDepartmentId == null) return;
    final req = _requirementsByPpeItem[ppeItemId];
    final cfg = _configsByPpeItem[ppeItemId];
    if (req == null && cfg == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove PPE from Department'),
        content: const Text('Remove requirement and department policy override?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      if (req != null) {
        await sl<ApiClient>().delete(Endpoints.ppeRequirementDetail(req['id'] as String));
      }
      if (cfg != null) {
        await sl<ApiClient>().delete(Endpoints.ppeConfigurationDetail(cfg['id'] as String));
      }
      await _loadRequirementsForDepartment(_selectedDepartmentId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from department')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showCreateDepartmentDialog() async {
    final nameCtrl = TextEditingController();
    String? siteId = _sites.isNotEmpty ? _sites.first['id'] as String : null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Create Department'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Department Name'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: siteId,
              items: _sites
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s['id'] as String,
                      child: Text(s['name'] as String? ?? 'Site'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => siteId = v,
              decoration: const InputDecoration(labelText: 'Site'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty || siteId == null) return;

    try {
      await sl<ApiClient>().post(
        Endpoints.departments,
        data: {'name': nameCtrl.text.trim(), 'site': siteId},
      );
      await _loadInitialData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department created')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create department: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCreatePpeDialog() async => _showPpeEditor();

  Future<void> _showEditPpeDialog(Map<String, dynamic> existing) async =>
      _showPpeEditor(existing: existing);

  Future<void> _showPpeEditor({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final validityCtrl = TextEditingController(
      text: '${(existing?['default_validity_days'] as int?) ?? 365}',
    );
    String category = (existing?['category'] as String?) ?? 'head';
    bool critical = (existing?['is_critical'] as bool?) ?? false;
    bool serial = (existing?['requires_serial_tracking'] as bool?) ?? false;
    XFile? selectedImage;
    const categories = [
      'head',
      'eye',
      'respiratory',
      'hand',
      'foot',
      'hearing',
      'hi_vis',
      'body',
      'other',
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: Text(existing == null ? 'Create PPE Item' : 'Edit PPE Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialog(() => category = v ?? category),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: validityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Default Validity Days'),
                ),
                SwitchListTile(
                  value: critical,
                  onChanged: (v) => setDialog(() => critical = v),
                  title: const Text('Critical PPE'),
                ),
                SwitchListTile(
                  value: serial,
                  onChanged: (v) => setDialog(() => serial = v),
                  title: const Text('Requires Serial Tracking'),
                ),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.image_outlined),
                  title: Text(
                    selectedImage != null
                        ? selectedImage!.name
                        : ((existing?['image'] as String?)?.isNotEmpty ?? false)
                            ? 'Current image available'
                            : 'No image selected',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await _imagePicker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1400,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        setDialog(() => selectedImage = picked);
                      }
                    },
                    child: const Text('Choose Image'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;

    try {
      final payload = {
        'name': nameCtrl.text.trim(),
        'category': category,
        'default_validity_days': (int.tryParse(validityCtrl.text.trim()) ?? 365)
            .clamp(1, 3650),
        'is_critical': critical,
        'requires_serial_tracking': serial,
      };
      final data = FormData.fromMap({
        ...payload,
        if (selectedImage != null)
          'image': await MultipartFile.fromFile(
            selectedImage!.path,
            filename: selectedImage!.name,
          ),
      });
      if (existing == null) {
        await sl<ApiClient>().post(Endpoints.ppeItems, data: data);
      } else {
        await sl<ApiClient>().patch(
          Endpoints.ppeItemDetail(existing['id'] as String),
          data: data,
        );
      }
      await _loadInitialData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'PPE item created' : 'PPE item updated'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save PPE item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePpeItem(String ppeItemId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete PPE Item'),
        content: const Text('Delete this PPE item from catalogue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await sl<ApiClient>().delete(Endpoints.ppeItemDetail(ppeItemId));
      await _loadInitialData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PPE item deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete PPE item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _copyFromAnotherDepartment() async {
    if (_selectedDepartmentId == null) return;
    final sourceId = await showDialog<String>(
      context: context,
      builder: (_) => _CopyFromDepartmentDialog(
        departments: _departments,
        currentDepartmentId: _selectedDepartmentId!,
      ),
    );
    if (sourceId == null) return;

    setState(() => _saving = true);
    try {
      final reqResp = await sl<ApiClient>().get(
        Endpoints.ppeRequirements,
        queryParams: {'department': sourceId},
      );
      final cfgResp = await sl<ApiClient>().get(
        Endpoints.ppeConfigurations,
        queryParams: {'scope_type': 'department'},
      );
      final reqs = ((reqResp.data as Map<String, dynamic>)['results'] as List)
          .cast<Map<String, dynamic>>();
      final cfgs = ((cfgResp.data as Map<String, dynamic>)['results'] as List)
          .cast<Map<String, dynamic>>()
          .where((c) => (c['scope_id'] as String?) == sourceId)
          .toList();
      final reqMap = {for (final r in reqs) r['ppe_item'] as String: r};
      final cfgMap = {for (final c in cfgs) c['ppe_item'] as String: c};

      for (final item in _ppeItems) {
        final id = item['id'] as String;
        final req = reqMap[id];
        final cfg = cfgMap[id];
        final defaultValidity = (item['default_validity_days'] as int?) ?? 365;
        _updateDraft(
          id,
          (req?['is_required'] as bool?) ?? false,
          (req?['quantity'] as int?) ?? 1,
          (cfg?['validity_days'] as int?) ?? defaultValidity,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied into draft. Click Save All.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to copy: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic>? get _selectedDepartment {
    final id = _selectedDepartmentId;
    if (id == null) return null;
    for (final d in _departments) {
      if (d['id'] == id) return d;
    }
    return null;
  }

  Widget _buildDepartmentMappingTab() {
    if (_departments.isEmpty) {
      return const Center(
        child: Text(
          'No departments yet.\nUse "Create Department" to add one.',
          textAlign: TextAlign.center,
        ),
      );
    }
    final assigned = _assignedPpeItemsForSelectedDepartment();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _showCreateDepartmentDialog,
                icon: const Icon(Icons.add_home_outlined),
                label: const Text('Create Department'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDepartment,
                  icon: const Icon(Icons.apartment_outlined),
                  label: Text(
                    _selectedDepartment == null
                        ? 'Select Department'
                        : '${_selectedDepartment!['name']}'
                            ' (${_selectedDepartment!['site_name'] ?? 'Site'})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _copyFromAnotherDepartment,
                icon: const Icon(Icons.content_copy_outlined),
                label: const Text('Copy'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _addPpeToSelectedDepartment,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add PPE to Dept'),
              ),
              const SizedBox(width: 8),
              Text('${_dirtyPpeItemIds.length} unsaved change(s)'),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: (_saving || _dirtyPpeItemIds.isEmpty)
                    ? null
                    : _saveAllDepartmentPpeChanges,
                icon: const Icon(Icons.save),
                label: const Text('Save All'),
              ),
            ],
          ),
        ),
        if (_saving) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: assigned.isEmpty
              ? const Center(
                  child: Text(
                    'No PPE assigned to this department.\nUse "Add PPE to Dept".',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: assigned.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = assigned[i];
                    final id = item['id'] as String;
                    final draft = _draftByPpeItem[id] ??
                        const _DraftRequirement(
                          isRequired: false,
                          quantity: 1,
                          validityDays: 365,
                        );
                    return _RequirementCard(
                      title: item['name'] as String? ?? 'PPE',
                      category: item['category'] as String? ?? '',
                      imageUrl: item['image'] as String?,
                      isRequired: draft.isRequired,
                      quantity: draft.quantity,
                      validityDays: draft.validityDays,
                      isDirty: _dirtyPpeItemIds.contains(id),
                      onChanged: (requiredValue, quantityValue, validityValue) =>
                          _updateDraft(
                        id,
                        requiredValue,
                        quantityValue,
                        validityValue,
                      ),
                      onRemoveFromDepartment: () => _removePpeFromDepartment(id),
                      onDeletePpeItem: () => _deletePpeItem(id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPpePoliciesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _showCreatePpeDialog,
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Create PPE'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _ppeItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final item = _ppeItems[i];
              return Card(
                child: ListTile(
                  title: Text(item['name'] as String? ?? 'PPE'),
                  subtitle: Text(
                    '${(item['category'] as String? ?? '').toUpperCase()}'
                    ' • Validity ${item['default_validity_days'] ?? 0} days'
                    ' • Critical: ${item['is_critical'] == true ? 'Yes' : 'No'}'
                    ' • Serial: ${item['requires_serial_tracking'] == true ? 'Yes' : 'No'}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: 'Edit PPE',
                        onPressed: () => _showEditPpeDialog(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete PPE',
                        onPressed: () => _deletePpeItem(item['id'] as String),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Safety Management'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.account_tree_outlined),
                text: 'Departments',
              ),
              Tab(
                icon: Icon(Icons.security_outlined),
                text: 'PPE Policies',
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildDepartmentMappingTab(),
                  _buildPpePoliciesTab(),
                ],
              ),
      ),
    );
  }
}

class _RequirementCard extends StatefulWidget {
  final String title;
  final String category;
  final String? imageUrl;
  final bool isRequired;
  final int quantity;
  final int validityDays;
  final bool isDirty;
  final void Function(bool, int, int) onChanged;
  final VoidCallback onRemoveFromDepartment;
  final VoidCallback onDeletePpeItem;

  const _RequirementCard({
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.isRequired,
    required this.quantity,
    required this.validityDays,
    required this.isDirty,
    required this.onChanged,
    required this.onRemoveFromDepartment,
    required this.onDeletePpeItem,
  });

  @override
  State<_RequirementCard> createState() => _RequirementCardState();
}

class _RequirementCardState extends State<_RequirementCard> {
  late bool _isRequired;
  late int _quantity;
  late int _validityDays;

  @override
  void initState() {
    super.initState();
    _isRequired = widget.isRequired;
    _quantity = widget.quantity;
    _validityDays = widget.validityDays;
  }

  @override
  void didUpdateWidget(covariant _RequirementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRequired != widget.isRequired ||
        oldWidget.quantity != widget.quantity ||
        oldWidget.validityDays != widget.validityDays) {
      _isRequired = widget.isRequired;
      _quantity = widget.quantity;
      _validityDays = widget.validityDays;
    }
  }

  void _emit() => widget.onChanged(_isRequired, _quantity, _validityDays);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: widget.isDirty ? Colors.orange.withValues(alpha: 0.08) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        widget.imageUrl!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                Chip(label: Text(widget.category)),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: widget.onRemoveFromDepartment,
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('Remove from Dept'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: widget.onDeletePpeItem,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete PPE'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isRequired,
                    onChanged: (v) {
                      setState(() => _isRequired = v);
                      _emit();
                    },
                    title: const Text('Required'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: TextFormField(
                    initialValue: '$_quantity',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    onChanged: (v) {
                      _quantity = int.tryParse(v.trim()) ?? 1;
                      _emit();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    initialValue: '$_validityDays',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Validity Days'),
                    onChanged: (v) {
                      _validityDays = int.tryParse(v.trim()) ?? 1;
                      _emit();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> departments;
  final String? selectedDepartmentId;

  const _DepartmentPickerSheet({
    required this.departments,
    required this.selectedDepartmentId,
  });

  @override
  State<_DepartmentPickerSheet> createState() => _DepartmentPickerSheetState();
}

class _DepartmentPickerSheetState extends State<_DepartmentPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = widget.departments.where((d) {
      final name = (d['name'] as String? ?? '').toLowerCase();
      final site = (d['site_name'] as String? ?? '').toLowerCase();
      return q.isEmpty || name.contains(q) || site.contains(q);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search department',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final d = filtered[i];
                  final id = d['id'] as String;
                  return ListTile(
                    title: Text(d['name'] as String? ?? 'Department'),
                    subtitle: Text(d['site_name'] as String? ?? 'Site'),
                    trailing: widget.selectedDepartmentId == id
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () => Navigator.pop(context, id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyFromDepartmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> departments;
  final String currentDepartmentId;

  const _CopyFromDepartmentDialog({
    required this.departments,
    required this.currentDepartmentId,
  });

  @override
  State<_CopyFromDepartmentDialog> createState() =>
      _CopyFromDepartmentDialogState();
}

class _CopyFromDepartmentDialogState extends State<_CopyFromDepartmentDialog> {
  String? _selectedSourceId;

  @override
  Widget build(BuildContext context) {
    final candidates = widget.departments
        .where((d) => d['id'] != widget.currentDepartmentId)
        .toList();
    return AlertDialog(
      title: const Text('Copy Standards From'),
      content: SizedBox(
        width: 460,
        child: candidates.isEmpty
            ? const Text('No other departments found.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: candidates.length,
                itemBuilder: (_, i) {
                  final d = candidates[i];
                  final id = d['id'] as String;
                  final selected = id == _selectedSourceId;
                  return ListTile(
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(d['name'] as String? ?? 'Department'),
                    subtitle: Text(d['site_name'] as String? ?? 'Site'),
                    onTap: () => setState(() => _selectedSourceId = id),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              _selectedSourceId == null ? null : () => Navigator.pop(context, _selectedSourceId),
          child: const Text('Copy'),
        ),
      ],
    );
  }
}

class _DraftRequirement {
  final bool isRequired;
  final int quantity;
  final int validityDays;

  const _DraftRequirement({
    required this.isRequired,
    required this.quantity,
    required this.validityDays,
  });
}
