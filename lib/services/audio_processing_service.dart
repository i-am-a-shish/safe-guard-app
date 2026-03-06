import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

/// Audio preprocessing service that converts raw PCM audio to mel spectrograms
/// for the CNN model inference.
class AudioProcessingService {
  // Mel filter bank parameters
  static const int _fftSize = 2048;
  static const int _hopLength = 512;
  static const int _nMels = AppConstants.melBands; // 128
  static const int _nFrames = AppConstants.melFrames; // 94
  static const double _fMin = 0.0;
  static const double _fMax = 8000.0; // sr/2 for 16000 Hz (matches training)

  static List<List<double>>? _melFilterBank;

  /// Initialize the mel filter bank (call once at startup)
  static void init() {
    _melFilterBank = _createMelFilterBank();
    debugPrint('AudioProcessingService: Mel filter bank initialized.');
  }

  /// Convert raw PCM audio bytes to mel spectrogram [128, 94]
  /// Input: Raw PCM 16-bit audio at 16000 Hz
  /// Output: Z-score normalised Float32List shaped [1, 128, 94, 1]
  ///
  /// Pipeline matches the training notebook exactly:
  ///   bytes → float → STFT → mel filterbank → log-dB → z-score → reshape
  static Float32List processAudioToSpectrogram(Uint8List audioBytes) {
    // Convert bytes to float samples
    final samples = _bytesToFloatSamples(audioBytes);

    // Compute STFT
    final stft = _computeSTFT(samples);

    // Apply mel filter bank
    final melSpec = _applyMelFilterBank(stft);

    // Convert to log scale (dB)
    final logMelSpec = _toLogScale(melSpec);

    // Z-score normalise using global training stats
    final normalized = _zScoreNormalize(logMelSpec);

    // Reshape to [1, 128, 94, 1] Float32List
    return _reshapeForModel(normalized);
  }

  /// Convert 16-bit PCM bytes to float samples [-1.0, 1.0]
  static List<double> _bytesToFloatSamples(Uint8List bytes) {
    final int16List = Int16List.view(bytes.buffer);
    return List<double>.generate(
      int16List.length,
      (i) => int16List[i] / 32768.0,
    );
  }

  /// Compute Short-Time Fourier Transform (STFT)
  static List<List<double>> _computeSTFT(List<double> samples) {
    final numFrames = _nFrames;
    final spectrogramWidth = _fftSize ~/ 2 + 1;
    final stft = List<List<double>>.generate(
      numFrames,
      (_) => List<double>.filled(spectrogramWidth, 0.0),
    );

    for (int frame = 0; frame < numFrames; frame++) {
      final start = frame * _hopLength;

      // Extract frame with Hann window
      final windowedFrame = List<double>.filled(_fftSize, 0.0);
      for (int i = 0; i < _fftSize; i++) {
        final sampleIdx = start + i;
        final sample = sampleIdx < samples.length ? samples[sampleIdx] : 0.0;
        // Hann window
        final window = 0.5 * (1.0 - cos(2.0 * pi * i / (_fftSize - 1)));
        windowedFrame[i] = sample * window;
      }

      // Compute FFT magnitude
      final magnitudes = _computeFFTMagnitude(windowedFrame);
      for (int i = 0; i < spectrogramWidth && i < magnitudes.length; i++) {
        stft[frame][i] = magnitudes[i];
      }
    }

    return stft;
  }

  /// Compute FFT magnitude spectrum using Cooley-Tukey radix-2 DIT
  static List<double> _computeFFTMagnitude(List<double> input) {
    final n = input.length;
    // Ensure power of 2
    assert((n & (n - 1)) == 0, 'FFT size must be power of 2');

    // Initialize real and imaginary parts
    final real = List<double>.from(input);
    final imag = List<double>.filled(n, 0.0);

    // Bit-reversal permutation
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      while (j >= bit) {
        j -= bit;
        bit >>= 1;
      }
      j += bit;
      if (i < j) {
        // Swap real
        final tempR = real[i];
        real[i] = real[j];
        real[j] = tempR;
        // Swap imag
        final tempI = imag[i];
        imag[i] = imag[j];
        imag[j] = tempI;
      }
    }

    // FFT butterfly operations
    for (int size = 2; size <= n; size *= 2) {
      final halfSize = size ~/ 2;
      final angle = -2.0 * pi / size;
      final wR = cos(angle);
      final wI = sin(angle);

      for (int k = 0; k < n; k += size) {
        double curR = 1.0;
        double curI = 0.0;

        for (int m = 0; m < halfSize; m++) {
          final u = k + m;
          final v = k + m + halfSize;

          final tR = curR * real[v] - curI * imag[v];
          final tI = curR * imag[v] + curI * real[v];

          real[v] = real[u] - tR;
          imag[v] = imag[u] - tI;
          real[u] = real[u] + tR;
          imag[u] = imag[u] + tI;

          final newCurR = curR * wR - curI * wI;
          final newCurI = curR * wI + curI * wR;
          curR = newCurR;
          curI = newCurI;
        }
      }
    }

