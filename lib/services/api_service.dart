import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Result returned by [ApiService.getPrediction].
class PredictionResult {
  /// Sigmoid probability in [0, 1].
  final double prediction;

  /// `"distress"` when [prediction] exceeds the server threshold, else `"normal"`.
  final String label;

  /// Human-readable confidence string, e.g. `"87%"`.
  final String confidence;

  /// UTC timestamp of when the inference was performed.
  final DateTime timestamp;

  const PredictionResult({
    required this.prediction,
    required this.label,
    required this.confidence,
    required this.timestamp,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      prediction: (json['prediction'] as num).toDouble(),
      label: json['label'] as String,
      confidence: json['confidence'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  bool get isDistress => label == 'distress';
}

/// HTTP client for the SafeGuardHer Flask inference API.
///
/// Usage:
/// ```dart
/// final File audioFile = File('/path/to/recorded.wav');
/// final PredictionResult? result = await ApiService.getPrediction(audioFile);
/// if (result != null && result.isDistress) { /* handle alert */ }
/// ```
///
/// Configure [baseUrl] to match your deployment:
/// - Android emulator → `http://10.0.2.2:5000`  (default)
/// - Physical device  → `http://<LAN-IP>:5000`
/// - Production       → your hosted domain
class ApiService {
  /// Base URL of the Flask service.
  ///
  /// Override at runtime via [setBaseUrl] or by setting [baseUrl] directly
  /// before the first call.
  static String baseUrl = 'http://10.0.2.2:5000';

  static const Duration _timeout = Duration(seconds: 30);

  ApiService._();

  /// Update the Flask service base URL at runtime.
  static void setBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Check whether the Flask service is reachable and the model is loaded.
  ///
  /// Returns `true` if the service responds with `{"model_loaded": true}`.
  static Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(_timeout);
      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['model_loaded'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Send [audioFile] to the `/predict` endpoint and return the result.
  ///
  /// The audio is base64-encoded and sent as JSON so no multipart boundary
  /// handling is needed on the client.
  ///
  /// Returns `null` on network error, timeout, or a non-200 response.
  /// Shows a [SnackBar] via [context] when an error occurs (pass `null` to
  /// suppress UI feedback).
  static Future<PredictionResult?> getPrediction(
    File audioFile, {
    BuildContext? context,
  }) async {
    // Capture ScaffoldMessengerState BEFORE any async gap so we never access
    // BuildContext after an await (fixes use_build_context_synchronously).
    final ScaffoldMessengerState? messenger =
        (context != null && context.mounted)
            ? ScaffoldMessenger.of(context)
            : null;

    final List<int> bytes;
    try {
      bytes = await audioFile.readAsBytes();
    } catch (e) {
      _showError(messenger, 'Could not read audio file: $e');
      return null;
    }

    final String audioBase64 = base64Encode(bytes);

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'audio_base64': audioBase64}),
          )
          .timeout(_timeout);
    } on SocketException {
      _showError(messenger, 'Cannot reach inference server. Check your network.');
      return null;
    } catch (e) {
      _showError(messenger, 'Inference request failed: $e');
      return null;
    }

    if (response.statusCode != 200) {
      final message = _extractErrorMessage(response.body);
      _showError(messenger, 'Server error (${response.statusCode}): $message');
      return null;
    }

    try {
      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      return PredictionResult.fromJson(json);
    } catch (e) {
      _showError(messenger, 'Invalid response from server.');
      return null;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static String _extractErrorMessage(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      return json['error']?.toString() ?? responseBody;
    } catch (_) {
      return responseBody.length > 120
          ? '${responseBody.substring(0, 120)}…'
          : responseBody;
    }
  }

  static void _showError(ScaffoldMessengerState? messenger, String message) {
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
