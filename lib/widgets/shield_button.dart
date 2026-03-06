import 'dart:math';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../providers/protection_provider.dart';

class ShieldButton extends StatelessWidget {
  final bool isActive;
  final ProtectionStatus status;
  final AnimationController pulseController;
  final VoidCallback onTap;

  const ShieldButton({
    super.key,
    required this.isActive,
    required this.status,
    required this.pulseController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAlert = status == ProtectionStatus.alertTriggered;
    final baseColor = isAlert ? AppColors.danger : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (context, child) {
          final pulseValue = isActive ? pulseController.value : 0.0;

          return SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer particle ring (rotating dots)
                if (isActive)
                  Transform.rotate(
                    angle: pulseValue * 2 * pi,
                    child: CustomPaint(
                      size: const Size(230, 230),
                      painter: _OrbitDotsPainter(
                        color: baseColor,
                        progress: pulseValue,
                      ),
                    ),
                  ),

                // Outer glow ring 3 — soft halo
                if (isActive)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 220 + (pulseValue * 16),
                    height: 220 + (pulseValue * 16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: baseColor.withValues(alpha: 0.06 + pulseValue * 0.04),
                        width: 1,
                      ),
                    ),
                  ),

                // Outer glow ring 2
                if (isActive)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 200 + (pulseValue * 10),
                    height: 200 + (pulseValue * 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: baseColor.withValues(alpha: 0.08 + pulseValue * 0.06),
                        width: 1.5,
                      ),
                    ),
                  ),

                // Outer glow ring 1 — bright inner halo
                if (isActive)
                  Container(
                    width: 184 + (pulseValue * 6),
                    height: 184 + (pulseValue * 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: baseColor.withValues(alpha: 0.12 + pulseValue * 0.08),
                          blurRadius: 40 + pulseValue * 20,
                          spreadRadius: 4 + pulseValue * 4,
                        ),
                      ],
                    ),
                  ),

                // Main shield button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isActive
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isAlert
                                ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                : [const Color(0xFF7C3AED), const Color(0xFF9333EA)],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.surfaceLight,
                              AppColors.surface,
                            ],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: isActive
                            ? baseColor.withValues(alpha: 0.35 + pulseValue * 0.1)
                            : Colors.black26,
                        blurRadius: isActive ? 30 + pulseValue * 10 : 20,
                        offset: const Offset(0, 8),
                      ),
                      if (isActive)
                        BoxShadow(
                          color: baseColor.withValues(alpha: 0.15),
                          blurRadius: 60,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          child: child,
                        ),
                        child: Icon(
                          isAlert
                              ? Icons.warning_rounded
                              : Icons.shield_rounded,
                          key: ValueKey(isAlert),
                          size: 52,
                          color: isActive
                              ? Colors.white
                              : AppColors.textMuted.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : AppColors.textMuted.withValues(alpha: 0.6),
                          fontSize: isAlert ? 14 : 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                        child: Text(
                          isActive
                              ? (isAlert ? 'ALERT!' : 'ACTIVE')
                              : 'OFF',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Paints small orbiting dots around the shield
class _OrbitDotsPainter extends CustomPainter {
  final Color color;
  final double progress;

  _OrbitDotsPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const dotCount = 8;

    for (int i = 0; i < dotCount; i++) {
      final angle = (2 * pi * i / dotCount) + (progress * 2 * pi);
      final dotX = center.dx + radius * cos(angle);
      final dotY = center.dy + radius * sin(angle);
      final opacity = 0.15 + (0.35 * ((sin(progress * 2 * pi + i) + 1) / 2));
      final dotSize = 2.0 + (1.5 * ((sin(progress * 2 * pi + i * 0.8) + 1) / 2));

      canvas.drawCircle(
        Offset(dotX, dotY),
        dotSize,
        Paint()..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitDotsPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
