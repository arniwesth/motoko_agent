"""explainer: render a narrated Manim film from a file of Explainer scenes, and check it.

    explainer lint FILM            run every scene's timeline without drawing it (seconds)
    explainer render FILM          narrate, render, join, and check; writes the mp4 and a report
    explainer check FILM           re-run the checks on the last render
    explainer say FILM             print each spoken line and how it will be pronounced
    explainer sheet FILM           contact sheets of the last render, for an author with eyes
    explainer doctor               say what is installed and what is missing

Exit status: 0 clean, 1 could not render, 2 rendered but a check failed.
"""

from __future__ import annotations

import argparse
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
    args = [sys.executable, "-m", "manim", "render", "-r", f"{width},{height}", "--fps", str(fps),
            "--media_dir", str(media), "--disable_caching", "-v", "WARNING",
            "--progress_bar", "none"]
    if dry:  # -s draws only the last frame: animations jump to their ends, time still advances
        args.append("-s")
    failed, pending = [], list(scenes)
    running = {}
    while pending or running:
        while pending and len(running) < jobs:
            name = pending.pop(0)
            log = open(logs / f"{name}.log", "w")
            running[name] = (subprocess.Popen(args + [str(film.path), name], cwd=film.path.parent,
                                              env=env, stdout=log, stderr=subprocess.STDOUT), log)
        name, (proc, log) = next(iter(running.items()))
        proc.wait()
        log.close()
        del running[name]
        if proc.returncode != 0:
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


def rendered(film, media, mode):
    """The scenes of the last render in this mode, or exit if there was none."""
    run_dir = media / f"run-{mode}"
    scenes = [s for s in film.scenes if (run_dir / f"{s}.json").exists()]
    if not scenes:
        sys.exit(f"no {mode} render to look at yet: run `explainer render {film.path}` first")
    return scenes


def video_seconds(path):
    import av
    with av.open(str(path)) as container:
        stream = container.streams.video[0]
        return float(stream.frames / stream.average_rate)


def loudness(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af",
                          "ebur128=peak=true", "-f", "null", "-"], capture_output=True,
                         text=True).stderr
    tail = out[out.rfind("Summary:"):]
    integrated = re.search(r"I:\s+(-?[\d.]+) LUFS", tail)
    peak = re.search(r"Peak:\s+(-?[\d.]+) dBFS", tail)
    return {"integrated_lufs": float(integrated.group(1)) if integrated else None,
            "true_peak_dbfs": float(peak.group(1)) if peak else None}


