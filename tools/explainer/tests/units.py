"""Fast checks of everything that is not geometry. Run by selftest.sh under the tool's Python.

Each test is a defect the review of PR #211 found, put back as an input: the test passes when
the tool now refuses it or reports it.
"""

import contextlib
import io
import json
import pathlib
import subprocess
import sys
import tempfile
import wave

import numpy as np

from explainer_kit import cli, voice
from explainer_kit.film import Film

TMP = pathlib.Path(tempfile.mkdtemp())


def film(source, name="film.py"):
    path = TMP / name
    path.write_text(source)
    return Film(path)


def test_narration_in_a_base_class_is_collected():
    f = film('''
class _Base(Explainer):
    def opening(self):
        self.say("Inherited narration.")
class Child(_Base):
    def construct(self):
        self.opening()
''')
    assert f.scenes == ["Child"], f.scenes
    assert f.texts(["Child"]) == ["Inherited narration."], f.texts(["Child"])


def test_keyword_speak_is_collected():
    f = film('''
class Card(Explainer):
    def construct(self):
        self.speak(text="A title card.", lead=0.1)
''')
    assert f.texts() == ["A title card."], f.texts()


def test_a_dynamic_line_is_a_problem_only_for_its_own_scene():
    f = film('''
class Good(Explainer):
    def construct(self):
        self.say("Fine.")
class Bad(Explainer):
    def construct(self):
        self.say("built " + "at run time")
''')
    assert f.problems_for(["Good"]) == [], f.problems_for(["Good"])
    assert len(f.problems_for(["Bad"])) == 1 and len(f.problems_for()) == 1
    assert f.texts(["Good"]) == ["Fine."]


def test_lines_are_listed_for_the_scenes_asked_for():
    f = film('''
class A(Explainer):
    def construct(self):
        self.say("The first scene.")
class B(Explainer):
    def construct(self):
        self.say("The second scene.")
''')
    assert [(o, t) for o, _, t in f.records_for(["B"])] == [("B", "The second scene.")]


def test_a_damaged_clip_is_not_trusted():
    path = TMP / "clip.wav"
    path.write_bytes(b"")
    assert not voice.clip_ok(path)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(voice.RATE)
        w.writeframes(np.zeros(100, dtype="<i2").tobytes())
    assert voice.clip_ok(path)


def _movie(name, audio_offset):
    """Two seconds of black with a tone starting at 1.0 s, its audio muxed `audio_offset` late."""
    tone = TMP / "tone.wav"
    samples = np.zeros(2 * voice.RATE, dtype=np.float32)
    t = np.arange(voice.RATE // 2) / voice.RATE
    samples[voice.RATE:voice.RATE + len(t)] = 0.3 * np.sin(2 * np.pi * 440 * t)
    with wave.open(str(tone), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(voice.RATE)
        w.writeframes((samples * 32767).astype("<i2").tobytes())
    out = TMP / name
    subprocess.run(cli.QUIET + ["-f", "lavfi", "-i", "color=c=black:s=160x90:r=15:d=2",
                                "-itsoffset", str(audio_offset), "-i", str(tone),
                                "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-c:a", "aac",
                                str(out)], check=True)
    return out


def test_sync_sees_audio_muxed_late():
    on_time = cli.sync(_movie("on-time.mp4", 0), [1.0])[0]
    assert on_time is not None and abs(on_time) < 0.05, on_time
    late = cli.sync(_movie("late.mp4", 1), [1.0])[0]
    assert late is None or abs(late) > 0.5, late  # the tone is now at 2.0 s, not where expected


def _exits(function, *args):
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            return function(*args)
    except SystemExit as stop:
        return stop.code


def test_check_refuses_when_nothing_was_rendered():
    f = film('class A(Explainer):\n    def construct(self):\n        pass\n', "empty.py")
    args = cli.argparse.Namespace(film=str(f.path), media=str(TMP / "none"), draft=True,
                                  transcribe=False, out=None, json=False)
    result = _exits(cli.cmd_check, args)
    assert isinstance(result, str) and "no successful" in result, result


def test_check_refuses_a_render_whose_film_is_gone():
    f = film('class A(Explainer):\n    def construct(self):\n        pass\n', "gone.py")
    media = TMP / "gone-media"
    (media / "run-draft").mkdir(parents=True)
    (media / "run-draft" / "A.json").write_text(json.dumps(
        {"scene": "A", "seconds": 1.0, "captions": 0, "timeline": [], "lint": []}))
    part = cli.part_paths(f, media, "draft", ["A"])[0]
    part.parent.mkdir(parents=True)
    part.write_bytes(b"x")
    (media / "render-draft.json").write_text(json.dumps(
        {"mode": "draft", "scenes": ["A"], "voiced": False, "joined": True,
         "outputs": [str(media / "draft.mp4")]}))
    args = cli.argparse.Namespace(film=str(f.path), media=str(media), draft=True,
                                  transcribe=False, out=None, json=False)
    result = _exits(cli.cmd_check, args)
    assert isinstance(result, str) and "gone" in result, result


if __name__ == "__main__":
    tests = [(name, fn) for name, fn in sorted(globals().items()) if name.startswith("test_")]
    failed = 0
    for name, fn in tests:
        try:
            fn()
        except Exception as error:  # noqa: BLE001  (report every failure, then exit non-zero)
            failed += 1
            print(f"FAIL {name}: {type(error).__name__}: {error}")
    print(f"units: {'FAILED' if failed else 'ok'}, {len(tests) - failed} of {len(tests)} passed")
    sys.exit(1 if failed else 0)
