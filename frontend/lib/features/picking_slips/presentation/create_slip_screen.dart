import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../injection.dart';
import '../data/picking_repository.dart';

class CreateSlipScreen extends StatefulWidget {
  const CreateSlipScreen({super.key});

  @override
  State<CreateSlipScreen> createState() => _CreateSlipScreenState();
}

class _CreateSlipScreenState extends State<CreateSlipScreen> {
  String _requestType = 'expiry';
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  static const _requestTypes = [
    ('expiry', 'PPE Expired'),
    ('lost', 'PPE Lost'),
    ('damaged', 'PPE Damaged'),
    ('new', 'New / First Issue'),
  ];

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await sl<PickingRepository>().createSlip({
        'request_type': _requestType,
        'notes': _notesCtrl.text,
        'items': [],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted successfully')),
        );
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request PPE Replacement')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request Type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._requestTypes.map((t) => RadioListTile<String>(
              title: Text(t.$2),
              value: t.$1,
              groupValue: _requestType,
              onChanged: (v) => setState(() => _requestType = v!),
            )),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