def sync(path, starts):
    """How far each clip's first sound in the finished file is from where its scene put it."""
    import av
    import numpy as np
    with av.open(str(path)) as container:
        stream = container.streams.audio[0]
        rate = stream.rate
        frames = [f.to_ndarray().mean(axis=0) for f in container.decode(stream)]
    audio = np.concatenate(frames).astype(np.float32)
    hop = max(1, rate // 200)  # 5 ms
    level = np.sqrt(np.convolve(audio ** 2, np.ones(hop) / hop, mode="same"))
    offsets = []
    for start in starts:
        lo, hi = int((start - 0.2) * rate), int((start + 0.4) * rate)
        loud = np.flatnonzero(level[max(lo, 0):hi] > 0.006)  # about -45 dBFS
        offsets.append(None if len(loud) == 0 else (max(lo, 0) + loud[0]) / rate - start)
    return offsets


def build_report(film, scenes, reports, mode, output, voiced, transcribe, media):
    width, height, fps = MODES[mode]
    findings = [dict(f, scene=r["scene"]) for r in reports for f in r["lint"]]
    findings += [{"scene": None, "t": 0, "kind": "unspeakable", "severity": "error",
                  "detail": p, "what": []} for p in film.problems]
    report = {
        "film": str(film.path), "mode": mode, "output": str(output) if output else None,
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
    if voiced:
        offset, placed, overlaps = 0.0, [], 0
        for r in reports:
            end = 0.0
            for entry in r["timeline"]:
                clip = media / "voice" / entry["wav"]
                overlaps += entry["t"] < end - 1e-6
                end = entry["t"] + voice.seconds(clip)
                placed.append((offset + entry["t"], clip))
            offset += r["seconds"]
        info = {"engine": "kokoro-v1.0", "voice": voice.VOICE, "clips": len(placed),
                "speech_seconds": round(sum(voice.seconds(c) for _, c in placed), 1),
                "overlaps": overlaps}
        ok = ok and overlaps == 0
        if output and pathlib.Path(output).exists():
            offsets = sync(output, [start for start, _ in placed])
            missing = sum(o is None for o in offsets)
            worst = float(max((abs(o) for o in offsets if o is not None), default=0.0))
            info["sync"] = {"worst_ms": round(worst * 1000), "silent_clips": missing,
                            "ok": missing == 0 and worst < 0.08}
            info["loudness"] = loudness(output)
            ok = ok and info["sync"]["ok"]
        if transcribe:
            exact, diffs = voice.transcribe(film.texts(scenes), media / "voice")
            info["transcription"] = {"exact": exact, "of": exact + len(diffs),
                                     "diffs": [{"said": s, "heard": h} for s, h in diffs]}
        report["voice"] = info
    report["ok"] = bool(ok)
    return report


def print_report(report, as_json):
    if as_json:
        print(json.dumps(report, indent=1))
        return
    minutes, seconds = divmod(report["seconds"], 60)
    print(f"{len(report['scenes'])} scenes, {int(minutes)} min {seconds:.0f} s, "
          f"{report['resolution']} at {report['fps']} fps ({report['mode']})")
    for scene in report["scenes"]:
        print(f"  {scene['name']:<14} {scene['seconds']:6.1f} s  {scene['captions']} captions")
    lint = report["lint"]
    print(f"lint: {lint['errors']} errors, {lint['warnings']} warnings")
    for f in lint["findings"]:
        where = f"{f['scene']} at {f['t']} s" if f["scene"] else "film"
        print(f"  {f['severity']:<7} {f['kind']:<15} {where}: {f['detail']}")
        for text in f["what"]:
            print(f"            \"{text}\"")
    v = report["voice"]
    if v:
        print(f"voice: {v['clips']} clips, {v['speech_seconds']} s of speech, "
              f"{v['overlaps']} overlaps ({v['voice']})")
        if "sync" in v:
            print(f"  sync: worst {v['sync']['worst_ms']} ms, "
                  f"{v['sync']['silent_clips']} clips not found in the file")
            print(f"  loudness: {v['loudness']['integrated_lufs']} LUFS, "
                  f"peak {v['loudness']['true_peak_dbfs']} dBFS")
        if "transcription" in v:
            t = v["transcription"]
            print(f"  transcription: {t['exact']} of {t['of']} clips word for word")
            for d in t["diffs"]:
                print(f"    said   {d['said']}\n    heard  {d['heard']}")
    if report["output"]:
        print(report["output"])
    print("ok" if report["ok"] else "CHECKS FAILED")


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
        lines = (media / "logs" / f"{name}.log").read_text().splitlines()
        print(f"--- {name} failed; last lines of {media / 'logs' / (name + '.log')}")
        print("\n".join(lines[-25:]))


def cmd_lint(args):
    film = Film(args.film)
    scenes = pick_scenes(film, args.scenes)
    media = media_dir(film, args.media)
    # Use the narration's timing when every clip is already made; else time by reading speed.
    texts = film.texts(scenes)
    voiced = bool(texts) and all(voice.clip_path(t, media / "voice").exists() for t in texts)
    run_dir = media / "run-lint"
    failed = run_scenes(film, scenes, media, run_dir, "final", voiced, True, args.jobs)
    if failed:
        tail_logs(media, failed)
        return 1
    report = build_report(film, scenes, scene_reports(run_dir, scenes), "final", None, False,
                          False, media)
    report["timed_by"] = "narration" if voiced else "reading speed"
    print_report(report, args.json)
    return 0 if report["ok"] else 2


def cmd_render(args):
    film = Film(args.film)
    scenes = pick_scenes(film, args.scenes)
    mode = "draft" if args.draft else "final"
    media = media_dir(film, args.media)
    voiced = not args.no_voice
    if film.problems and voiced:
        print("\n".join(film.problems))
        return 1
    if voiced:
        made = voice.synth(film.texts(scenes), media / "voice")
        if made and not args.json:
            print(f"narration: {made} new clips")
    run_dir = media / f"run-{mode}"
    failed = run_scenes(film, scenes, media, run_dir, mode, voiced, False, args.jobs)
    if failed:
        tail_logs(media, failed)
        return 1
    reports = scene_reports(run_dir, scenes)
    parts = part_paths(film, media, mode, scenes)

    output = None
    if scenes == film.scenes:  # a partial render leaves the scenes' own files and no film
        output = film_path(film, media, mode, args.out)
        listing = media / f"concat-{mode}.txt"
        listing.write_text("".join(f"file '{p}'\n" for p in parts))
        picture = media / f"picture-{mode}.mp4"
        quiet = ["ffmpeg", "-y", "-loglevel", "error"]
        subprocess.run(quiet + ["-f", "concat", "-safe", "0", "-i", str(listing), "-c", "copy",
                                str(picture)], check=True)
        if voiced:
            offset, placed = 0.0, []
            for part, r in zip(parts, reports):
                placed += [(offset + e["t"], media / "voice" / e["wav"]) for e in r["timeline"]]
                offset += video_seconds(part)
            track = media / f"narration-{mode}.wav"
            voice.mix(placed, offset, track)
            subprocess.run(quiet + ["-i", str(picture), "-i", str(track), "-map", "0:v", "-map",
                                    "1:a", "-af", voice.MASTER, "-c:v", "copy", "-c:a", "aac",
                                    "-b:a", "128k", "-ar", "48000", "-movflags", "+faststart",
                                    str(output)], check=True)
        else:
            subprocess.run(quiet + ["-i", str(picture), "-c", "copy", "-movflags", "+faststart",
                                    str(output)], check=True)

    report = build_report(film, scenes, reports, mode, output, voiced, args.transcribe, media)
    (media / f"report-{mode}.json").write_text(json.dumps(report, indent=1))
    print_report(report, args.json)
    return 0 if report["ok"] else 2


def cmd_check(args):
    film = Film(args.film)
    media = media_dir(film, args.media)
    mode = "draft" if args.draft else "final"
    scenes = rendered(film, media, mode)
    reports = scene_reports(media / f"run-{mode}", scenes)
    output = film_path(film, media, mode, args.out)
    if scenes != film.scenes or not output.exists():
        output = None
    voiced = any(r["timeline"] for r in reports)
    report = build_report(film, scenes, reports, mode, output, voiced, args.transcribe, media)
    (media / f"report-{mode}.json").write_text(json.dumps(report, indent=1))
    print_report(report, args.json)
    return 0 if report["ok"] else 2


def cmd_say(args):
    film = Film(args.film)
    for problem in film.problems:
        print(problem)
    texts = film.texts(pick_scenes(film, args.scenes))
    try:
        sounds = voice.phonemes(texts)
    except ImportError:
        sounds = [None] * len(texts)
    for (scene, line, text), sound in zip(film.lines, sounds):
        print(f"{scene}:{line}  {text}")
        if sound:
            print(f"    {sound}")
    return 1 if film.problems else 0


def cmd_sheet(args):
    film = Film(args.film)
    media = media_dir(film, args.media)
    mode = "draft" if args.draft else "final"
    scenes = [s for s in rendered(film, media, mode) if not args.scenes or s in args.scenes]
    out = media / "sheets"
    out.mkdir(exist_ok=True)
    for name, part in zip(scenes, part_paths(film, media, mode, scenes)):
        count = max(1, math.ceil(video_seconds(part) / args.every))
        rows = math.ceil(count / args.columns)
        sheet = out / f"{name}.png"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(part), "-vf",
                        f"fps=1/{args.every}:start_time={args.every / 2},scale={args.width}:-1,"
                        f"tile={args.columns}x{rows}:padding=4:color=0x444444",
                        "-frames:v", "1", str(sheet)], check=True)
        print(sheet)
    return 0


