# ── Build stage ──────────────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build deps (needed for librosa / soundfile native extensions)
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libsndfile1-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Runtime stage ────────────────────────────────────────────────────────────
FROM python:3.11-slim

LABEL maintainer="SafeGuardHer <safeguardher@example.com>"
LABEL description="SafeGuardHer distress-detection inference API"
LABEL version="1.0.0"

WORKDIR /app

# Runtime-only system library for soundfile
RUN apt-get update && apt-get install -y --no-install-recommends \
        libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Copy installed Python packages from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY app.py preprocessing.py ./

# Copy TFLite model (placed relative to this Dockerfile inside flask_service/)
# When building from the project root use:
#   docker build -f flask_service/Dockerfile -t safeguardher-flask .
# and the COPY below will find the model in assets/models/.
COPY assets/models/cnn_model.tflite ./models/cnn_model.tflite

# Non-root user for security
RUN useradd -m appuser
USER appuser

EXPOSE 5000

# Environment defaults (can be overridden at runtime)
ENV MODEL_PATH=/app/models/cnn_model.tflite \
    DISTRESS_THRESHOLD=0.20 \
    PORT=5000 \
    FLASK_DEBUG=false

CMD ["gunicorn", \
     "--bind", "0.0.0.0:5000", \
     "--workers", "2", \
     "--timeout", "60", \
     "--access-logfile", "-", \
     "app:app"]
