"""
SafeGuardHer Distress Detection — Flask REST API.

Exposes a TFLite CNN model as a REST service with two endpoints:
    GET  /health   — liveness probe
    POST /predict  — run inference on an audio clip

The preprocessing pipeline in preprocessing.py mirrors the Flutter app exactly,
ensuring prediction scores are consistent between mobile inference and this service.
"""

from __future__ import annotations

import base64
import logging
import os
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from flask import Flask, jsonify, request
from flask_cors import CORS

logger = logging.getLogger(__name__)

# ── Model configuration ──────────────────────────────────────────────────────
MODEL_PATH = Path(os.getenv("MODEL_PATH", Path(__file__).parent / "models" / "cnn_model.tflite"))
DISTRESS_THRESHOLD = float(os.getenv("DISTRESS_THRESHOLD", "0.20"))
MAX_AUDIO_BYTES = 10 * 1024 * 1024  # 10 MB

# ── TFLite interpreter (loaded once at startup) ──────────────────────────────
_interpreter = None
_model_loaded = False


def _load_model() -> None:
    """Load the TFLite interpreter from MODEL_PATH.

    Tries ai_edge_litert first (Python 3.9-3.13, Google's tflite-runtime
    replacement), then tflite_runtime, then tensorflow.lite as final fallback.
    Sets module-level _interpreter and _model_loaded flags.
    """
    global _interpreter, _model_loaded

    Interpreter = None
    try:
        from ai_edge_litert.interpreter import Interpreter  # type: ignore
    except ImportError:
        pass

    if Interpreter is None:
        try:
            from tflite_runtime.interpreter import Interpreter  # type: ignore
        except ImportError:
            pass

    if Interpreter is None:
        try:
            from tensorflow.lite.python.interpreter import Interpreter  # type: ignore
        except ImportError:
            logger.error(
                "No TFLite backend found. Install ai-edge-litert or tensorflow."
            )
            return

    if not MODEL_PATH.exists():
        logger.error("Model file not found: %s", MODEL_PATH)
        return

    try:
        _interpreter = Interpreter(model_path=str(MODEL_PATH))
        _interpreter.allocate_tensors()
        input_details = _interpreter.get_input_details()
        output_details = _interpreter.get_output_details()
        logger.info(
            "Model loaded: input=%s dtype=%s  output=%s",
            input_details[0]["shape"],
            input_details[0]["dtype"],
            output_details[0]["shape"],
        )
        _model_loaded = True
    except Exception as exc:
        logger.exception("Failed to load TFLite model: %s", exc)


def _run_inference(tensor: np.ndarray) -> float:
    """Run TFLite inference and return the sigmoid probability.

    Args:
        tensor: float32 ndarray of shape [1, 128, 94, 1].

    Returns:
        Sigmoid probability in [0, 1].

    Raises:
        RuntimeError: If the interpreter is not loaded or inference fails.
    """
    if not _model_loaded or _interpreter is None:
        raise RuntimeError("TFLite interpreter is not loaded.")

    input_details = _interpreter.get_input_details()
    output_details = _interpreter.get_output_details()

    _interpreter.set_tensor(input_details[0]["index"], tensor)
    _interpreter.invoke()

    output = _interpreter.get_tensor(output_details[0]["index"])
    probability = float(output[0][0])
    logger.debug("Inference probability: %.4f", probability)
    return probability


# ── Flask app factory ────────────────────────────────────────────────────────

