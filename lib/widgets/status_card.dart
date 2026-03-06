import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../providers/protection_provider.dart';

class StatusCard extends StatefulWidget {
  final ProtectionStatus status;
  final double probability;
  final bool isActive;

  const StatusCard({
    super.key,
    required this.status,
    required this.probability,
    required this.isActive,
  });

  @override
  State<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<StatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _getGradientColors(),
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            children: [
              // Status Icon with animated ring
              _buildStatusIcon(statusColor),
              const SizedBox(width: 16),

              // Status Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusTitle(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusSubtitle(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Detection indicator pill
              if (widget.isActive && widget.probability > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    '${(widget.probability * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(Color statusColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer subtle ring
        if (widget.isActive)
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
        // Inner icon circle
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          child: Icon(
            _getStatusIcon(),
            color: Colors.white,
            size: 26,
          ),
        ),
      ],
    );
  }

  List<Color> _getGradientColors() {
    switch (widget.status) {
      case ProtectionStatus.listening:
        return [const Color(0xFF0E7490), const Color(0xFF0369A1)];
      case ProtectionStatus.alertTriggered:
        return [const Color(0xFFDC2626), const Color(0xFFBE185D)];
      case ProtectionStatus.cooldown:
        return [const Color(0xFFD97706), const Color(0xFFC2410C)];
      case ProtectionStatus.idle:
        return [AppColors.surfaceLight, AppColors.surface];
    }
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case ProtectionStatus.listening:
        return AppColors.cyan;
      case ProtectionStatus.alertTriggered:
        return AppColors.danger;
      case ProtectionStatus.cooldown:
        return AppColors.warning;
      case ProtectionStatus.idle:
        return AppColors.textMuted;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.status) {
      case ProtectionStatus.listening:
        return Icons.hearing_rounded;
      case ProtectionStatus.alertTriggered:
        return Icons.warning_rounded;
      case ProtectionStatus.cooldown:
        return Icons.timer_rounded;
      case ProtectionStatus.idle:
        return Icons.shield_outlined;
    }
  }

  String _getStatusTitle() {
    switch (widget.status) {
      case ProtectionStatus.listening:
        return 'Actively Listening';
      case ProtectionStatus.alertTriggered:
        return 'Alert Triggered!';
      case ProtectionStatus.cooldown:
        return 'Cooldown Period';
      case ProtectionStatus.idle:
        return 'Protection Disabled';
    }
  }

  String _getStatusSubtitle() {
    switch (widget.status) {
      case ProtectionStatus.listening:
        return 'AI is monitoring for distress sounds';
      case ProtectionStatus.alertTriggered:
        return 'Emergency contacts notified';
      case ProtectionStatus.cooldown:
        return 'Alert cooldown, resuming soon...';
      case ProtectionStatus.idle:
        return 'Enable protection to start monitoring';
    }
  }
}