def cmd_doctor(_args):
    ok = True

    def line(good, what, fix=""):
        nonlocal ok
        ok = ok and good
        print(f"  {'ok     ' if good else 'MISSING'} {what}{'' if good else '  -> ' + fix}")

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
    models = all((voice.MODELS / f).exists() for f in ("kokoro-v1.0.onnx", "voices-v1.0.bin"))
    line(models, f"Kokoro model files in {voice.MODELS}", setup)
    try:
        import faster_whisper  # noqa: F401
        print("  ok      faster-whisper (optional: --transcribe)")
    except ImportError:
        print(f"  absent  faster-whisper (optional: --transcribe)  -> {setup} --with-whisper")
    return 0 if ok else 1


def main(argv=None):
    parser = argparse.ArgumentParser(prog="explainer", description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)

    def film_command(name, func, **flags):
        p = sub.add_parser(name)
        p.add_argument("film", help="the film: a Python file of Explainer scenes")
        p.add_argument("--media", help="scratch directory (default: under the system temp dir)")
        p.add_argument("--json", action="store_true", help="print the report as JSON only")
        if flags.get("scenes", True):
            p.add_argument("--scenes", nargs="+", metavar="SCENE", help="only these scenes")
        p.set_defaults(func=func)
        return p

    p = film_command("lint", cmd_lint)
    p.add_argument("--jobs", type=int, default=os.cpu_count() or 2)

    p = film_command("render", cmd_render)
    p.add_argument("--draft", action="store_true", help="854x480 at 15 fps, kept in scratch")
    p.add_argument("--no-voice", action="store_true", help="captions only, timed by reading")
    p.add_argument("--transcribe", action="store_true",
                   help="also check each clip by speech-to-text (needs faster-whisper)")
    p.add_argument("-o", "--out", help="where to write the film (default: beside the film file)")
    p.add_argument("--jobs", type=int, default=os.cpu_count() or 2)

    p = film_command("check", cmd_check, scenes=False)
    p.add_argument("--draft", action="store_true")
    p.add_argument("--transcribe", action="store_true")
    p.add_argument("-o", "--out", help="the film to check, if render was given -o")

    film_command("say", cmd_say)

    p = film_command("sheet", cmd_sheet)
    p.add_argument("--draft", action="store_true")
    p.add_argument("--every", type=float, default=4.0, help="seconds between frames")
    p.add_argument("--columns", type=int, default=3)
    p.add_argument("--width", type=int, default=640, help="pixels per frame")

    sub.add_parser("doctor").set_defaults(func=cmd_doctor)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
