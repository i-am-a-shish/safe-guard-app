import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file_plus/open_file_plus.dart';
import '../core/app_theme.dart';
import '../models/alert_log.dart';

class AlertListTile extends StatelessWidget {
  final AlertLog alert;

  const AlertListTile({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final isAuto = alert.type == 'auto';
    final accentColor = isAuto ? AppColors.warning : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showAlertDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.15),
                        accentColor.withValues(alpha: 0.08),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAuto ? Icons.auto_awesome_rounded : Icons.sos_rounded,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isAuto ? 'Auto Detection' : 'Manual SOS',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (alert.hasRecording) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videocam_rounded,
                                      size: 12, color: AppColors.cyan),
                                  const SizedBox(width: 3),
                                  Text(
                                    'REC',
                                    style: TextStyle(
                                      color: AppColors.cyan,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${alert.formattedDate} at ${alert.formattedTime}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            alert.smsSent
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            size: 13,
                            color: alert.smsSent
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            alert.smsSent
                                ? '${alert.contactsNotified.length} contacts notified'
                                : 'SMS not sent',
                            style: TextStyle(
                              color: alert.smsSent
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Trailing actions
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isAuto)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(alert.confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (alert.latitude != 0.0)
                      GestureDetector(
                        onTap: () => _openMap(alert),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.map_rounded,
                            color: AppColors.info,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAlertDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              alert.type == 'auto' ? 'Auto Detection Alert' : 'Manual SOS Alert',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            _detailRow(Icons.access_time_rounded, 'Time',
                '${alert.formattedDate} at ${alert.formattedTime}'),
            _detailRow(Icons.location_on_rounded, 'Location',
                alert.latitude != 0 ? '${alert.latitude.toStringAsFixed(4)}, ${alert.longitude.toStringAsFixed(4)}' : 'Unknown'),
            _detailRow(Icons.analytics_rounded, 'Confidence',
                '${(alert.confidence * 100).toStringAsFixed(1)}%'),
            _detailRow(
                alert.smsSent
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                'SMS Status',
                alert.smsSent
                    ? 'Sent to ${alert.contactsNotified.length} contacts'
                    : 'Not sent'),
            if (alert.hasRecording)
              _detailRow(Icons.videocam_rounded, 'Recording', 'Video evidence saved'),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                if (alert.latitude != 0.0)
                  Expanded(
                    child: _actionButton(
                      icon: Icons.map_rounded,
                      label: 'View Map',
                      color: AppColors.info,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openMap(alert);
                      },
                    ),
                  ),
                if (alert.latitude != 0.0 && alert.hasRecording)
                  const SizedBox(width: 12),
                if (alert.hasRecording)
                  Expanded(
                    child: _actionButton(
                      icon: Icons.play_circle_rounded,
                      label: 'Play Video',
                      color: AppColors.success,
                      onTap: () {
                        Navigator.pop(ctx);
                        _playRecording(ctx, alert);
                      },
                    ),
                  ),
              ],
            ),
            if (alert.hasRecording) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.share_rounded,
                      label: 'Share Video',
                      color: AppColors.cyan,
                      onTap: () {
                        Navigator.pop(ctx);
                        _shareRecording(alert);
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMap(AlertLog alert) async {
    final uri = Uri.parse(alert.locationUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Play the recorded video using the device's default video player
  void _playRecording(BuildContext context, AlertLog alert) async {
    if (alert.recordingPath == null) return;
    final file = File(alert.recordingPath!);
    if (await file.exists()) {
      try {
        await OpenFile.open(alert.recordingPath!);
      } catch (e) {
        debugPrint('AlertListTile: Failed to open video: $e');
      }
    }
  }

  void _shareRecording(AlertLog alert) async {
    if (alert.recordingPath == null) return;
    final file = File(alert.recordingPath!);
    if (await file.exists()) {
      await Share.shareXFiles(
        [XFile(alert.recordingPath!)],
        text: '⚠️ Emergency recording from SafeGuardHer\n'
            'Time: ${alert.formattedDate} at ${alert.formattedTime}\n'
            'Location: ${alert.locationUrl}',
      );
    }
  }
}
