# SafeGuardHer — Flask Distress Detection API

REST service that exposes the SafeGuardHer CNN model as an HTTP API.
Mirrors the exact audio preprocessing pipeline used in the Flutter app, so
prediction scores are consistent across both surfaces.

---

## Endpoints

| Method | Path       | Description                    |
|--------|------------|--------------------------------|
| GET    | `/health`  | Liveness probe                 |
| POST   | `/predict` | Run inference on an audio clip |

### `POST /predict` — request formats

**JSON (base64)**
```json
{
  "audio_base64": "<base64-encoded audio bytes>"
}
```

**Multipart form upload**
```
audio=<binary audio file>
```

### `POST /predict` — response
```json
{
  "prediction":  0.872341,
  "label":       "distress",
  "confidence":  "87%",
  "timestamp":   "2026-03-05T12:34:56.789012+00:00"
}
```

`label` is `"distress"` when `prediction > 0.20` (matches the Flutter threshold).

---

## Quick Start — Local Python

**Prerequisites:** Python 3.11, pip

```bash
# 1. Enter the flask_service directory
cd "flask_service"

# 2. Create + activate a virtual environment (recommended)
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Copy the TFLite model
mkdir -p models
cp ../assets/models/cnn_model.tflite models/cnn_model.tflite

# 5. Run the development server
python app.py
```

The API is now available at `http://localhost:5000`.

---

## Quick Start — Docker

Build from the **project root** (so the model COPY path resolves correctly):

```bash
# Build
docker build -f flask_service/Dockerfile -t safeguardher-flask .

# Run
docker run --rm -p 5000:5000 safeguardher-flask
```

The API is available at `http://localhost:5000`.

### Environment variables

| Variable             | Default                              | Description                    |
|----------------------|--------------------------------------|--------------------------------|
| `MODEL_PATH`         | `/app/models/cnn_model.tflite`       | Absolute path to the model     |
| `DISTRESS_THRESHOLD` | `0.20`                               | Sigmoid threshold for "distress" label |
| `PORT`               | `5000`                               | HTTP port                      |
| `FLASK_DEBUG`        | `false`                              | Enable Flask debug mode        |

---

## curl Examples

### Health check
```bash
curl http://localhost:5000/health
```
Expected:
```json
{"model_loaded": true, "status": "ok", "version": "1.0.0"}
```

### Predict — base64 JSON
```bash
# Encode a WAV file
AUDIO_B64=$(base64 -w 0 "Muffled Noises_muffled_8_chunk1.wav")

curl -X POST http://localhost:5000/predict \
  -H "Content-Type: application/json" \
  -d "{\"audio_base64\": \"$AUDIO_B64\"}"
```

### Predict — multipart upload
```bash
curl -X POST http://localhost:5000/predict \
  -F "audio=@Muffled Noises_muffled_8_chunk1.wav"
```

---

## Running Tests

```bash
cd flask_service

# Make sure the model is in place
mkdir -p models
cp ../assets/models/cnn_model.tflite models/cnn_model.tflite

# Run all tests with coverage
pytest tests/ -v --cov=. --cov-report=term-missing
```

---

## Flutter Client

Add the `http` package to your Flutter app:

```yaml
# pubspec.yaml
dependencies:
  http: ^1.2.2
```

Then use `lib/services/api_service.dart`:

```dart
import 'dart:io';
import 'package:your_app/services/api_service.dart';

final File audioFile = File('/path/to/recorded_audio.wav');
final PredictionResult? result = await ApiService.getPrediction(audioFile);

if (result != null) {
  print('Label: ${result.label}');       // "distress" or "normal"
  print('Score: ${result.prediction}');  // 0.0 – 1.0
}
```

**Host configuration:**

| Scenario              | Host                     |
|-----------------------|--------------------------|
| Android emulator      | `http://10.0.2.2:5000`   |
| Physical device (USB) | `http://<your-LAN-IP>:5000` |
| Docker / production   | Set `ApiService.baseUrl` |

---

## Model Notes

- **File**: `assets/models/cnn_model.tflite` (432 KB)
- **Input**: `[1, 128, 94, 1]`  float32  (128 mel bands × 94 time frames)
- **Output**: single float32 in [0, 1]  (sigmoid probability)
- **Threshold**: `> 0.20` → distress  (matches `AppConstants.defaultThreshold`)
- **Expected audio**: ~2.18 s at 22050 Hz; shorter clips are zero-padded
