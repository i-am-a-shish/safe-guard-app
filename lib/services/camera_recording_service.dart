import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

/// Camera recording service that captures video evidence from the back camera
/// when a distress event is detected. Recordings are stored locally AND
/// saved to the device gallery so the user can view them easily.
class CameraRecordingService {
  static CameraController? _controller;
  static bool _isRecording = false;
  static bool _isInitialized = false;
  static List<CameraDescription>? _cameras;

  /// Duration for distress recording (30 seconds)
  static const int recordingDurationSeconds = 30;

  /// Initialize available cameras
  static Future<bool> init() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        debugPrint('CameraRecordingService: No cameras available.');
        return false;
      }
      debugPrint('CameraRecordingService: Found ${_cameras!.length} camera(s).');
      return true;
    } catch (e) {
      debugPrint('CameraRecordingService: Error initializing cameras: $e');
      return false;
    }
  }

  /// Start recording video from the back camera
  /// Returns the file path of the recording, or null if failed
  static Future<String?> startRecording() async {
    if (_isRecording) {
      debugPrint('CameraRecordingService: Already recording.');
      return null;
    }

    try {
      if (_cameras == null || _cameras!.isEmpty) {
        final initialized = await init();
        if (!initialized) return null;
      }

      // Find back camera (prefer back, fallback to first available)
      final backCamera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      // Create controller with medium resolution for balance of quality/size
      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: true, // Record audio too
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      _isInitialized = true;

      // Generate file path
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${recordingsDir.path}/distress_$timestamp.mp4';

      // Start video recording
      await _controller!.startVideoRecording();
      _isRecording = true;

      debugPrint('CameraRecordingService: 📹 Recording started → $filePath');

      // Auto-stop after duration
      Future.delayed(Duration(seconds: recordingDurationSeconds), () async {
        await stopRecording(filePath);
      });

      return filePath;
    } catch (e) {
      debugPrint('CameraRecordingService: Error starting recording: $e');
      await _cleanup();
      return null;
    }
  }

  /// Stop the current recording and save to the given path + gallery
  static Future<String?> stopRecording([String? targetPath]) async {
    if (!_isRecording || _controller == null) {
      debugPrint('CameraRecordingService: Not recording.');
      return null;
    }

    try {
      final xFile = await _controller!.stopVideoRecording();
      _isRecording = false;

      String finalPath;
      if (targetPath != null) {
        // Move to target path
        final file = File(xFile.path);
        final targetFile = await file.copy(targetPath);
        await file.delete();
        finalPath = targetFile.path;
      } else {
        finalPath = xFile.path;
      }

      debugPrint('CameraRecordingService: 📹 Recording saved → $finalPath');

      // Get file size
      final file = File(finalPath);
      if (await file.exists()) {
        final sizeBytes = await file.length();
        final sizeMB = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
        debugPrint('CameraRecordingService: File size: ${sizeMB}MB');

        // ── Save to device gallery ──
        try {
          final saved = await GallerySaver.saveVideo(finalPath,
              albumName: 'SafeGuardHer');
          if (saved == true) {
            debugPrint(
                'CameraRecordingService: ✅ Video saved to gallery (SafeGuardHer album)');
          } else {
            debugPrint(
                'CameraRecordingService: ⚠️ Gallery save returned false');
          }
        } catch (e) {
          debugPrint(
              'CameraRecordingService: ⚠️ Failed to save to gallery: $e');
        }
      }

      await _cleanup();
      return finalPath;
    } catch (e) {
      debugPrint('CameraRecordingService: Error stopping recording: $e');
      await _cleanup();
      return null;
    }
  }

  /// Clean up camera resources
  static Future<void> _cleanup() async {
    try {
      if (_controller != null) {
        if (_controller!.value.isRecordingVideo) {
          await _controller!.stopVideoRecording();
        }
        await _controller!.dispose();
        _controller = null;
      }
      _isRecording = false;
      _isInitialized = false;
    } catch (e) {
      debugPrint('CameraRecordingService: Cleanup error: $e');
    }
  }

  /// Get all saved recordings
  static Future<List<FileSystemEntity>> getSavedRecordings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');
      if (!await recordingsDir.exists()) return [];
      return recordingsDir.listSync()
          .where((f) => f.path.endsWith('.mp4'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
    } catch (e) {
      debugPrint('CameraRecordingService: Error listing recordings: $e');
      return [];
    }
  }

  /// Delete a recording file
  static Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('CameraRecordingService: Deleted recording: $path');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('CameraRecordingService: Error deleting recording: $e');
      return false;
    }
  }

  /// Dispose all resources
  static Future<void> dispose() async {
    await _cleanup();
  }

  static bool get isRecording => _isRecording;
  static bool get isInitialized => _isInitialized;
}