def create_app() -> Flask:
    """Create and configure the Flask application.

    Returns:
        Configured Flask instance with CORS enabled.
    """
    app = Flask(__name__)
    CORS(app, resources={r"/*": {"origins": "*"}})

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
        stream=sys.stdout,
    )

    _load_model()

    # ── /health ──────────────────────────────────────────────────────────────

    @app.get("/health")
    def health() -> tuple:
        """Liveness probe.

        Returns:
            JSON: ``{"status": "ok", "model_loaded": bool, "version": "1.0.0"}``
        """
        return jsonify({
            "status": "ok",
            "model_loaded": _model_loaded,
            "version": "1.0.0",
        }), 200

    # ── /predict ─────────────────────────────────────────────────────────────

    @app.post("/predict")
    def predict() -> tuple:
        """Run distress detection on an audio clip.

        Accepts one of:
            - JSON body: ``{"audio_base64": "<base64-encoded audio bytes>"}``
            - Multipart form: field ``audio`` containing the audio file.

        Returns (200):
            JSON::

                {
                    "prediction":  0.87,
                    "label":       "distress",
                    "confidence":  "87%",
                    "timestamp":   "2026-03-05T12:34:56.789012+00:00"
                }

        Error responses:
            400 — missing / malformed input
            413 — audio exceeds 10 MB limit
            422 — preprocessing or decoding failure
            500 — inference failure
        """
        from preprocessing import preprocess_audio  # local import keeps tests fast

        request_id = str(uuid.uuid4())[:8]
        logger.info("[%s] POST /predict  content-type=%s", request_id, request.content_type)

        # ── Extract raw audio bytes from request ──────────────────────────
        audio_bytes: bytes | None = None

        if request.content_type and "multipart/form-data" in request.content_type:
            audio_file = request.files.get("audio")
            if audio_file is None:
                return jsonify({"error": "Multipart request must include an 'audio' field."}), 400
            audio_bytes = audio_file.read()

        elif request.is_json:
            body = request.get_json(silent=True) or {}
            b64_str = body.get("audio_base64")
            if not b64_str:
                return jsonify({"error": "JSON body must contain 'audio_base64'."}), 400
            try:
                audio_bytes = base64.b64decode(b64_str)
            except Exception:
                return jsonify({"error": "Invalid base64 string in 'audio_base64'."}), 400

        else:
            return jsonify({
                "error": "Unsupported Content-Type. Use application/json or multipart/form-data.",
            }), 400

        if len(audio_bytes) == 0:
            return jsonify({"error": "Audio payload is empty."}), 400

        if len(audio_bytes) > MAX_AUDIO_BYTES:
            return jsonify({
                "error": f"Audio exceeds maximum allowed size of {MAX_AUDIO_BYTES // (1024*1024)} MB.",
            }), 413

        logger.info("[%s] Audio bytes: %d", request_id, len(audio_bytes))

        # ── Preprocessing ──────────────────────────────────────────────────
        try:
            tensor = preprocess_audio(audio_bytes)
        except ValueError as exc:
            logger.warning("[%s] Preprocessing failed: %s", request_id, exc)
            return jsonify({"error": f"Preprocessing failed: {exc}"}), 422
        except Exception as exc:
            logger.exception("[%s] Unexpected preprocessing error: %s", request_id, exc)
            return jsonify({"error": "Internal preprocessing error."}), 500

        # ── TFLite inference ───────────────────────────────────────────────
        try:
            probability = _run_inference(tensor)
        except RuntimeError as exc:
            logger.error("[%s] Inference error: %s", request_id, exc)
            return jsonify({"error": str(exc)}), 500
        except Exception as exc:
            logger.exception("[%s] Unexpected inference error: %s", request_id, exc)
            return jsonify({"error": "Inference failed."}), 500

        label = "distress" if probability > DISTRESS_THRESHOLD else "normal"
        confidence = f"{probability * 100:.0f}%"
        timestamp = datetime.now(tz=timezone.utc).isoformat()

        logger.info(
            "[%s] Result: probability=%.4f  label=%s  threshold=%.2f",
            request_id, probability, label, DISTRESS_THRESHOLD,
        )

        return jsonify({
            "prediction": round(probability, 6),
            "label": label,
            "confidence": confidence,
            "timestamp": timestamp,
        }), 200

    return app


# ── Entry point ──────────────────────────────────────────────────────────────

app = create_app()

if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    debug = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    logger.info("Starting SafeGuardHer API on port %d  debug=%s", port, debug)
    app.run(host="0.0.0.0", port=port, debug=debug)
