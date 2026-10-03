"""Narration: one Kokoro clip per spoken line, cached by text, then one track for the film.

The scene kit and the CLI both derive a caption's spoken sentence with spoken(), so the clip a
scene asks for at render time is the one the CLI made beforehand. With EXPLAINER_VOICE_DIR unset
there is no narration and scenes time themselves by reading speed alone.
"""

from __future__ import annotations

import hashlib
import os
import pathlib
import re
import wave

VOICE = os.environ.get("EXPLAINER_VOICE", "af_heart")
SPEED = float(os.environ.get("EXPLAINER_SPEED", "1.0"))
MODELS = pathlib.Path(os.environ.get(
    "KOKORO_MODELS", "~/.local/share/manim-env-root/models/kokoro")).expanduser()
RATE = 24000  # Kokoro's sample rate
LEVEL = 0.07  # RMS each clip is brought to, so lines match in loudness without a compressor
# +6 dB under a limiter takes the mixed track from about -23 LUFS to -17, peaks near -1 dBFS.
MASTER = "volume=6dB,alimiter=limit=0.84:attack=5:release=80:level=false"

MARK = re.compile(r"\{([a-z]+)\|([^{}]*)\}")

# Captions are written to be read; a film's SAY table makes them sayable, and these apply after
# it to every film.
BASE_SAY = [
    (r"\bstdout\b", "standard out"),
    (r"\bstderr\b", "standard error"),
]


def spoken(lines, table=()):
    """The sentence a caption is spoken as: its lines joined, markup dropped, terms respelt."""
    text = " ".join(MARK.sub(lambda m: m.group(2), line) for line in lines)
    for pattern, said in list(table) + BASE_SAY:
        text = re.sub(pattern, said, text)
    return re.sub(r"\s+", " ", text).strip()


def clip_path(text, voice_dir):
    key = hashlib.sha1(f"{VOICE}|{SPEED}|{LEVEL}|{text}".encode()).hexdigest()[:16]
    return pathlib.Path(voice_dir) / f"{key}.wav"


def seconds(path):
    with wave.open(str(path)) as w:
        return w.getnframes() / w.getframerate()


def clip(text):
    """(path, seconds) of the clip for a spoken line, or None when narration is off."""
    voice_dir = os.environ.get("EXPLAINER_VOICE_DIR")
    if not voice_dir:
        return None
    path = clip_path(text, voice_dir)
    if not path.exists():
        raise FileNotFoundError(f"no narration clip for {text!r}: the CLI makes them before "
                                "rendering; a say() built at run time cannot be narrated")
    return path, seconds(path)


def _quiet():
    """The phonemizer logs a warning for every line whose punctuation it re-attaches."""
    import logging
    logging.getLogger("phonemizer").setLevel(logging.ERROR)


def _lang():
    return "en-gb" if VOICE.startswith("b") else "en-us"


def synth(texts, voice_dir, log=print):
    """Make the clips that are missing. Returns how many were made."""
    import numpy as np
    out = pathlib.Path(voice_dir)
    out.mkdir(parents=True, exist_ok=True)
    todo = [t for t in dict.fromkeys(texts) if not clip_path(t, out).exists()]
    if not todo:
        return 0
    from kokoro_onnx import Kokoro
    _quiet()
    engine = Kokoro(str(MODELS / "kokoro-v1.0.onnx"), str(MODELS / "voices-v1.0.bin"))
    for text in todo:
        samples, rate = engine.create(text, voice=VOICE, speed=SPEED, lang=_lang())
        assert rate == RATE, rate
        loud = np.flatnonzero(np.abs(samples) > 0.01)
        samples = samples[max(0, loud[0] - 480):loud[-1] + 1200]  # 20 ms before, 50 ms after
        samples = np.clip(samples * (LEVEL / np.sqrt(np.mean(samples ** 2))), -0.98, 0.98)
        with wave.open(str(clip_path(text, out)), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((samples * 32767).astype("<i2").tobytes())
        log(f"  voiced {len(samples) / RATE:5.2f}s  {text}")
    return len(todo)


def mix(placed, total, out):
    """One mono track of `total` seconds with each (start, clip path) laid at its time."""
    import numpy as np
    track = np.zeros(int(total * RATE) + 1, dtype=np.float32)
    for start, path in placed:
        with wave.open(str(path)) as w:
            data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2") / 32767
        i = int(start * RATE)
        track[i:i + len(data)] += data[:len(track) - i]
    with wave.open(str(out), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(track, -1, 1) * 32767).astype("<i2").tobytes())


def phonemes(texts):
    """How each line will be pronounced, to catch a term that needs a SAY entry."""
    from kokoro_onnx.tokenizer import Tokenizer
    _quiet()
    tokenizer = Tokenizer()
    return [tokenizer.phonemize(text, _lang()) for text in texts]


def transcribe(texts, voice_dir, model_name="small.en"):
    """A stand-in for listening: what a speech recogniser hears in each clip, against the line.

    Returns (exact, [(said, heard), ...]). Homophones (write/right, red/read) and digits for
    spelt-out numbers are expected differences; a wrong or missing word is not.
    """
    import difflib
    import numpy as np
    from faster_whisper import WhisperModel
    from scipy.signal import resample_poly

    digits = {"zero": "0", "one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
              "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10", "twelve": "12"}

    def words(text):
        text = re.sub(r"[^a-z0-9 ]", "", text.lower().replace("-", " "))
        return [digits.get(w, w) for w in text.split()]

    model = WhisperModel(model_name, device="cpu", compute_type="int8")
    exact, diffs = 0, []
    for text in dict.fromkeys(texts):
        with wave.open(str(clip_path(text, voice_dir))) as w:
            pcm = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2") / 32768
        audio = resample_poly(pcm, 2, 3).astype(np.float32)  # 24 kHz to Whisper's 16 kHz
        parts, _ = model.transcribe(audio, beam_size=5, language="en",
                                    condition_on_previous_text=False)
        heard = " ".join(part.text.strip() for part in parts)
        ops = difflib.SequenceMatcher(a=words(text), b=words(heard), autojunk=False).get_opcodes()
        if all(op[0] == "equal" for op in ops):
            exact += 1
        else:
            diffs.append((text, heard))
    return exact, diffs
