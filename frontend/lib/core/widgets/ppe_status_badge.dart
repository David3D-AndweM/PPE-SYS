import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PpeStatusBadge extends StatelessWidget {
  final String status;
  const PpeStatusBadge({super.key, required this.status});

  String get _label {
    switch (status) {
      case 'valid': return 'Valid';
      case 'expiring_soon': return 'Expiring';
      case 'expired': return 'Expired';
      case 'blocked': return 'Blocked';
      case 'pending_issue': return 'Pending';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
