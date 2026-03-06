import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../providers/protection_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../services/audio_processing_service.dart';
import '../../services/tflite_service.dart';
import '../contacts/contacts_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/shield_button.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/status_card.dart';
import '../../widgets/alert_list_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildDashboard(),
            const ContactsScreen(),
            const SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDashboard() {
    return Consumer2<ProtectionProvider, ContactsProvider>(
      builder: (context, protection, contacts, _) {
        return SafeArea(
          child: FadeTransition(
            opacity: _fadeController,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // App Header
                    _buildHeader(context),
                    const SizedBox(height: 24),

                    // Status Card
                    StatusCard(
                      status: protection.status,
                      probability: protection.lastProbability,
                      isActive: protection.isProtectionEnabled,
                    ),
                    const SizedBox(height: 32),

                    // Main Shield Button
                    ShieldButton(
                      isActive: protection.isProtectionEnabled,
                      status: protection.status,
                      pulseController: _pulseController,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        protection.toggleProtection();
                      },
                    ),
                    const SizedBox(height: 16),

                    // Protection toggle text
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        protection.isProtectionEnabled
                            ? 'Tap shield to disable protection'
                            : 'Tap shield to enable protection',
                        key: ValueKey(protection.isProtectionEnabled),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                              letterSpacing: 0.3,
                            ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // SOS Button — sends immediately, no confirmation
                    SOSButton(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        protection.triggerManualSOS();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.sos_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 10),
                                Expanded(child: Text('🚨 Emergency SOS sent! Alerting contacts...')),
                              ],
                            ),
                            backgroundColor: AppColors.danger,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Test Detection Button
                    _buildTestButton(context),
                    const SizedBox(height: 24),

                    // Quick Stats Row
                    _buildQuickStats(protection, contacts),
                    const SizedBox(height: 28),

                    // Recent Alerts
                    _buildRecentAlerts(protection),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.shimmerGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SafeGuardHer',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                Text(
                  'Your Silent Guardian',
                  style: TextStyle(
                    color: AppColors.primaryLight.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            color: AppColors.textSecondary,
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(ProtectionProvider protection, ContactsProvider contacts) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people_rounded,
            label: 'Contacts',
            value: '${contacts.count}',
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.warning_amber_rounded,
            label: 'Alerts',
            value: '${protection.alertLogs.length}',
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.speed_rounded,
            label: 'Last Scan',
            value: protection.lastProbability > 0
                ? '${(protection.lastProbability * 100).toStringAsFixed(0)}%'
                : '—',
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
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
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlerts(ProtectionProvider protection) {
    final alerts = protection.alertLogs.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Recent Alerts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            if (alerts.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: const Text('Clear History'),
                      content: const Text('Clear all alert logs?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Clear',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    protection.clearAlertLogs();
                  }
                },
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (alerts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    size: 40,
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'All Clear',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'No alerts triggered yet.\nYour safety monitor will log events here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted.withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...alerts.map((alert) => AlertListTile(alert: alert)),
      ],
    );
  }




  Widget _buildTestButton(BuildContext context) {
    return GestureDetector(
      onTap: _isTesting ? null : () => _runMicTest(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: _isTesting
              ? AppColors.surface
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.info.withValues(alpha: _isTesting ? 0.2 : 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.info.withValues(alpha: _isTesting ? 0.05 : 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isTesting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                ),
              )
            else
              const Icon(Icons.mic_rounded, color: AppColors.info, size: 22),
            const SizedBox(width: 10),
            Text(
              _isTesting ? 'Recording 3 seconds...' : 'Test Mic Detection',
              style: TextStyle(
                color: _isTesting ? AppColors.textMuted : AppColors.info,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runMicTest(BuildContext context) async {
    if (_isTesting) return;
    setState(() => _isTesting = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      // Ensure model is loaded
      if (!TfliteService.isInitialized) {
        final loaded = await TfliteService.init();
        if (!loaded) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Model not loaded — cannot run test.')),
          );
          return;
        }
      }

      final recorder = AudioRecorder();

      // Exact bytes for 94 mel frames at 16000 Hz:
      // (94-1)*512 + 2048 = 49664 samples × 2 bytes = 99328 bytes
      const int targetBytes = 99328;

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConstants.sampleRate, // 16000
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      );

      // Start stream and collect exactly targetBytes of PCM data
      final stream = await recorder.startStream(config);
      final List<int> buffer = [];

      await for (final chunk in stream) {
        buffer.addAll(chunk);
        if (buffer.length >= targetBytes) break;
      }

      await recorder.stop();

      // Clamp to exact size
      final int capturedBytes = math.min(buffer.length, targetBytes);
      final pcmBytes = Uint8List.fromList(buffer.sublist(0, capturedBytes));

      // Analyze amplitude of captured audio
      final ampStats = _analyzePcmAmplitude(pcmBytes);

      // Save as WAV file for inspection
      String? savedPath;
      try {
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${dir.path}/mic_test_$timestamp.wav');
        final wavBytes = _buildWavBytes(pcmBytes, AppConstants.sampleRate, 1, 16);
        await file.writeAsBytes(wavBytes);
        savedPath = file.path;
      } catch (e) {
        debugPrint('HomeScreen: Failed to save WAV: $e');
      }

      // If we captured fewer bytes than needed, pad with zeros for pipeline
      final Uint8List audioBytes = capturedBytes >= targetBytes
          ? pcmBytes
          : Uint8List(targetBytes)..setAll(0, pcmBytes);

      // Run through full pipeline
      final spectrogram = AudioProcessingService.processAudioToSpectrogram(audioBytes);
      final probability = TfliteService.runInference(spectrogram);

      if (!context.mounted) return;

      if (probability != null) {
        _showTestResult(
          context,
          probability: probability,
          peakAmplitude: ampStats['peak']!,
          rmsAmplitude: ampStats['rms']!,
          capturedBytes: capturedBytes,
          savedPath: savedPath,
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Inference failed — check model and pipeline.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Test error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  /// Analyze PCM 16-bit LE audio for amplitude stats
  Map<String, double> _analyzePcmAmplitude(Uint8List pcmBytes) {
    double maxAbs = 0;
    double sumSquares = 0;
    final int count = pcmBytes.length ~/ 2;
    if (count == 0) return {'peak': 0, 'rms': 0};

    for (int i = 0; i < count; i++) {
      int lo = pcmBytes[i * 2];
      int hi = pcmBytes[i * 2 + 1];
      int raw = (hi << 8) | lo;
      if (raw >= 32768) raw -= 65536; // two's complement signed
      final double s = raw / 32767.0;
      final double absS = s.abs();
      if (absS > maxAbs) maxAbs = absS;
      sumSquares += s * s;
    }
    return {
      'peak': maxAbs,
      'rms': math.sqrt(sumSquares / count),
    };
  }

  /// Write PCM bytes as a proper WAV file (44-byte header + data)
  Uint8List _buildWavBytes(Uint8List pcm, int sampleRate, int channels, int bitsPerSample) {
    final int dataSize = pcm.length;
    final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final int blockAlign = channels * (bitsPerSample ~/ 8);
    final ByteData hdr = ByteData(44);

    // RIFF
    hdr.setUint8(0, 0x52); hdr.setUint8(1, 0x49);
    hdr.setUint8(2, 0x46); hdr.setUint8(3, 0x46); // "RIFF"
    hdr.setUint32(4, 36 + dataSize, Endian.little);
    hdr.setUint8(8, 0x57); hdr.setUint8(9, 0x41);
    hdr.setUint8(10, 0x56); hdr.setUint8(11, 0x45); // "WAVE"
    // fmt
    hdr.setUint8(12, 0x66); hdr.setUint8(13, 0x6D);
    hdr.setUint8(14, 0x74); hdr.setUint8(15, 0x20); // "fmt "
    hdr.setUint32(16, 16, Endian.little);
    hdr.setUint16(20, 1, Endian.little);   // PCM
    hdr.setUint16(22, channels, Endian.little);
    hdr.setUint32(24, sampleRate, Endian.little);
    hdr.setUint32(28, byteRate, Endian.little);
    hdr.setUint16(32, blockAlign, Endian.little);
    hdr.setUint16(34, bitsPerSample, Endian.little);
    // data
    hdr.setUint8(36, 0x64); hdr.setUint8(37, 0x61);
    hdr.setUint8(38, 0x74); hdr.setUint8(39, 0x61); // "data"
    hdr.setUint32(40, dataSize, Endian.little);

    final result = Uint8List(44 + dataSize);
    result.setAll(0, hdr.buffer.asUint8List());
    result.setAll(44, pcm);
    return result;
  }

  void _showTestResult(
    BuildContext context, {
    required double probability,
    required double peakAmplitude,
    required double rmsAmplitude,
    required int capturedBytes,
    String? savedPath,
  }) {
    const double threshold = 0.45;
    final bool isDistress = probability > threshold;
    final String percent = (probability * 100).toStringAsFixed(1);
    final Color color = isDistress ? AppColors.danger : AppColors.success;
    final IconData icon =
        isDistress ? Icons.warning_amber_rounded : Icons.check_circle_rounded;
    final String label = isDistress ? 'DISTRESS' : 'NORMAL';
    final bool isSilent = peakAmplitude < 0.01;
    final int durationMs = (capturedBytes / 2 / AppConstants.sampleRate * 1000).round();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            const Text(
              'Mic Test Result',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),

              // --- Result badge ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$percent% distress score',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // --- Model score bar ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Model score',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Text('${(probability * 100).toStringAsFixed(3)}%',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: probability.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Threshold: 45%  |  Duration: ${durationMs}ms  |  $capturedBytes bytes',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 14),

              // --- Mic amplitude stats ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSilent
                      ? AppColors.danger.withValues(alpha: 0.07)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSilent
                        ? AppColors.danger.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSilent ? Icons.mic_off_rounded : Icons.graphic_eq_rounded,
                          color: isSilent ? AppColors.danger : AppColors.info,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isSilent ? 'MIC SILENT — no audio detected!' : 'Mic Audio Captured',
                          style: TextStyle(
                            color: isSilent ? AppColors.danger : AppColors.info,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _statRow('Peak amplitude',
                        '${(peakAmplitude * 100).toStringAsFixed(1)}%  (${(peakAmplitude * 32767).round()} / 32767)'),
                    _statRow('RMS level',
                        '${(rmsAmplitude * 100).toStringAsFixed(2)}%'),
                    if (isSilent) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'The mic recorded silence. Check:\n'
                        '• App mic permission granted?\n'
                        '• Another app using the mic?\n'
                        '• Restart app and try again.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // --- Saved WAV file path ---
              if (savedPath != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.save_rounded, color: AppColors.success, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'WAV saved:',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        savedPath,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Share WAV File'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.info,
                            side: BorderSide(
                                color: AppColors.info.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          onPressed: () {
                            Share.shareXFiles(
                              [XFile(savedPath)],
                              text: 'SafeGuardHer mic test recording',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runMicTest(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Test Again',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = i);
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