    // Compute magnitude (only first half + 1)
    final halfN = n ~/ 2 + 1;
    final magnitudes = List<double>.filled(halfN, 0.0);
    for (int i = 0; i < halfN; i++) {
      magnitudes[i] = sqrt(real[i] * real[i] + imag[i] * imag[i]);
    }

    return magnitudes;
  }

  /// Create mel filter bank
  static List<List<double>> _createMelFilterBank() {
    final spectrogramBins = _fftSize ~/ 2 + 1;
    final filterBank = List<List<double>>.generate(
      _nMels,
      (_) => List<double>.filled(spectrogramBins, 0.0),
    );

    final melMin = _hzToMel(_fMin);
    final melMax = _hzToMel(_fMax);
    final melPoints = List<double>.generate(
      _nMels + 2,
      (i) => melMin + i * (melMax - melMin) / (_nMels + 1),
    );

    final hzPoints = melPoints.map(_melToHz).toList();
    final binPoints = hzPoints
        .map((hz) => ((hz * _fftSize) / AppConstants.sampleRate).floor())
        .toList();

    for (int i = 0; i < _nMels; i++) {
      for (int j = binPoints[i]; j < binPoints[i + 1] && j < spectrogramBins; j++) {
        filterBank[i][j] = (j - binPoints[i]) / (binPoints[i + 1] - binPoints[i]);
      }
      for (int j = binPoints[i + 1]; j < binPoints[i + 2] && j < spectrogramBins; j++) {
        filterBank[i][j] = (binPoints[i + 2] - j) / (binPoints[i + 2] - binPoints[i + 1]);
      }
    }

    return filterBank;
  }

  /// Apply mel filter bank to STFT output
  static List<List<double>> _applyMelFilterBank(List<List<double>> stft) {
    _melFilterBank ??= _createMelFilterBank();

    final melSpec = List<List<double>>.generate(
      _nFrames,
      (_) => List<double>.filled(_nMels, 0.0),
    );

    for (int frame = 0; frame < _nFrames && frame < stft.length; frame++) {
      for (int mel = 0; mel < _nMels; mel++) {
        double sum = 0.0;
        final bins = min(stft[frame].length, _melFilterBank![mel].length);
        for (int bin = 0; bin < bins; bin++) {
          sum += stft[frame][bin] * stft[frame][bin] * _melFilterBank![mel][bin];
        }
        melSpec[frame][mel] = sum;
      }
    }

    return melSpec;
  }

  /// Convert to log scale (dB)
  static List<List<double>> _toLogScale(List<List<double>> melSpec) {
    const double amin = 1e-10;
    const double refValue = 1.0;
    const double topDb = 80.0;

    final logSpec = List<List<double>>.generate(
      melSpec.length,
      (i) => List<double>.generate(
        melSpec[i].length,
        (j) => 10.0 * log(max(melSpec[i][j], amin) / refValue) / ln10,
      ),
    );

    // Clip to top_db
    double maxVal = -double.infinity;
    for (final row in logSpec) {
      for (final val in row) {
        if (val > maxVal) maxVal = val;
      }
    }

    for (int i = 0; i < logSpec.length; i++) {
      for (int j = 0; j < logSpec[i].length; j++) {
        logSpec[i][j] = max(logSpec[i][j], maxVal - topDb);
      }
    }

    return logSpec;
  }

  /// Z-score normalise using the global mean and std from training.
  /// Formula: (value - mean) / std  — matches training notebook exactly.
  static List<List<double>> _zScoreNormalize(List<List<double>> spec) {
    const double mean = AppConstants.normMean; // -49.602452774109494
    const double std = AppConstants.normStd;   // 20.54078017353221

    return List<List<double>>.generate(
      spec.length,
      (i) => List<double>.generate(
        spec[i].length,
        (j) => (spec[i][j] - mean) / std,
      ),
    );
  }

  /// Reshape normalized mel spectrogram to model input [1, 128, 94, 1]
  static Float32List _reshapeForModel(List<List<double>> normalized) {
    // Model expects [1, 128, 94, 1] - (batch, height=mel_bands, width=frames, channels)
    final output = Float32List(1 * _nMels * _nFrames * 1);

    for (int frame = 0; frame < _nFrames && frame < normalized.length; frame++) {
      for (int mel = 0; mel < _nMels && mel < normalized[frame].length; mel++) {
        // Index: batch * (128*94*1) + mel * (94*1) + frame * 1 + channel
        output[mel * _nFrames + frame] = normalized[frame][mel];
      }
    }

    return output;
  }

  // ---- Helper functions ----

  static double _hzToMel(double hz) {
    return 2595.0 * log(1.0 + hz / 700.0) / ln10;
  }

  static double _melToHz(double mel) {
    return 700.0 * (pow(10.0, mel / 2595.0) - 1.0);
  }
}
