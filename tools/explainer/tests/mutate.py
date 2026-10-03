"""Revert one fix at a time in a copy of the tool; the self-test must go red each time.

A test that stays green with its fix reverted is not testing that fix. This holds the tests to
account the way examples/defects.py holds the checks: every entry below is a defect a review of
the tool found, written as the smallest edit that brings it back.

    python3 tests/mutate.py            every mutation: about ten minutes
    python3 tests/mutate.py stroke     only those whose name contains the word

A mutation names the text it replaces, which must occur exactly once, so an edit to the tool
that moves it shows up here as an error and not as a mutation that silently did nothing. The
copy is run from this folder on purpose: it must import its own code, not its neighbour's.

Not covered, because nothing here can observe them: that a clip is written under a temporary
name and renamed, and that curl is asked for --retry.
"""

import pathlib
import shutil
import subprocess
import sys
import tempfile

TOOL = pathlib.Path(__file__).resolve().parent.parent

# (what comes back, file, the fix, the defect, whether it takes selftest.sh --full to see)
MUTATIONS = [
    # -- geometry ------------------------------------------------------------------------------
    ("an arrow's shaft is not ink", "explainer_kit/lint.py",
     '            own = _own(mob)\n            if own:\n                yield {"info": None,',
     '            own = None if mob.submobjects else _own(mob)\n            if own:\n'
     '                yield {"info": None,', False),
    ("stroke thickness is ignored", "explainer_kit/lint.py",
     "    half = _half_stroke(m)", "    half = _half_stroke(m) * 0", False),
    ("background strokes are unseen", "explainer_kit/lint.py",
     "for background in (False, True)", "for background in (False,)", False),
    ("images are not ink", "explainer_kit/lint.py",
     "    if isinstance(m, AbstractImageMobject):\n        box = _image_box(m)",
     "    if isinstance(m, AbstractImageMobject):\n        return None\n"
     "        box = _image_box(m)", False),
    ("transparent pixels count as ink", "explainer_kit/lint.py",
     "    seen = m.pixel_array[:, :, 3] > 5 if m.pixel_array.shape[2] == 4 else np.ones(",
     "    seen = m.pixel_array[:, :, 3] > -1 if m.pixel_array.shape[2] == 4 else np.ones(",
     False),
    ("an image is its whole rectangle", "explainer_kit/lint.py",
     '    if isinstance(piece["mob"], AbstractImageMobject):  # its visible pixels, not its '
     'rectangle', '    if False:', False),
    ("an empty outline fills its box", "explainer_kit/lint.py",
     '    elif piece["filled"]:\n        return True', "    elif True:\n        return True",
     False),
    ("caption lines may overlap", "explainer_kit/lint.py",
     '            dx, dy = _shared(a["box"], b["box"])',
     '            if a["info"]["kind"] == b["info"]["kind"] == "caption":\n'
     '                continue\n'
     '            dx, dy = _shared(a["box"], b["box"])', False),
    ("a pixel is taken for a circle", "explainer_kit/lint.py",
     "    half = (np.abs(across) + np.abs(down))[:2] / 2",
     "    half = np.full(2, max(np.linalg.norm(across), np.linalg.norm(down)) / 2)", False),
    ("glyphs carry no text record", "explainer_kit/lint.py",
     "        glyph.explainer_part = record", "        pass", False),
    ("plain text is not marked", "explainer_kit/kit.py",
     "            lint.mark_plain_text(mob)  # so a plain Text stays one text if Manim takes it "
     "apart", "            pass", False),
    ("a glyph with a child is not regrouped", "explainer_kit/lint.py",
     '        elif getattr(mob, "explainer_part", None) is not None:',
     '        elif getattr(mob, "explainer_part", None) is not None and not mob.submobjects:',
     False),
    ("regrouped text forgets its scale", "explainer_kit/lint.py",
     "scale=float(np.median(scales)) if scales else 1)", "scale=1)", False),
    ("caption_cut is judged before the wait", "explainer_kit/kit.py",
     "        self.hush(0.15)  # never talk over the line before\n",
     "", True),
    ("a wait rounded down to a frame is a cut", "explainer_kit/kit.py",
     "        slack = max(0.05, 1 / config.frame_rate + 0.005)", "        slack = 0.05", True),
    # -- which lines a scene speaks ---------------------------------------------------------------
    ("speak(text=...) is skipped", "explainer_kit/film.py",
     '        nodes = node.args[:1] or [kw.value for kw in node.keywords if kw.arg == "text"]',
     "        nodes = node.args[:1]", False),
    ("a problem anywhere blocks every scene", "explainer_kit/film.py",
     "        for scene in self.scenes if scenes is None else scenes:",
     "        for scene in self.scenes:", False),
    ("bases and mixins are not followed", "explainer_kit/film.py",
     "            self.bases[node.name] = [b for b in names if b in self.bases]",
     "            self.bases[node.name] = []", False),
    ("an overridden method is followed", "explainer_kit/film.py",
     "        for c in lineage:", "        for c in reversed(lineage):", False),
    ("method lookup is depth-first", "explainer_kit/film.py",
     "            head = next((r[0] for r in rows if not any(r[0] in other[1:] for other in "
     "rows)), None)", "            head = None", False),
    ("a nested function cannot see its neighbours", "explainer_kit/film.py",
     "            visible = {**enclosing, **nested}", "            visible = dict(nested)", False),
    ("nested functions are always entered", "explainer_kit/film.py",
     "        if isinstance(node, DEFS):\n            nested[node.name] = node",
     "        if False:\n            nested[node.name] = node", False),
    ("every helper belongs to every scene", "explainer_kit/film.py",
     "        return list(seen.values())",
     "        return list(seen.values()) + [(None, f) for f in self.functions.values()]", False),
    # -- the narration cache and the speech-to-text model -----------------------------------------
    ("a clip is trusted by its header", "explainer_kit/voice.py",
     "            return ours and frames > 0 and len(w.readframes(frames)) == frames * 2",
     "            return ours and frames > 0", False),
    ("an incomplete Whisper model is ready", "explainer_kit/voice.py",
     "    whole = all((path / name).is_file() and (path / name).stat().st_size > 0",
     "    whole = all((path / name).is_file() or name != 'model.bin'", False),
    ("transcription may reach the network", "explainer_kit/voice.py",
     '    os.environ["HF_HUB_OFFLINE"] = "1"  # before the import below reads it: no network, '
     'ever', "    pass", False),
    ("Whisper may download what is missing", "explainer_kit/voice.py",
     'compute_type="int8", local_files_only=True)', 'compute_type="int8")', False),
    # -- the CLI ----------------------------------------------------------------------------------
    ("sync ignores where the audio sits", "explainer_kit/cli.py",
     "        i = int(round(t * rate))", "        i = int(round((t - chunks[0][0]) * rate))",
     False),
    ("a manifest is not bound to its film", "explainer_kit/cli.py",
     '    if run.get("film") != str(film.path):', "    if False:", False),
    ("a movie is judged by its headers", "explainer_kit/cli.py",
     "            frames = sum(1 for _ in container.decode(stream))",
     "            frames = stream.frames", False),
    ("any length of movie will do", "explainer_kit/cli.py",
     "    if frames != made:", "    if False:", False),
    ("a movie's length is judged in time", "explainer_kit/cli.py",
     "    if frames != made:", "    if abs(frames - made) / rate > 0.2:", False),
    ("a movie may be a frame short", "explainer_kit/cli.py",
     "    if frames != made:", "    if abs(frames - made) > 1:", False),
    ("a joined film is decoded per scene", "explainer_kit/cli.py",
     "            offsets = [o for path, times in starts.items() for o in sync(path, times)]",
     "            offsets = [o for path, times in starts.items() for t in times\n"
     "                       for o in sync(path, [t])]", False),
    ("a library can print into the report", "explainer_kit/cli.py",
     "    with contextlib.redirect_stdout(sys.stderr):", "    if True:", False),
    ("the launcher imports from the current folder", "explainer",
     "exec python -P -m explainer_kit.cli", "exec python -m explainer_kit.cli", False),
    ("a failed render keeps the last manifest", "explainer_kit/cli.py",
     "    manifest.unlink(missing_ok=True)", "    pass", True),
    ("synthesis logs go to stdout", "explainer_kit/cli.py",
     '        made = voice.synth(film.texts(scenes), media / "voice", log=log)',
     '        made = voice.synth(film.texts(scenes), media / "voice", log=out)', True),
    ("scenes share one Manim directory", "explainer_kit/cli.py",
     '    return media / "manim" / scene', '    return media / "manim"', True),
    ("sheet crashes", "explainer_kit/cli.py",
     "        out(sheet)", "        sheets(sheet)", True),
    ("--scenes files get no narration", "explainer_kit/cli.py",
     "    elif voiced:  # some scenes only", "    elif False:  # some scenes only", True),
    ("--scenes files get no loudness", "explainer_kit/cli.py",
     '                info["scene_loudness"] = measured', "                pass", True),
    ("a file beside the film can replace the kit", "explainer_kit/cli.py",
     '    start = "import sys, explainer_kit; from manim.__main__ import main; sys.exit(main())"',
     '    start = "import sys; from manim.__main__ import main; sys.exit(main())"', True),
    # -- setup ------------------------------------------------------------------------------------
    ("an HTTP error page is saved as the download", "setup.sh",
     '  curl -fsSL --retry 3 -o "$2.part" "$1"', '  curl -sSL --retry 3 -o "$2.part" "$1"',
     False),
    ("half a Whisper model counts as whole", "setup.sh",
     '    [ -s "$1/$f" ] || return 1', '    [ -s "$1/$f" ] || [ "$f" != model.bin ] || return 1',
     False),
]


