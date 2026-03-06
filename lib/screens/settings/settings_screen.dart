import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Settings',
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Profile Section
                  _buildSectionTitle(context, 'Profile'),
                  const SizedBox(height: 10),
                  _buildNameCard(context, settings),
                  const SizedBox(height: 28),

                  // Detection Section
                  _buildSectionTitle(context, 'Detection'),
                  const SizedBox(height: 10),
                  _buildSensitivityCard(context, settings),
                  const SizedBox(height: 28),

                  // Alerts Section
                  _buildSectionTitle(context, 'Alert Actions'),
                  const SizedBox(height: 10),
                  _buildToggleCard(
                    context,
                    icon: Icons.sms_rounded,
                    title: 'SMS Alerts',
                    subtitle: 'Send SMS with location to emergency contacts',
                    value: settings.smsEnabled,
                    onChanged: (v) => settings.setSmsEnabled(v),
                    color: AppColors.info,
                  ),
                  const SizedBox(height: 10),
                  _buildToggleCard(
                    context,
                    icon: Icons.volume_up_rounded,
                    title: 'Sound Alerts',
                    subtitle: 'Play alarm sound when distress is detected',
                    value: settings.soundAlertEnabled,
                    onChanged: (v) => settings.setSoundAlertEnabled(v),
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 10),
                  _buildToggleCard(
                    context,
                    icon: Icons.videocam_rounded,
                    title: 'Video Recording',
                    subtitle: 'Record 30s video from back camera on alert',
                    value: settings.videoRecordingEnabled,
                    onChanged: (v) => settings.setVideoRecordingEnabled(v),
                    color: AppColors.cyan,
                  ),
                  const SizedBox(height: 28),

                  // About Section
                  _buildSectionTitle(context, 'About'),
                  const SizedBox(height: 10),
                  _buildInfoCard(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: AppColors.textMuted.withValues(alpha: 0.8),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildNameCard(BuildContext context, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showEditNameDialog(context, settings),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.shimmerGradient,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  settings.userName.isNotEmpty
                      ? settings.userName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.userName.isEmpty ? 'Set Your Name' : settings.userName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Used in SMS alerts to identify you',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: AppColors.textMuted,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensitivityCard(BuildContext context, SettingsProvider settings) {
    // Calculate sensitivity label and color
    String sensitivityLabel;
    Color sensitivityColor;
    IconData sensitivityIcon;

    if (settings.threshold <= 0.4) {
      sensitivityLabel = 'High Sensitivity';
      sensitivityColor = AppColors.danger;
      sensitivityIcon = Icons.warning_rounded;
    } else if (settings.threshold <= 0.6) {
      sensitivityLabel = 'Balanced';
      sensitivityColor = AppColors.success;
      sensitivityIcon = Icons.tune_rounded;
    } else {
      sensitivityLabel = 'Low Sensitivity';
      sensitivityColor = AppColors.info;
      sensitivityIcon = Icons.shield_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sensitivityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  sensitivityIcon,
                  color: sensitivityColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detection Sensitivity',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sensitivityLabel,
                      style: TextStyle(
                        color: sensitivityColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: sensitivityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  settings.threshold.toStringAsFixed(2),
                  style: TextStyle(
                    color: sensitivityColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: sensitivityColor,
              inactiveTrackColor: sensitivityColor.withValues(alpha: 0.15),
              thumbColor: sensitivityColor,
              overlayColor: sensitivityColor.withValues(alpha: 0.15),
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: settings.threshold,
              min: AppConstants.minThreshold,
              max: AppConstants.maxThreshold,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                settings.setThreshold(v);
              },
            ),
          ),

          // Min/Max labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSliderLabel('More\nSensitive', AppConstants.minThreshold),
                _buildSliderLabel('Less\nSensitive', AppConstants.maxThreshold),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Explanation card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textMuted.withValues(alpha: 0.6),
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lower threshold = more alerts (may include false positives)\n'
                    'Higher threshold = fewer, more certain alerts',
                    style: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.7),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderLabel(String text, double value) {
    return Column(
      children: [
        Text(
          text,
          style: TextStyle(
            color: AppColors.textMuted.withValues(alpha: 0.6),
            fontSize: 11,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(
            color: AppColors.textMuted.withValues(alpha: 0.4),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: value ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: value ? 0.15 : 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: value ? color : AppColors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeTrackColor: color.withValues(alpha: 0.4),
            activeThumbColor: color,
            inactiveTrackColor: AppColors.surfaceLight,
            inactiveThumbColor: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          _buildInfoRow('App Name', AppConstants.appName),
          _buildInfoRow('Version', '1.0.0'),
          _buildInfoRow('Model', 'CNN (128×94 mel spectrogram)'),
          _buildInfoRow('Audio', '22050 Hz, 16-bit PCM'),
          _buildInfoRow('Recording', '30 sec back camera'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.cyan.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_rounded,
                    color: AppColors.primaryLight, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All data is stored locally on your device. No cloud servers.',
                    style: TextStyle(
                      color: AppColors.primaryLight.withValues(alpha: 0.8),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.userName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Your Name',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter your name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                settings.setUserName(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
