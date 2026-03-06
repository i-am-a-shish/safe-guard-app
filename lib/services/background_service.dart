import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:record/record.dart';
import '../core/constants.dart';
import '../services/audio_processing_service.dart';
import '../services/tflite_service.dart';
import '../services/alert_service.dart';
import '../services/storage_service.dart';

/// Background service for continuous audio monitoring and distress detection.
/// Runs as an Android foreground service with a persistent notification.
@pragma('vm:entry-point')
class BackgroundServiceManager {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _isRunning = false;

  /// Initialize background service
  static Future<void> init() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: AppConstants.notificationChannelId,
        initialNotificationTitle: AppConstants.notificationTitle,
        initialNotificationContent: AppConstants.notificationBody,
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.microphone],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    debugPrint('BackgroundServiceManager: Service configured.');
  }

  /// Start the background service (idempotent – checks if already running first)
  static Future<void> startService() async {
    // Avoid launching a duplicate audio pipeline if service is already running
    final alreadyRunning = await _service.isRunning();
    if (alreadyRunning) {
      _isRunning = true;
      debugPrint('BackgroundServiceManager: Service already running – no restart needed.');
      return;
    }
    await _service.startService();
    _isRunning = true;
    debugPrint('BackgroundServiceManager: Service started.');
  }

  /// Stop the background service
  static Future<void> stopService() async {
    _service.invoke('stopService');
    _isRunning = false;
    debugPrint('BackgroundServiceManager: Service stopped.');
  }

  static bool get isRunning => _isRunning;

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  /// Main background service entry point
  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    debugPrint('BackgroundService: ═══════════════════════════════════════');
    debugPrint('BackgroundService: Starting audio monitoring pipeline...');
    debugPrint('BackgroundService: ═══════════════════════════════════════');

    // Initialize services
    try {
      await StorageService.init();
      debugPrint('BackgroundService: ✅ StorageService initialized');
    } catch (e) {
      debugPrint('BackgroundService: ❌ StorageService init failed: $e');
    }

    AudioProcessingService.init();
    debugPrint('BackgroundService: ✅ AudioProcessingService initialized');

    bool modelLoaded = false;
    try {
      modelLoaded = await TfliteService.init();
      debugPrint('BackgroundService: ${modelLoaded ? "✅" : "❌"} TfliteService.init() returned $modelLoaded');
    } catch (e) {
      debugPrint('BackgroundService: ❌ TfliteService init exception: $e');
    }

    if (!modelLoaded) {
      debugPrint('BackgroundService: ❌ Failed to load model. Will retry once...');
      // Retry once after a brief delay – the TFLite delegate sometimes needs
      // a moment on cold start.
      await Future.delayed(const Duration(seconds: 2));
      try {
        modelLoaded = await TfliteService.init();
        debugPrint('BackgroundService: Retry – TfliteService.init() returned $modelLoaded');
      } catch (e) {
        debugPrint('BackgroundService: Retry – TfliteService init exception: $e');
      }

      if (!modelLoaded) {
        debugPrint('BackgroundService: ❌ Model failed to load after retry. Stopping service.');
        service.stopSelf();
        return;
      }
    }

    // Update notification for Android
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: AppConstants.notificationTitle,
        content: 'Actively monitoring for distress sounds...',
      );
    }

    // Listen for stop command
    service.on('stopService').listen((event) async {
      debugPrint('BackgroundService: Received stop command.');
      TfliteService.dispose();
      await service.stopSelf();
    });

    // Start the audio monitoring loop
    _startAudioPipeline(service);
  }

  // ── Low-sound sensitivity helpers ──────────────────────────────────────────

  /// Software gain applied to every audio window before model inference.
  /// 4.0x ≈ +12 dB ensures whispers / muffled sounds reach the model with
  /// sufficient energy. Change to 1.0 to disable.
  static const double _audioGain = 4.0;

  /// Compute RMS of raw PCM-16 bytes, normalised to [0.0, 1.0].
  static double _computeRMS(Uint8List audioBytes) {
    if (audioBytes.length < 2) return 0.0;
    final int16List = Int16List.view(audioBytes.buffer);
    if (int16List.isEmpty) return 0.0;
    double sumSq = 0.0;
    for (final sample in int16List) {
      final norm = sample / 32768.0;
      sumSq += norm * norm;
    }
    return sqrt(sumSq / int16List.length);
  }

  /// Apply software gain to raw PCM-16 bytes, clamping to avoid int16 overflow.
  /// Even very quiet sounds become visible to the model after amplification.
  static Uint8List _amplifyAudio(Uint8List audioBytes, double gain) {
    if (gain == 1.0) return audioBytes;
    final src = Int16List.view(audioBytes.buffer);
    final dst = Int16List(src.length);
    for (int i = 0; i < src.length; i++) {
      dst[i] = (src[i] * gain).round().clamp(-32768, 32767);
    }
    return dst.buffer.asUint8List();
  }

  /// Audio pipeline: Record → Process → Infer → Alert
  static Future<void> _startAudioPipeline(ServiceInstance service) async {
    final recorder = AudioRecorder();

    // Check microphone permission first
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      debugPrint('BackgroundService: ❌ No microphone permission! Cannot start audio pipeline.');
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: '⚠️ Mic Permission Denied',
          content: 'Please grant microphone permission to enable monitoring.',
        );
      }
      return;
    }
    debugPrint('BackgroundService: ✅ Microphone permission granted');

    // Configure recording
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: AppConstants.sampleRate,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    );

    // Start streaming audio
    Stream<Uint8List> stream;
    try {
      stream = await recorder.startStream(config);
      debugPrint('BackgroundService: ✅ Audio stream started at ${AppConstants.sampleRate}Hz.');
    } catch (e) {
      debugPrint('BackgroundService: ❌ Failed to start audio stream: $e');
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: '⚠️ Audio Error',
          content: 'Failed to start microphone: $e',
        );
      }
      service.stopSelf();
      return;
    }

    // Exact number of samples needed for 94 mel frames:
    // (nFrames-1)*hopLength + fftSize = (94-1)*512 + 2048 = 49664 samples
    // At 16-bit PCM (2 bytes per sample): 49664 * 2 = 99328 bytes
    const int targetSamples = (AppConstants.melFrames - 1) * 512 + 2048; // 49664
    const int targetBytes = targetSamples * 2; // 99328 bytes
    // Stride: advance by half buffer → 50% overlap → process every ~1.1s of new audio
    const int strideBytes = targetBytes ~/ 2; // ~49664 bytes

    // Buffer to accumulate audio chunks
    List<int> audioBuffer = [];
    int chunkCount = 0;
    int inferenceCount = 0;

    stream.listen(
      (data) async {
        chunkCount++;
        audioBuffer.addAll(data);

        if (chunkCount % 20 == 0) {
          debugPrint('BackgroundService: 🎤 Received $chunkCount audio chunks, buffer size: ${audioBuffer.length}/$targetBytes bytes');
        }

        // Process whenever we have a full window of audio
        if (audioBuffer.length >= targetBytes) {
          final audioBytes = Uint8List.fromList(audioBuffer.sublist(0, targetBytes));
          // Slide forward by stride (50% overlap keeps context from previous window)
          audioBuffer = audioBuffer.sublist(strideBytes);

          inferenceCount++;

          // ── Debug: RMS of raw captured audio ─────────────────────────────
          final rawRms = _computeRMS(audioBytes);
          debugPrint(
            'BackgroundService: 🎤 [#$inferenceCount] Raw audio RMS: ${rawRms.toStringAsFixed(6)}'
            '  bytes: ${audioBytes.length}'
            '  ${rawRms < 0.001 ? "(very quiet)" : rawRms < 0.01 ? "(quiet)" : "(audible)"}'
          );

          // ── Amplify audio for low-sound sensitivity ───────────────────────
          final amplifiedBytes = _amplifyAudio(audioBytes, _audioGain);
          final ampRms = _computeRMS(amplifiedBytes);
          debugPrint(
            'BackgroundService: 🔊 [#$inferenceCount] After amplification (${_audioGain}x):'
            '  RMS: ${ampRms.toStringAsFixed(6)}'
          );

          try {
            // 1. Convert amplified audio to mel spectrogram
            debugPrint('BackgroundService: 📤 [#$inferenceCount] Sending audio to ML model (spectrogram preprocessing)...');
            final spectrogram = AudioProcessingService.processAudioToSpectrogram(amplifiedBytes);
            debugPrint('BackgroundService: ✅ [#$inferenceCount] Spectrogram ready — tensor size: ${spectrogram.length}  sending to TFLite...');

            // 2. Run TFLite inference
            final probability = TfliteService.runInference(spectrogram);

            if (probability != null) {
              final threshold = StorageService.getThreshold();
              debugPrint(
                'BackgroundService: 🧠 Inference #$inferenceCount: probability=${probability.toStringAsFixed(4)} (threshold=$threshold) ${probability > threshold ? "⚠️ DISTRESS" : "✅ normal"}'
              );

              // 3. Trigger alert if above threshold
              if (TfliteService.isDistressDetected(probability, threshold)) {
                debugPrint('BackgroundService: ⚠️ DISTRESS DETECTED! Triggering alert...');

                // Update notification
                if (service is AndroidServiceInstance) {
                  service.setForegroundNotificationInfo(
                    title: '⚠️ DISTRESS DETECTED',
                    content: 'Emergency alert triggered! Confidence: ${(probability * 100).toStringAsFixed(1)}%',
                  );
                }

                // Trigger alert pipeline
                await AlertService.triggerAlert(
                  type: 'auto',
                  confidence: probability,
                );

                // Send update to UI
                service.invoke('alertTriggered', {
                  'probability': probability,
                  'timestamp': DateTime.now().toIso8601String(),
                });

                // Reset notification after delay
                Future.delayed(const Duration(seconds: 10), () {
                  if (service is AndroidServiceInstance) {
                    service.setForegroundNotificationInfo(
                      title: AppConstants.notificationTitle,
                      content: 'Actively monitoring for distress sounds...',
                    );
                  }
                });
              }

              // Send status update to UI
              service.invoke('detectionUpdate', {
                'probability': probability,
                'threshold': threshold,
                'isDistress': probability > threshold,
              });
            } else {
              debugPrint('BackgroundService: ⚠️ Inference #$inferenceCount returned null — model may not be initialized');
            }
          } catch (e) {
            debugPrint('BackgroundService: ❌ Processing error on inference #$inferenceCount: $e');
          }
        }
      },
      onError: (error) {
        debugPrint('BackgroundService: ❌ Audio stream error: $error');
      },
      cancelOnError: false,
    );
  }
}
