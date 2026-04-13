import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../injection.dart';
import '../data/scan_repository.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController();
  final _slipNumberCtrl = TextEditingController();
  final _mineNumberCtrl = TextEditingController();
  final _employeeIdCtrl = TextEditingController();
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    _slipNumberCtrl.dispose();
    _mineNumberCtrl.dispose();
    _employeeIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    setState(() => _processing = true);
    _controller.stop();

    try {
      final slip = await sl<ScanRepository>().validateScan(code);
      if (mounted) {
        context.push('/store/issue-confirm', extra: slip);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Scan error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _processing = false);
        _controller.start();
      }
    }
  }

  Future<void> _manualLookup() async {
    final slipNumber = _slipNumberCtrl.text.trim();
    final mineNumber = _mineNumberCtrl.text.trim();
    final employeeId = _employeeIdCtrl.text.trim();
    if (slipNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a picking slip number')),
      );
      return;
    }
    if (mineNumber.isEmpty && employeeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter mine number or employee ID')),
      );
      return;
    }

    setState(() => _processing = true);
    try {
      final slip = await sl<ScanRepository>().validateByReference(
        slipNumber: slipNumber,
        mineNumber: mineNumber.isEmpty ? null : mineNumber,
        employeeId: employeeId.isEmpty ? null : employeeId,
      );
      if (mounted) {
        context.push('/store/issue-confirm', extra: slip);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lookup error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Picking Slip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                // Scan guide overlay
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _processing
                            ? 'Processing...'
                            : 'Scan QR or use manual lookup below',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Manual Lookup',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _slipNumberCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Picking Slip Number',
                    hintText: 'e.g. ABCD1234',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mineNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mine Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _employeeIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Employee ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _processing ? null : _manualLookup,
                    icon: const Icon(Icons.search),
                    label: const Text('Find Picking Slip'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