def main():
    wanted = [m for m in MUTATIONS if not sys.argv[1:] or any(w in m[0] for w in sys.argv[1:])]
    survived = []
    for name, rel, fix, defect, full in wanted:
        work = pathlib.Path(tempfile.mkdtemp()) / "explainer"
        shutil.copytree(TOOL, work, ignore=shutil.ignore_patterns("__pycache__", ".DS_Store"))
        source = (work / rel).read_text()
        if source.count(fix) != 1:
            sys.exit(f"{name}: its fix occurs {source.count(fix)} times in {rel}, not once; "
                     "this script is out of date with the tool")
        (work / rel).write_text(source.replace(fix, defect))
        done = subprocess.run([str(work / "selftest.sh")] + (["--full"] if full else []),
                              capture_output=True, text=True, cwd=TOOL)
        red = done.returncode != 0
        if not red:
            survived.append(name)
        said = [line for line in (done.stdout + done.stderr).splitlines() if line.strip()]
        why = next((line for line in said if line.startswith("FAIL")), said[-1] if said else "")
        print(f"{'red  ' if red else 'GREEN'} {name:<46} {why[:90]}", flush=True)
        shutil.rmtree(work.parent)
    print(f"{len(wanted) - len(survived)} of {len(wanted)} reverted fixes turn the self-test red")
    return 1 if survived else 0


if __name__ == "__main__":
    sys.exit(main())
