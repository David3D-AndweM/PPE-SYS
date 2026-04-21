import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../injection.dart';

class GapAnalysisScreen extends StatefulWidget {
  final String employeeId;
  final String? employeeName;

  const GapAnalysisScreen({
    super.key,
    required this.employeeId,
    this.employeeName,
  });

  @override
  State<GapAnalysisScreen> createState() => _GapAnalysisScreenState();
}

class _GapAnalysisScreenState extends State<GapAnalysisScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await sl<ApiClient>().get(
        Endpoints.gapAnalysis(widget.employeeId),
      );
      setState(() {
        _data = response.data as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employeeName != null
            ? '${widget.employeeName} — Gap Analysis'
            : 'PPE Gap Analysis'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(error: _error!, onRetry: _load)
              : _GapAnalysisBody(data: _data!, onRefresh: _load),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _GapAnalysisBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;

  const _GapAnalysisBody({required this.data, required this.onRefresh});

  List<Map<String, dynamic>> _list(String key) =>
      ((data[key] as List?) ?? []).cast<Map<String, dynamic>>();

  @override
  Widget build(BuildContext context) {
    final compliancePct = (data['compliance_percentage'] as num?)?.toDouble() ?? 0.0;
    final isCompliant = data['is_compliant'] == true;
    final required = _list('required');
    final assigned = _list('assigned');
    final expired = _list('expired');
    final pending = _list('pending');
    final missing = _list('missing');

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Compliance % ring ──────────────────────────────────────────────
          _ComplianceIndicator(
            percentage: compliancePct,
            isCompliant: isCompliant,
            totalRequired: required.length,
            assignedCount: assigned.length,
          ),
          const SizedBox(height: 16),

          // ── Summary chips ─────────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: '${assigned.length} Valid',
                color: Colors.green,
                icon: Icons.check_circle_outline,
              ),
              if (pending.isNotEmpty)
                _StatusChip(
                  label: '${pending.length} Pending',
                  color: Colors.blue,
                  icon: Icons.hourglass_empty_outlined,
                ),
              if (expired.isNotEmpty)
                _StatusChip(
                  label: '${expired.length} Expired',
                  color: Colors.red,
                  icon: Icons.warning_amber_rounded,
                ),
              if (missing.isNotEmpty)
                _StatusChip(
                  label: '${missing.length} Missing',
                  color: Colors.deepOrange,
                  icon: Icons.block_outlined,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Missing PPE (highest priority) ────────────────────────────────
          if (missing.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Missing PPE',
              subtitle: 'Required items not yet assigned',
              color: Colors.deepOrange,
              icon: Icons.block_outlined,
            ),
            ...missing.map((item) => _PpeItemTile(
                  name: item['name'] ?? '',
                  statusLabel: 'Missing',
                  statusColor: Colors.deepOrange,
                  leadingIcon: Icons.block_outlined,
                )),
            const SizedBox(height: 16),
          ],

          // ── Expired ───────────────────────────────────────────────────────
          if (expired.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Expired',
              subtitle: 'Items past their expiry date',
              color: Colors.red,
              icon: Icons.timer_off_outlined,
            ),
            ...expired.map((item) => _PpeItemTile(
                  name: item['name'] ?? '',
                  statusLabel: 'Expired',
                  statusColor: Colors.red,
                  leadingIcon: Icons.timer_off_outlined,
                )),
            const SizedBox(height: 16),
          ],

          // ── Pending Issue ─────────────────────────────────────────────────
          if (pending.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Pending Issue',
              subtitle: 'Assigned but not yet physically issued',
              color: Colors.blue,
              icon: Icons.hourglass_empty_outlined,
            ),
            ...pending.map((item) => _PpeItemTile(
                  name: item['name'] ?? '',
                  statusLabel: 'Pending',
                  statusColor: Colors.blue,
                  leadingIcon: Icons.hourglass_empty_outlined,
                )),
            const SizedBox(height: 16),
          ],

          // ── Valid / Assigned ──────────────────────────────────────────────
          if (assigned.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Valid PPE',
              subtitle: 'Currently assigned and in compliance',
              color: Colors.green,
              icon: Icons.verified_outlined,
            ),
            ...assigned.map((item) => _PpeItemTile(
                  name: item['name'] ?? '',
                  statusLabel: 'Valid',
                  statusColor: Colors.green,
                  leadingIcon: Icons.verified_outlined,
                )),
          ],

          if (required.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No PPE requirements defined for this employee\'s department.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Compliance indicator ─────────────────────────────────────────────────────

class _ComplianceIndicator extends StatelessWidget {
  final double percentage;
  final bool isCompliant;
  final int totalRequired;
  final int assignedCount;

  const _ComplianceIndicator({
    required this.percentage,
    required this.isCompliant,
    required this.totalRequired,
    required this.assignedCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompliant
        ? Colors.green
        : percentage >= 50
            ? Colors.orange
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: percentage / 100,
                    strokeWidth: 8,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Center(
                    child: Text(
                      '${percentage.round()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCompliant ? 'Fully Compliant' : 'Non-Compliant',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$assignedCount of $totalRequired required items in compliance',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PPE item tile ────────────────────────────────────────────────────────────

class _PpeItemTile extends StatelessWidget {
  final String name;
  final String statusLabel;
  final Color statusColor;
  final IconData leadingIcon;

  const _PpeItemTile({
    required this.name,
    required this.statusLabel,
    required this.statusColor,
    required this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(leadingIcon, size: 16, color: statusColor),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Status chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Could not load gap analysis',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
