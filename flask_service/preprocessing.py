"""
Audio preprocessing pipeline for SafeGuardHer distress detection.

Matches the training notebook (Model_Training_NO_Attention_CNN.ipynb) exactly:

Pipeline:
    1. Decode audio bytes → float32 PCM, resampled to 16000 Hz
    2. Short-time Fourier transform (n_fft=2048, hop=512, Hann window)
    3. 128-band mel filterbank  (fmin=0, fmax=8000 = sr/2)
    4. Power → dB with 80 dB top-clip  (ref=np.max)
    5. Global z-score normalisation: (mel - NORM_MEAN) / NORM_STD
    6. Pad/trim to 94 frames, reshape → [1, 128, 94, 1]

Training constants from normalization_stats.npz:
    mean = -49.602452774109494
    std  =  20.54078017353221
"""

from __future__ import annotations

import io
import logging

import librosa
import numpy as np

logger = logging.getLogger(__name__)

# ── Constants matching training notebook ────────────────────────────────────
SAMPLE_RATE: int = 16000          # training used sr=16000
MEL_BANDS: int = 128
MEL_FRAMES: int = 94
FFT_SIZE: int = 2048
HOP_LENGTH: int = 512
F_MIN: float = 0.0
F_MAX: float = 8000.0             # sr/2 — librosa default for sr=16000
TOP_DB: float = 80.0

# Global z-score stats saved as normalization_stats.npz during training
NORM_MEAN: float = -49.602452774109494
NORM_STD: float = 20.54078017353221


# ── Individual pipeline steps ────────────────────────────────────────────────

def _load_audio(audio_bytes: bytes) -> np.ndarray:
    """Decode raw audio bytes to float32 PCM resampled to 16000 Hz (mono).

    Args:
        audio_bytes: Raw audio file content (WAV, MP3, OGG, ...).

    Returns:
        Mono float32 array.

    Raises:
        ValueError: If audio cannot be decoded or is empty.
    """
    try:
        samples, sr = librosa.load(
            io.BytesIO(audio_bytes),
            sr=SAMPLE_RATE,
            mono=True,
            dtype=np.float32,
        )
    except Exception as exc:
        raise ValueError(f"Failed to decode audio: {exc}") from exc

    if samples.size == 0:
        raise ValueError("Audio is empty after decoding.")

    duration = samples.size / sr
    rms = float(np.sqrt(np.mean(samples ** 2)))
    peak = float(np.abs(samples).max())
    logger.info(
        "[AUDIO INPUT] ✅ Audio received by preprocessing — "
        "samples=%d  duration=%.3fs  RMS=%.6f  peak=%.6f  "
        "%s",
        samples.size, duration, rms, peak,
        "(very quiet — rms<0.001)" if rms < 0.001
        else "(quiet — rms<0.01)" if rms < 0.01
        else "(audible)",
    )
    return samples


def _compute_mel_spectrogram(samples: np.ndarray) -> np.ndarray:
    """Compute a 128-band log-mel spectrogram matching the training pipeline.

    Uses librosa defaults for sr=16000:
        n_fft=2048, hop_length=512, n_mels=128, fmin=0, fmax=8000

    Args:
        samples: Float32 audio samples at SAMPLE_RATE.

    Returns:
        Log-mel spectrogram of shape [MEL_BANDS, n_frames] (float32).
    """
    mel_spec = librosa.feature.melspectrogram(
        y=samples,
        sr=SAMPLE_RATE,
        n_fft=FFT_SIZE,
        hop_length=HOP_LENGTH,
        n_mels=MEL_BANDS,
        fmin=F_MIN,
        fmax=F_MAX,
        power=2.0,
    )

    # Power -> dB, reference at max, TOP_DB clip -- matches librosa.power_to_db defaults
    log_mel = librosa.power_to_db(mel_spec, ref=np.max, top_db=TOP_DB)

    logger.info(
        "[SPECTROGRAM] shape=%s  min=%.4f  max=%.4f  mean=%.4f",
        log_mel.shape, log_mel.min(), log_mel.max(), log_mel.mean(),
    )
    return log_mel.astype(np.float32)


def _zscore_normalize(spec: np.ndarray) -> np.ndarray:
    """Global z-score normalisation using training statistics.

    Formula: (spec - NORM_MEAN) / NORM_STD
    Matches: mel = (mel - mean) / std  in the training notebook.

    Args:
        spec: Log-mel spectrogram of any shape (float32).

    Returns:
        Normalised float32 array.
    """
    return ((spec - NORM_MEAN) / NORM_STD).astype(np.float32)


def _pad_or_trim(spec: np.ndarray, target_frames: int = MEL_FRAMES) -> np.ndarray:
    """Ensure the spectrogram has exactly *target_frames* time frames.

    - Shorter clips: zero-padded on the right.
    - Longer clips:  trimmed from the right.

    Args:
        spec:          Log-mel spectrogram of shape [MEL_BANDS, n_frames].
        target_frames: Required number of time frames (default 94).

    Returns:
        Spectrogram of shape [MEL_BANDS, target_frames] (float32).
    """
    n_frames = spec.shape[1]
    if n_frames < target_frames:
        spec = np.pad(spec, ((0, 0), (0, target_frames - n_frames)), mode="constant")
        logger.debug("Padded spectrogram: %d -> %d frames", n_frames, target_frames)
    elif n_frames > target_frames:
        spec = spec[:, :target_frames]
        logger.debug("Trimmed spectrogram: %d -> %d frames", n_frames, target_frames)
    return spec.astype(np.float32)


# ── Public API ───────────────────────────────────────────────────────────────

def preprocess_audio(audio_bytes: bytes) -> np.ndarray:
    """Full preprocessing pipeline -> model-ready tensor.

    Matches training notebook pipeline exactly so inference scores reflect
    the model's training distribution.

    Args:
        audio_bytes: Raw audio file content as bytes.

    Returns:
        float32 ndarray of shape ``[1, 128, 94, 1]`` ready for TFLite inference.

    Raises:
        ValueError: If audio cannot be decoded or is empty/corrupt.
    """
    # Step 1 -- decode & resample to 16000 Hz mono
    samples = _load_audio(audio_bytes)

    # Steps 2-4 -- STFT -> mel filterbank -> log-dB (matches training)
    log_mel = _compute_mel_spectrogram(samples)

    # Step 5 -- global z-score normalisation (matches training)
    normalised = _zscore_normalize(log_mel)

    # Step 6 -- pad/trim to [128, 94] then reshape to [1, 128, 94, 1]
    fixed = _pad_or_trim(normalised, target_frames=MEL_FRAMES)
    tensor = fixed.reshape(1, MEL_BANDS, MEL_FRAMES, 1)

    logger.info(
        "[MODEL INPUT] ✅ Tensor ready for inference — shape=%s  dtype=%s  "
        "min=%.4f  max=%.4f  mean=%.4f",
        tensor.shape, tensor.dtype,
        float(tensor.min()), float(tensor.max()), float(tensor.mean()),
    )
    return tensor
