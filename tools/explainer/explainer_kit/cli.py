"""explainer: render a narrated Manim film from a file of Explainer scenes, and check it.

    explainer lint FILM            run every scene's timeline without drawing it (seconds)
    explainer render FILM          narrate, render, join, and check; writes the mp4 and a report
    explainer check FILM           re-run the checks on the last successful render
    explainer say FILM             print each spoken line and how it will be pronounced
    explainer sheet FILM           contact sheets of the last render, for an author with eyes
    explainer doctor               say what is installed and what is missing

Exit status: 0 clean, 1 could not render (or nothing to check), 2 rendered but a check failed.
The report goes to stdout; progress goes to stderr, so `--json` output is always valid JSON.
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import math
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

from . import voice
from .film import Film

KIT = pathlib.Path(__file__).resolve().parent.parent
MODES = {"final": (1920, 1080, 30), "draft": (854, 480, 15)}
QUIET = ["ffmpeg", "-y", "-loglevel", "error"]
# main() points sys.stdout at stderr while a command runs, so that nothing a library prints can
# get in front of the report. What a command means to print goes through out().
STDOUT = sys.stdout


def out(text):
    print(text, file=STDOUT)


def log(message):
    print(message, file=sys.stderr)


def media_dir(film, override=None):
    """Scratch space for one film: clips, partial movies, per-scene reports. Disposable."""
    if override or os.environ.get("EXPLAINER_MEDIA"):
        return pathlib.Path(override or os.environ["EXPLAINER_MEDIA"]).resolve()
    key = hashlib.sha1(str(film.path).encode()).hexdigest()[:8]
    return pathlib.Path(tempfile.gettempdir()) / "explainer-media" / f"{film.path.stem}-{key}"


def run_scenes(film, scenes, media, run_dir, mode, voiced, dry, jobs):
    """One Manim process per scene. Returns the names of the scenes that failed."""
    width, height, fps = MODES[mode]
    env = dict(os.environ, EXPLAINER_RUN_DIR=str(run_dir),
               PYTHONPATH=os.pathsep.join([str(KIT), os.environ.get("PYTHONPATH", "")]))
    env.pop("EXPLAINER_VOICE_DIR", None)
    if voiced:
        env["EXPLAINER_VOICE_DIR"] = str(media / "voice")
    logs = media / "logs"
    logs.mkdir(parents=True, exist_ok=True)
    shutil.rmtree(run_dir, ignore_errors=True)
    # -P as in the launcher. Manim itself puts the film's folder on the path to import it.
    args = [sys.executable, "-P", "-m", "manim", "render", "-r", f"{width},{height}",
            "--fps", str(fps),
            "--media_dir", str(media), "--disable_caching", "-v", "WARNING",
            "--progress_bar", "none"]
    if dry:  # -s draws only the last frame: animations jump to their ends, time still advances
        args.append("-s")
    failed, pending = [], list(scenes)
    running = {}
    while pending or running:
        while pending and len(running) < jobs:
            name = pending.pop(0)
            out = open(logs / f"{name}.log", "w")
            running[name] = (subprocess.Popen(args + [str(film.path), name], cwd=film.path.parent,
                                              env=env, stdout=out, stderr=subprocess.STDOUT), out)
        name, (proc, out) = next(iter(running.items()))
        proc.wait()
        out.close()
        del running[name]
        # A scene writes its report as its last act, so no report means it did not finish.
        if proc.returncode != 0 or not (run_dir / f"{name}.json").exists():
            failed.append(name)
    return failed


def scene_reports(run_dir, scenes):
    return [json.loads((run_dir / f"{name}.json").read_text()) for name in scenes]


def part_paths(film, media, mode, scenes):
    _, height, fps = MODES[mode]
    return [media / "videos" / film.path.stem / f"{height}p{fps}" / f"{s}.mp4" for s in scenes]


def film_path(film, media, mode, out=None):
    """Where the joined film goes: beside the film file, or in scratch for a draft."""
    if out:
        return pathlib.Path.cwd() / out
    if mode == "draft":
        return media / "draft.mp4"
    return film.path.parent / (film.output or f"{film.path.stem}.mp4")


def video_seconds(path):
    import av
    with av.open(str(path)) as container:
        stream = container.streams.video[0]
        return float(stream.frames / stream.average_rate)


def movie_problem(path, seconds, voiced):
    """Why a file is not the movie a render should have left, or None if it is."""
    import av
    try:
        with av.open(str(path)) as container:
            if not container.streams.video:
                return "has no video stream"
            stream = container.streams.video[0]
            length = float(stream.frames / stream.average_rate)
            if voiced and not container.streams.audio:
                return "has no audio stream, though the render was narrated"
    except Exception as error:  # noqa: BLE001  (whatever PyAV raises, the file is not a movie)
        return f"cannot be read as a movie ({type(error).__name__})"
    if abs(length - seconds) > 0.2:
        return f"runs {length:.1f} s where the render made {seconds:.1f} s"
    return None


def narrate(picture, placed, seconds, track, target):
    """Lay the clips on one track, level it, and mux it onto the picture."""
    voice.mix(placed, seconds, track)
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(QUIET + ["-i", str(picture), "-i", str(track), "-map", "0:v", "-map", "1:a",
                            "-af", voice.MASTER, "-c:v", "copy", "-c:a", "aac", "-b:a", "128k",
                            "-ar", "48000", "-movflags", "+faststart", str(target)], check=True)


def loudness(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af",
                          "ebur128=peak=true", "-f", "null", "-"], capture_output=True,
                         text=True).stderr
    tail = out[out.rfind("Summary:"):]
    integrated = re.search(r"I:\s+(-?[\d.]+) LUFS", tail)
    peak = re.search(r"Peak:\s+(-?[\d.]+) dBFS", tail)
    return {"integrated_lufs": float(integrated.group(1)) if integrated else None,
            "true_peak_dbfs": float(peak.group(1)) if peak else None}


def audio_on_timeline(path):
    """A file's audio as (samples, rate), each frame placed at its own timestamp.

    Decoding alone yields samples from the stream's first frame onward and loses where that
    frame sits against the picture, so a track muxed a second late would look perfectly in sync.
    """
    import av
    import numpy as np
    with av.open(str(path)) as container:
        if not container.streams.audio:
            return None, 0
        stream = container.streams.audio[0]
        rate = stream.rate
        video = container.streams.video[0] if container.streams.video else None
        zero = 0.0
        if video is not None and video.start_time is not None:
            zero = float(video.start_time * video.time_base)
        chunks = [(float(f.pts * f.time_base) - zero, f.to_ndarray().mean(axis=0))
                  for f in container.decode(stream) if f.pts is not None]
    if not chunks:
        return None, rate
    audio = np.zeros(max(int(round(t * rate)) + len(c) for t, c in chunks), dtype=np.float32)
    for t, chunk in chunks:
        i = int(round(t * rate))
        if i < 0:
            chunk, i = chunk[-i:], 0
        audio[i:i + len(chunk)] = chunk
    return audio, rate


def sync(path, starts):
    """How far each clip's first sound in a finished file is from where its scene put it."""
    import numpy as np
    audio, rate = audio_on_timeline(path)
    if audio is None:
        return [None] * len(starts)
    hop = max(1, rate // 200)  # 5 ms
    level = np.sqrt(np.convolve(audio ** 2, np.ones(hop) / hop, mode="same"))
    offsets = []
    for start in starts:
        lo, hi = max(int((start - 0.2) * rate), 0), int((start + 0.4) * rate)
        loud = np.flatnonzero(level[lo:hi] > 0.006)  # about -45 dBFS
        offsets.append(None if len(loud) == 0 else float((lo + loud[0]) / rate - start))
    return offsets


def build_report(film, run, reports, transcribe, media):
    """The report for a run: `run` says what was rendered, `reports` what each scene recorded."""
    mode, scenes = run["mode"], run["scenes"]
    width, height, fps = MODES[mode]
    findings = [dict(f, scene=r["scene"]) for r in reports for f in r["lint"]]
    findings += [{"scene": None, "t": 0, "kind": "unspeakable", "severity": "error",
                  "detail": problem, "what": []} for problem in film.problems_for(scenes)]
    report = {
        "film": str(film.path), "mode": mode,
        "output": run["outputs"][0] if run["joined"] else None,
        "scene_files": [] if run["joined"] else run["outputs"],
        "resolution": f"{width}x{height}", "fps": fps,
        "seconds": round(sum(r["seconds"] for r in reports), 2),
        "scenes": [{"name": r["scene"], "seconds": r["seconds"], "captions": r["captions"],
                    "clips": len(r["timeline"])} for r in reports],
        "lint": {"errors": sum(f["severity"] == "error" for f in findings),
                 "warnings": sum(f["severity"] == "warning" for f in findings),
                 "findings": findings},
        "voice": None,
    }
    ok = report["lint"]["errors"] == 0
    if run["voiced"]:
        # Each file that was written, with the times its clips should start at. A joined film
        # is one file holding every scene's clips, so it is decoded once, not once per scene.
        starts, offset, overlaps, clips = {}, 0.0, 0, []
        for index, r in enumerate(reports):
            end = 0.0
            for entry in r["timeline"]:
                clip = media / "voice" / entry["wav"]
                overlaps += entry["t"] < end - 1e-6
                end = entry["t"] + voice.seconds(clip)
                clips.append(clip)
                if run["outputs"]:
                    path = run["outputs"][0 if run["joined"] else index]
                    starts.setdefault(path, []).append(offset + entry["t"])
            if run["joined"]:
                offset += r["seconds"]
        info = {"engine": "kokoro-v1.0", "voice": voice.VOICE, "clips": len(clips),
                "speech_seconds": round(sum(voice.seconds(c) for c in clips), 1),
                "overlaps": overlaps}
        ok = ok and overlaps == 0
        if run["outputs"]:
            offsets = [o for path, times in starts.items() for o in sync(path, times)]
            missing = sum(o is None for o in offsets)
            worst = max((abs(o) for o in offsets if o is not None), default=0.0)
            info["sync"] = {"worst_ms": round(worst * 1000), "silent_clips": missing,
                            "ok": missing == 0 and worst < 0.08}
            ok = ok and info["sync"]["ok"]
            measured = [dict(loudness(path), file=path) for path in run["outputs"]]
            if run["joined"]:
                info["loudness"] = {k: v for k, v in measured[0].items() if k != "file"}
            else:
                info["scene_loudness"] = measured
        if transcribe:
            exact, diffs = voice.transcribe(film.texts(scenes), media / "voice")
            info["transcription"] = {"exact": exact, "of": exact + len(diffs),
                                     "diffs": [{"said": s, "heard": h} for s, h in diffs]}
        report["voice"] = info
    report["ok"] = bool(ok)
    return report


def print_report(report, as_json):
    if as_json:
        out(json.dumps(report, indent=1))
        return
    minutes, seconds = divmod(report["seconds"], 60)
    out(f"{len(report['scenes'])} scenes, {int(minutes)} min {seconds:.0f} s, "
          f"{report['resolution']} at {report['fps']} fps ({report['mode']})")
    for scene in report["scenes"]:
        out(f"  {scene['name']:<14} {scene['seconds']:6.1f} s  {scene['captions']} captions")
    lint = report["lint"]
    out(f"lint: {lint['errors']} errors, {lint['warnings']} warnings")
    for f in lint["findings"]:
        where = f"{f['scene']} at {f['t']} s" if f["scene"] else "film"
        out(f"  {f['severity']:<7} {f['kind']:<15} {where}: {f['detail']}")
        for text in f["what"]:
            out(f"            \"{text}\"")
    v = report["voice"]
    if v:
        out(f"voice: {v['clips']} clips, {v['speech_seconds']} s of speech, "
              f"{v['overlaps']} overlaps ({v['voice']})")
        if "sync" in v:
            out(f"  sync: worst {v['sync']['worst_ms']} ms, "
                  f"{v['sync']['silent_clips']} clips not found where their scene put them")
        for measure in [v["loudness"]] if "loudness" in v else v.get("scene_loudness", []):
            name = f" of {pathlib.Path(measure['file']).name}" if "file" in measure else ""
            out(f"  loudness{name}: {measure['integrated_lufs']} LUFS, "
                  f"peak {measure['true_peak_dbfs']} dBFS")
        if "transcription" in v:
            t = v["transcription"]
            out(f"  transcription: {t['exact']} of {t['of']} clips word for word")
            for d in t["diffs"]:
                out(f"    said   {d['said']}\n    heard  {d['heard']}")
    for path in [report["output"]] if report["output"] else report["scene_files"]:
        out(path)
    out("ok" if report["ok"] else "CHECKS FAILED")


def pick_scenes(film, wanted):
    if not wanted:
        return film.scenes
    unknown = [s for s in wanted if s not in film.scenes]
    if unknown:
        sys.exit(f"no such scene in {film.path.name}: {', '.join(unknown)} "
                 f"(it has {', '.join(film.scenes)})")
    return [s for s in film.scenes if s in wanted]


def tail_logs(media, failed):
    for name in failed:
        path = media / "logs" / f"{name}.log"
        log(f"--- {name} failed; last lines of {path}")
        log("\n".join(path.read_text().splitlines()[-25:]))


def need_whisper(args):
    if getattr(args, "transcribe", False) and voice.whisper_model() is None:
        sys.exit(f"--transcribe needs the Whisper model in {voice.WHISPER}: "
                 f"run {KIT / 'setup.sh'} --with-whisper")


def cmd_lint(args):
    film = Film(args.film)
    scenes = pick_scenes(film, args.scenes)
    media = media_dir(film, args.media)
    # Use the narration's timing when every clip is already made; else time by reading speed.
    texts = film.texts(scenes)
    voiced = bool(texts) and all(voice.clip_ok(voice.clip_path(t, media / "voice"))
                                 for t in texts)
    run_dir = media / "run-lint"
    failed = run_scenes(film, scenes, media, run_dir, "final", voiced, True, args.jobs)
    if failed:
        tail_logs(media, failed)
        return 1
    run = {"mode": "final", "scenes": scenes, "voiced": False, "joined": False, "outputs": []}
    report = build_report(film, run, scene_reports(run_dir, scenes), False, media)
    report["timed_by"] = "narration" if voiced else "reading speed"
    print_report(report, args.json)
    return 0 if report["ok"] else 2


def cmd_render(args):
    film = Film(args.film)
    scenes = pick_scenes(film, args.scenes)
    mode = "draft" if args.draft else "final"
    media = media_dir(film, args.media)
    voiced = not args.no_voice
    need_whisper(args)
    # The manifest names the last render that finished; one that fails must not leave it behind.
    manifest = media / f"render-{mode}.json"
    manifest.unlink(missing_ok=True)
    problems = film.problems_for(scenes)
    if problems and voiced:
        log("\n".join(problems))
        return 1
    if voiced:
        made = voice.synth(film.texts(scenes), media / "voice", log=log)
        if made:
            log(f"narration: {made} new clips")
    run_dir = media / f"run-{mode}"
    failed = run_scenes(film, scenes, media, run_dir, mode, voiced, False, args.jobs)
    if failed:
        tail_logs(media, failed)
        return 1
    reports = scene_reports(run_dir, scenes)
    parts = part_paths(film, media, mode, scenes)

    joined = scenes == film.scenes
    if joined:
        output = film_path(film, media, mode, args.out)
        listing = media / f"concat-{mode}.txt"
        listing.write_text("".join(f"file '{p}'\n" for p in parts))
        picture = media / f"picture-{mode}.mp4"
        subprocess.run(QUIET + ["-f", "concat", "-safe", "0", "-i", str(listing), "-c", "copy",
                                str(picture)], check=True)
        if voiced:
            offset, placed = 0.0, []
            for part, r in zip(parts, reports):
                placed += [(offset + e["t"], media / "voice" / e["wav"]) for e in r["timeline"]]
                offset += video_seconds(part)
            narrate(picture, placed, offset, media / f"narration-{mode}.wav", output)
        else:
            subprocess.run(QUIET + ["-i", str(picture), "-c", "copy", "-movflags", "+faststart",
                                    str(output)], check=True)
        outputs = [output]
    elif voiced:  # some scenes only: no film, but each scene still gets its voice, and is checked
        outputs = []
        for name, part, r in zip(scenes, parts, reports):
            placed = [(e["t"], media / "voice" / e["wav"]) for e in r["timeline"]]
            out = media / f"scenes-{mode}" / f"{name}.mp4"
            narrate(part, placed, video_seconds(part), media / f"narration-{mode}-{name}.wav", out)
            outputs.append(out)
    else:
        outputs = parts

    run = {"film": str(film.path), "mode": mode, "scenes": scenes, "voiced": voiced,
           "joined": joined, "outputs": [str(p) for p in outputs]}
    manifest.write_text(json.dumps(run, indent=1))
    report = build_report(film, run, reports, args.transcribe, media)
    (media / f"report-{mode}.json").write_text(json.dumps(report, indent=1))
    print_report(report, args.json)
    return 0 if report["ok"] else 2


def last_run(film, media, mode):
    """What the last successful render in this mode produced, verified to still be there."""
    manifest = media / f"render-{mode}.json"
    if not manifest.exists():
        sys.exit(f"no successful {mode} render of {film.path.name} to look at: "
                 f"run `explainer render {film.path}{' --draft' if mode == 'draft' else ''}`")
    run = json.loads(manifest.read_text())
    if run.get("film") != str(film.path):  # a scratch directory shared between films
        sys.exit(f"the last {mode} render in {media} was of {run.get('film')}, not of "
                 f"{film.path}; render this film again")
    run_dir = media / f"run-{mode}"
    needed = [run_dir / f"{s}.json" for s in run["scenes"]]
    needed += part_paths(film, media, mode, run["scenes"])
    missing = [str(p) for p in needed if not p.exists()]
    if missing:
        sys.exit("the last render is incomplete; render again. Missing:\n  "
                 + "\n  ".join(missing))
    return run


def cmd_check(args):
    film = Film(args.film)
    media = media_dir(film, args.media)
    mode = "draft" if args.draft else "final"
    need_whisper(args)
    run = last_run(film, media, mode)
    if args.out:
        if not run["joined"]:
            sys.exit("-o names a joined film, but the last render was of some scenes only")
        run["outputs"] = [str(pathlib.Path.cwd() / args.out)]
    missing = [p for p in run["outputs"] if not pathlib.Path(p).exists()]
    if missing:
        sys.exit("nothing to check: the rendered file is gone\n  " + "\n  ".join(missing))
    reports = scene_reports(media / f"run-{mode}", run["scenes"])
    lengths = [video_seconds(p) for p in part_paths(film, media, mode, run["scenes"])]
    expected = [sum(lengths)] if run["joined"] else lengths
    wrong = [f"{path} {problem}" for path, seconds in zip(run["outputs"], expected)
             if (problem := movie_problem(path, seconds, run["voiced"]))]
    if wrong:
        sys.exit("nothing to check: not the movie the render made\n  " + "\n  ".join(wrong))
    report = build_report(film, run, reports, args.transcribe, media)
    (media / f"report-{mode}.json").write_text(json.dumps(report, indent=1))
    print_report(report, args.json)
    return 0 if report["ok"] else 2


def cmd_say(args):
    film = Film(args.film)
    scenes = pick_scenes(film, args.scenes)
    problems = film.problems_for(scenes)
    records = film.records_for(scenes)
    try:
        sounds = voice.phonemes([text for _, _, text in records])
    except ImportError:
        sounds = [None] * len(records)
    lines = [{"scene": owner, "line": line, "text": text, "phonemes": sound}
             for (owner, line, text), sound in zip(records, sounds)]
    if args.json:
        out(json.dumps({"lines": lines, "problems": problems}, indent=1))
    else:
        for problem in problems:
            out(problem)
        for item in lines:
            out(f"{item['scene'] or '(module)'}:{item['line']}  {item['text']}")
            if item["phonemes"]:
                out(f"    {item['phonemes']}")
    return 1 if problems else 0


def cmd_sheet(args):
    film = Film(args.film)
    media = media_dir(film, args.media)
    mode = "draft" if args.draft else "final"
    run = last_run(film, media, mode)
    scenes = [s for s in run["scenes"] if not args.scenes or s in args.scenes]
    out = media / "sheets"
    out.mkdir(exist_ok=True)
    for name, part in zip(scenes, part_paths(film, media, mode, scenes)):
        count = max(1, math.ceil(video_seconds(part) / args.every))
        rows = math.ceil(count / args.columns)
        sheet = out / f"{name}.png"
        subprocess.run(QUIET + ["-i", str(part), "-vf",
                                f"fps=1/{args.every}:start_time={args.every / 2},"
                                f"scale={args.width}:-1,"
                                f"tile={args.columns}x{rows}:padding=4:color=0x444444",
                                "-frames:v", "1", str(sheet)], check=True)
        out(sheet)
    return 0


def cmd_doctor(_args):
    ok = True

    def line(good, what, fix=""):
        nonlocal ok
        ok = ok and good
        out(f"  {'ok     ' if good else 'MISSING'} {what}{'' if good else '  -> ' + fix}")

    setup = f"run {KIT / 'setup.sh'}"
    try:
        import manim
        line(True, f"manim {manim.__version__}")
    except ImportError:
        line(False, "manim", setup)
    line(shutil.which("ffmpeg") is not None, "ffmpeg", setup)
    line(len(list((KIT / "explainer_kit" / "fonts").glob("*.ttf"))) >= 7, "Computer Modern fonts",
         "restore tools/explainer/explainer_kit/fonts")
    try:
        import kokoro_onnx  # noqa: F401
        line(True, "kokoro-onnx (narration)")
    except ImportError:
        line(False, "kokoro-onnx (narration)", setup + ", or render with --no-voice")
    whole = all((voice.MODELS / name).exists() and (voice.MODELS / name).stat().st_size == size
                for name, size in voice.MODEL_FILES.items())
    line(whole, f"Kokoro model files, complete, in {voice.MODELS}", setup)
    try:
        import faster_whisper  # noqa: F401
        ready = voice.whisper_model() is not None
    except ImportError:
        ready = False
    state = "ok     " if ready else "absent "
    out(f"  {state} faster-whisper and its model (optional: --transcribe)"
          f"{'' if ready else '  -> ' + setup + ' --with-whisper'}")
    return 0 if ok else 1


def main(argv=None):
    parser = argparse.ArgumentParser(prog="explainer", description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)

    def film_command(name, func, scenes=True):
        p = sub.add_parser(name)
        p.add_argument("film", help="the film: a Python file of Explainer scenes")
        p.add_argument("--media", help="scratch directory (default: under the system temp dir)")
        p.add_argument("--json", action="store_true", help="print the report as JSON only")
        if scenes:
            p.add_argument("--scenes", nargs="+", metavar="SCENE", help="only these scenes")
        p.set_defaults(func=func)
        return p

    p = film_command("lint", cmd_lint)
    p.add_argument("--jobs", type=int, default=os.cpu_count() or 2)

    p = film_command("render", cmd_render)
    p.add_argument("--draft", action="store_true", help="854x480 at 15 fps, kept in scratch")
    p.add_argument("--no-voice", action="store_true", help="captions only, timed by reading")
    p.add_argument("--transcribe", action="store_true",
                   help="also check each clip by speech-to-text (setup.sh --with-whisper)")
    p.add_argument("-o", "--out", help="where to write the film (default: beside the film file)")
    p.add_argument("--jobs", type=int, default=os.cpu_count() or 2)

    p = film_command("check", cmd_check, scenes=False)
    p.add_argument("--draft", action="store_true")
    p.add_argument("--transcribe", action="store_true")
    p.add_argument("-o", "--out", help="the film to check, if it is not where render wrote it")

    film_command("say", cmd_say)

    p = film_command("sheet", cmd_sheet)
    p.add_argument("--draft", action="store_true")
    p.add_argument("--every", type=float, default=4.0, help="seconds between frames")
    p.add_argument("--columns", type=int, default=3)
    p.add_argument("--width", type=int, default=640, help="pixels per frame")

    sub.add_parser("doctor").set_defaults(func=cmd_doctor)

    args = parser.parse_args(argv)
    with contextlib.redirect_stdout(sys.stderr):
        return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
