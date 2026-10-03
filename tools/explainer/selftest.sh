#!/usr/bin/env bash
# The tool's own tests.
#
#   ./selftest.sh         geometry: each check must flag its seeded defect, as its own kind, and
#                         the clean scenes must stay clean. Then the unit checks. Draws nothing:
#                         about twenty seconds.
#   ./selftest.sh --full  also renders a small narrated film, and checks what only a real render
#                         shows: about a minute more.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
env=${EXPLAINER_ENV:-${MANIM_ENV:-$HOME/.local/share/manim-env-root/env}}
media=$(mktemp -d)
trap 'rm -rf "$media"' EXIT
explainer="$here/explainer"

"$explainer" lint "$here/examples/defects.py" --media "$media/defects" --json \
  >"$media/defects.json" || [ $? = 2 ]
"$explainer" lint "$here/examples/minimal.py" --media "$media/minimal" --json \
  >"$media/minimal.json"

python3 - "$media/defects.json" "$media/minimal.json" <<'PY'
import json, sys
defects, minimal = (json.load(open(p)) for p in sys.argv[1:3])
expected = {
    "Clean": [], "CleanOutline": [],
    "OffFrame": ["off_frame"], "NearEdge": ["near_edge"], "TextOverlap": ["text_overlap"],
    "CaptionOverlap": ["caption_overlap"], "SmallText": ["small_text"],
    "CaptionCut": ["caption_cut"],
    "ArrowOffFrame": ["off_frame"], "ThickLineInCaption": ["caption_overlap"],
    "PlainTextOverlap": ["text_overlap"], "PlainSmallText": ["small_text"],
    "ImageOffFrame": ["off_frame"], "CaptionLinesCollide": ["text_overlap"],
    "BackgroundStrokeInCaption": ["caption_overlap"],
    "PlainTextLosesAGlyph": ["text_overlap"], "KitTextLosesAGlyph": ["text_overlap"],
    "CodeLineLosesAGlyph": ["text_overlap"],
    "CleanTransparentImages": [],
}
found = {name: [] for name in expected}
for f in defects["lint"]["findings"]:
    found.setdefault(f["scene"], []).append(f["kind"])
bad = {name: (found[name], kinds) for name, kinds in expected.items()
       if set(found[name]) != set(kinds)}
bad.update({name: (kinds, "no such scene expected") for name, kinds in found.items()
            if name not in expected})
for name, (got, want) in bad.items():
    print(f"FAIL {name}: lint found {got}, expected {want}")
if minimal["lint"]["findings"] or not minimal["ok"]:
    bad["minimal"] = True
    print(f"FAIL minimal.py: expected no findings, got {minimal['lint']['findings']}")
if defects["ok"]:
    bad["ok"] = True
    print("FAIL defects.py: the report says ok although it holds errors")
seeded = sum(1 for kinds in expected.values() if kinds)
print("geometry: " + ("FAILED" if bad else
      f"ok, {seeded} seeded defects each flagged as its own kind, "
      f"{len(expected) - seeded + 1} clean scenes clean"))
sys.exit(1 if bad else 0)
PY

PATH="$env/bin:$PATH" PYTHONPATH="$here" PYTHONDONTWRITEBYTECODE=1 \
  "$env/bin/python" "$here/tests/units.py"

[ "${1:-}" = --full ] || exit 0

film="$here/tests/film.py"
m="$media/full"
fail() { echo "FAIL $1"; exit 1; }
# status COMMAND...: run it quietly and print its exit status, whatever that is.
status() { set +e; "$@" >/dev/null 2>&1; echo $?; set -e; }

# A first render makes its clips; --json must still be nothing but the report.
"$explainer" render "$film" --draft --media "$m" --json >"$media/first.json" 2>"$media/first.err"
python3 -c "
import json, sys
r = json.load(open('$media/first.json'))
assert r['ok'] and r['voice']['clips'] == 3 and r['voice']['sync']['ok'], r['voice']
" || fail "a fresh render with --json did not print one valid, passing report"
grep -q "voiced" "$media/first.err" || fail "the first render did not report making clips"

# Some scenes only: each scene file carries its own narration and is checked.
"$explainer" render "$film" --draft --media "$m" --scenes B --json >"$media/partial.json"
python3 -c "
import json, sys
r = json.load(open('$media/partial.json'))
assert r['output'] is None and len(r['scene_files']) == 1 and r['voice']['sync']['ok'], r
print(r['scene_files'][0])" >"$media/partial.path" ||
  fail "render --scenes did not check its scene file"
"$env/bin/ffprobe" -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 \
  "$(cat "$media/partial.path")" | grep -q aac ||
  fail "render --scenes wrote a scene file with no audio"

# The same film with its audio a second late must fail, and fail on sync: exit 2, sync not ok.
# Any other way of failing (a crash, a refusal) would also be non-zero, so the code is checked.
"$explainer" render "$film" --draft --media "$m" >/dev/null 2>&1
"$env/bin/ffmpeg" -y -loglevel error -i "$m/picture-draft.mp4" -itsoffset 1 -i "$m/draft.mp4" \
  -map 0:v -map 1:a -c copy "$media/late.mp4"
set +e
( cd "$media" && "$explainer" check "$film" --draft --media "$m" -o late.mp4 --json \
  >"$media/late.json" 2>/dev/null )
code=$?
set -e
[ "$code" = 2 ] || fail "check of a film with late narration exited $code, not 2"
python3 -c "
import json
r = json.load(open('$media/late.json'))
assert r['voice']['sync']['ok'] is False and r['lint']['errors'] == 0, r['voice']
" || fail "check of a film with late narration did not fail on sync"

# With the speech-to-text check on, stdout is still the report alone.
if "$explainer" doctor 2>/dev/null | grep -q "ok.*faster-whisper"; then
  "$explainer" check "$film" --draft --media "$m" --transcribe --json \
    >"$media/heard.json" 2>/dev/null
  python3 -c "
import json
r = json.load(open('$media/heard.json'))
assert r['voice']['transcription']['of'] == 3, r['voice']
" || fail "check --transcribe --json did not print one valid report"
  heard="transcription as JSON, "
else
  heard=""
fi

# A caption that stayed up until its slow narration ended was not cut short.
EXPLAINER_SPEED=0.5 "$explainer" render "$here/tests/slow.py" --draft --media "$media/slow" \
  --json >"$media/slow.json" 2>/dev/null || fail "the slow-narration film did not render clean"
python3 -c "
import json
r = json.load(open('$media/slow.json'))
assert r['lint']['findings'] == [] and r['voice']['clips'] == 2, r['lint']
" || fail "a caption kept up by its narration was reported as cut"

# A film that is gone, and a render in which a scene crashed: refused, exit 1, nothing approved.
mv "$m/draft.mp4" "$media/kept.mp4"
code=$(status "$explainer" check "$film" --draft --media "$m")
[ "$code" = 1 ] || fail "check with the rendered film gone exited $code, not 1"
mv "$media/kept.mp4" "$m/draft.mp4"
code=$(EXPLAINER_TEST_CRASH=1 status "$explainer" render "$film" --draft --media "$m")
[ "$code" = 1 ] || fail "a render in which a scene crashed exited $code, not 1"
code=$(status "$explainer" check "$film" --draft --media "$m")
[ "$code" = 1 ] || fail "check after a render in which a scene crashed exited $code, not 1"

echo "full: ok, fresh --json, narrated --scenes, late audio fails on sync," \
  "${heard}slow narration, missing film, crashed scene"
