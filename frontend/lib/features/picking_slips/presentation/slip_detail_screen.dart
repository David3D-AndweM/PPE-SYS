import 'package:flutter/material.dart';
import '../../../injection.dart';
import '../data/picking_repository.dart';

class SlipDetailScreen extends StatefulWidget {
  final String slipId;
  const SlipDetailScreen({super.key, required this.slipId});

  @override
  State<SlipDetailScreen> createState() => _SlipDetailScreenState();
}

class _SlipDetailScreenState extends State<SlipDetailScreen> {
  Map<String, dynamic>? _slip;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _slip = await sl<PickingRepository>().getSlip(widget.slipId);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Request ${_slip?['slip_number'] ?? ''}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _slip == null
              ? const Center(child: Text('Request not found'))
              : _SlipDetailView(slip: _slip!),
    );
  }
}

class _SlipDetailView extends StatelessWidget {
  final Map<String, dynamic> slip;
  const _SlipDetailView({required this.slip});

  @override
  Widget build(BuildContext context) {
    final items = (slip['items'] as List?) ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoRow('Employee', slip['employee_name'] ?? ''),
        _InfoRow('Mine Number', slip['mine_number'] ?? ''),
        _InfoRow('Department', slip['department_name'] ?? ''),
        _InfoRow('Request Type', slip['request_type'] ?? ''),
        _InfoRow('Status', slip['status'] ?? ''),
        _InfoRow('Requested By', slip['requested_by_name'] ?? ''),
        if (slip['approved_at'] != null)
          _InfoRow('Approved At', slip['approved_at'].toString().substring(0, 10)),
        if (slip['issued_at'] != null)
          _InfoRow('Issued At', slip['issued_at'].toString().substring(0, 10)),
        if (slip['notes']?.isNotEmpty == true)
          _InfoRow('Notes', slip['notes']),
        const Divider(height: 32),
        Text('Items', style: Theme.of(context).textTheme.titleMedium),
        ...items.map((item) => ListTile(
          leading: const Icon(Icons.security),
          title: Text(item['ppe_item_name'] ?? ''),
          trailing: Text('× ${item['quantity']}'),
        )),
        if (slip['qr_image'] != null && slip['status'] == 'approved')
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              children: [
                Text('QR Code', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Image.memory(
                  Uri.parse(slip['qr_image']).data!.contentAsBytes(),
                  width: 200,
                  height: 200,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
