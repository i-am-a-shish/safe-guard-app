import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../core/constants.dart';

/// TFLite model inference service for distress detection.
/// Loads the CNN model and runs inference on mel spectrograms.
class TfliteService {
  static Interpreter? _interpreter;
  static bool _isInitialized = false;

  /// Initialize the TFLite interpreter
  static Future<bool> init() async {
    // If already initialized, skip
    if (_isInitialized && _interpreter != null) {
      debugPrint('TfliteService: Already initialized, skipping.');
      return true;
    }

    try {
      debugPrint('TfliteService: Loading model from "${AppConstants.modelPath}"...');

      _interpreter = await Interpreter.fromAsset(AppConstants.modelPath);
      _isInitialized = true;

      // Log model details
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      debugPrint('TfliteService: ✅ Model loaded successfully.');
      debugPrint('TfliteService: Input shape: ${inputTensor.shape}, type: ${inputTensor.type}');
      debugPrint('TfliteService: Output shape: ${outputTensor.shape}, type: ${outputTensor.type}');

      return true;
    } catch (e, stackTrace) {
      debugPrint('TfliteService: ❌ Failed to load model: $e');
      debugPrint('TfliteService: Stack trace: $stackTrace');
      _isInitialized = false;
      _interpreter = null;
      return false;
    }
  }

  /// Run inference on a preprocessed mel spectrogram
  /// Input: Float32List of shape [1, 128, 94, 1]
  /// Output: Single float32 value between 0-1 (sigmoid probability)
  static double? runInference(Float32List spectrogramData) {
    if (!_isInitialized || _interpreter == null) {
      debugPrint('TfliteService: ⚠️ Interpreter not initialized (initialized=$_isInitialized, interpreter=${_interpreter != null}).');
      return null;
    }

    try {
      // Validate input size
      final expectedSize = 1 * AppConstants.melBands * AppConstants.melFrames * 1;
      if (spectrogramData.length != expectedSize) {
        debugPrint('TfliteService: ⚠️ Input size mismatch: got ${spectrogramData.length}, expected $expectedSize');
        return null;
      }

      // Reshape input to [1, 128, 94, 1]
      final input = spectrogramData.reshape([
        1,
        AppConstants.melBands,
        AppConstants.melFrames,
        1,
      ]);

      // Debug: log input tensor statistics to confirm model received audio
      double minVal = double.infinity, maxVal = double.negativeInfinity, sum = 0.0;
      for (final v in spectrogramData) {
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
        sum += v;
      }
      final mean = sum / spectrogramData.length;
      debugPrint(
        'TfliteService: 📊 Input tensor stats — '
        'min: ${minVal.toStringAsFixed(4)}  '
        'max: ${maxVal.toStringAsFixed(4)}  '
        'mean: ${mean.toStringAsFixed(4)}  '
        'size: ${spectrogramData.length}'
      );
      debugPrint('TfliteService: 🚀 Running inference on model...');

      // Prepare output buffer [1, 1]
      final output = List.filled(1, List.filled(1, 0.0));

      // Run inference
      _interpreter!.run(input, output);

      final probability = output[0][0];
      debugPrint('TfliteService: ✅ Model inference complete — probability: ${probability.toStringAsFixed(6)}');

      return probability;
    } catch (e, stackTrace) {
      debugPrint('TfliteService: ❌ Inference error: $e');
      debugPrint('TfliteService: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Check if a detection probability exceeds the threshold
  static bool isDistressDetected(double probability, double threshold) {
    return probability > threshold;
  }

  /// Dispose the interpreter
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    debugPrint('TfliteService: Interpreter disposed.');
  }

  static bool get isInitialized => _isInitialized;
}
