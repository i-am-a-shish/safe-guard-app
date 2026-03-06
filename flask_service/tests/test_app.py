"""
pytest test suite for the SafeGuardHer Flask distress-detection API.

Run from the flask_service/ directory:
    pytest tests/ -v --cov=. --cov-report=term-missing

Prerequisites:
    - pip install -r requirements.txt
    - models/cnn_model.tflite must exist (copy from ../assets/models/)
    - The project-root WAV file is used for end-to-end audio tests.
"""

from __future__ import annotations

import base64
import io
import json
import os
import sys
from pathlib import Path

import numpy as np
import pytest

# Add flask_service/ to sys.path so app & preprocessing are importable
sys.path.insert(0, str(Path(__file__).parent.parent))

# ── Fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture(scope="session")
def flask_app():
    """Create the Flask app with testing config, session-scoped for speed."""
    from app import create_app
    application = create_app()
    application.config["TESTING"] = True
    return application


@pytest.fixture(scope="session")
def client(flask_app):
    """Flask test client."""
    return flask_app.test_client()


@pytest.fixture(scope="session")
def real_wav_bytes() -> bytes:
    """Load the muffled-noise WAV fixture from the project root.

    If the file is missing the tests that depend on it are skipped automatically.
    """
    wav_path = Path(__file__).parent.parent.parent / "Muffled Noises_muffled_8_chunk1.wav"
    if not wav_path.exists():
        return b""
    return wav_path.read_bytes()


@pytest.fixture(scope="session")
def synthetic_wav_bytes() -> bytes:
    """Generate a synthetic 2-second 22050 Hz WAV file in memory.

    Used as a fast, dependency-free audio fixture that does not need the
    real WAV file on disk.
    """
    import struct
    import wave

    sample_rate = 22050
    duration_s = 2
    n_samples = sample_rate * duration_s

    # 440 Hz sine wave
    rng = np.random.default_rng(42)
    samples = (rng.uniform(-0.3, 0.3, n_samples) * 32767).astype(np.int16)

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(samples.tobytes())
    return buf.getvalue()


# ── /health tests ─────────────────────────────────────────────────────────────

class TestHealthEndpoint:
    def test_returns_200(self, client):
        response = client.get("/health")
        assert response.status_code == 200

    def test_json_structure(self, client):
        response = client.get("/health")
        data = response.get_json()
        assert "status" in data
        assert data["status"] == "ok"
        assert "model_loaded" in data
        assert "version" in data

    def test_cors_header_present(self, client):
        response = client.get("/health", headers={"Origin": "http://localhost"})
        assert "Access-Control-Allow-Origin" in response.headers


# ── /predict — input validation ──────────────────────────────────────────────

class TestPredictInputValidation:
    def test_no_body_returns_400(self, client):
        response = client.post("/predict", content_type="application/json")
        assert response.status_code == 400

    def test_empty_json_returns_400(self, client):
        response = client.post(
            "/predict",
            data=json.dumps({}),
            content_type="application/json",
        )
        assert response.status_code == 400

    def test_invalid_base64_returns_400(self, client):
        response = client.post(
            "/predict",
            data=json.dumps({"audio_base64": "!!!not-valid-base64!!!"}),
            content_type="application/json",
        )
        assert response.status_code == 400

    def test_valid_base64_but_not_audio_returns_422(self, client):
        garbage = base64.b64encode(b"this is not audio at all").decode()
        response = client.post(
            "/predict",
            data=json.dumps({"audio_base64": garbage}),
            content_type="application/json",
        )
        assert response.status_code == 422

    def test_unsupported_content_type_returns_400(self, client):
        response = client.post(
            "/predict",
            data="raw body",
            content_type="text/plain",
        )
        assert response.status_code == 400

    def test_empty_base64_payload_returns_400(self, client):
        empty_b64 = base64.b64encode(b"").decode()
        response = client.post(
            "/predict",
            data=json.dumps({"audio_base64": empty_b64}),
            content_type="application/json",
        )
        assert response.status_code == 400


# ── /predict — response structure ────────────────────────────────────────────

class TestPredictResponseStructure:
    def test_json_b64_synthetic_audio(self, client, synthetic_wav_bytes):
        """End-to-end test with a synthetic WAV via JSON base64."""
        b64 = base64.b64encode(synthetic_wav_bytes).decode()
        response = client.post(
            "/predict",
            data=json.dumps({"audio_base64": b64}),
            content_type="application/json",
        )
        assert response.status_code == 200
        data = response.get_json()

        assert "prediction" in data
        assert "label" in data
        assert "confidence" in data
        assert "timestamp" in data

        assert 0.0 <= data["prediction"] <= 1.0
        assert data["label"] in ("distress", "normal")
        assert data["confidence"].endswith("%")

    def test_multipart_upload_synthetic_audio(self, client, synthetic_wav_bytes):
        """End-to-end test with a synthetic WAV via multipart upload."""
        response = client.post(
            "/predict",
            data={"audio": (io.BytesIO(synthetic_wav_bytes), "test.wav")},
            content_type="multipart/form-data",
        )
        assert response.status_code == 200
        data = response.get_json()
        assert 0.0 <= data["prediction"] <= 1.0

    def test_cors_header_on_predict(self, client, synthetic_wav_bytes):
        b64 = base64.b64encode(synthetic_wav_bytes).decode()
        response = client.post(
            "/predict",
            data=json.dumps({"audio_base64": b64}),
            content_type="application/json",
            headers={"Origin": "http://localhost:3000"},
        )
        assert "Access-Control-Allow-Origin" in response.headers

    @pytest.mark.skipif(
        not Path(__file__).parent.parent.parent.joinpath(
            "Muffled Noises_muffled_8_chunk1.wav"
        ).exists(),
        reason="Real WAV fixture not present in project root.",
    )
    def test_real_muffled_audio_returns_valid_response(self, client, real_wav_bytes):
        """The muffled-noise sample should produce a valid inference response."""
        b64 = base64.b64encode(real_wav_bytes).decode()
        response = client.post(
            "/predict",
            data=json.dumps({"audio_base64": b64}),
            content_type="application/json",
        )
        assert response.status_code == 200
        data = response.get_json()
        assert 0.0 <= data["prediction"] <= 1.0
        assert data["label"] in ("distress", "normal")
        assert data["confidence"].endswith("%")


# ── preprocessing unit tests ──────────────────────────────────────────────────

class TestPreprocessing:
    def test_output_shape(self, synthetic_wav_bytes):
        from preprocessing import preprocess_audio
        tensor = preprocess_audio(synthetic_wav_bytes)
        assert tensor.shape == (1, 128, 94, 1)

    def test_output_dtype(self, synthetic_wav_bytes):
        from preprocessing import preprocess_audio
        tensor = preprocess_audio(synthetic_wav_bytes)
        assert tensor.dtype == np.float32

    def test_output_range(self, synthetic_wav_bytes):
        from preprocessing import preprocess_audio
        tensor = preprocess_audio(synthetic_wav_bytes)
        # Z-score normalised: values are centred around 0 with std ~1.
        # Real audio stays within a few standard deviations; padded zeros map to
        # (0 - (-49.6)) / 20.54 ≈ +2.41 so max is slightly above 0.
        assert float(tensor.min()) >= -10.0
        assert float(tensor.max()) <= 10.0

    def test_invalid_audio_raises_value_error(self):
        from preprocessing import preprocess_audio
        with pytest.raises(ValueError):
            preprocess_audio(b"not audio data at all 12345")
