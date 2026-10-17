"""013 PLAN-004 explainer: what `make eval_matrix` runs, compares and is for.

A film for tools/explainer: one Explainer scene per beat, each caption also spoken. Render with
`tools/explainer/explainer render eval_matrix.py`. Every number on screen is read from a file the
scene's sources line names; README.md lists them and says what is illustrative.
"""

from manim import *

from explainer_kit import *

OUTPUT = "eval-matrix-explainer.mp4"

# Captions are written to be read; these make them sayable.
SAY = [
    (r"\bcase_id\b", "case I D"),
    (r"\bmake dst\b", "make D S T"),
    (r"\bCI\b", "C I"),
    (r"\b013\b", "oh thirteen"),
    (r"\b011\b", "oh eleven"),
    (r"\b621\b", "six hundred and twenty-one"),
    (r"\b360\b", "three hundred and sixty"),
    (r"\b185\b", "one hundred and eighty-five"),
    (r"\b425\b", "four hundred and twenty-five"),
]

# Colour is meaning. A join status keeps one colour in every scene, as a mark and as a word:
# blue a recorded verdict that matched, green a row credited on its test's pass, grey a row with
# no test, amber nothing observed, red observed and wrong. Verdict values are data and stay
# uncoloured: 360 rows expect `refused`, and that is not a fault. The four hues, in stack order,
# pass the dataviz palette validator against BG (README, "Notes on the source").
C_EQ = "#3987e5"
C_CR = "#199e70"
C_NA = "#898781"
C_MISS = "#c98500"
C_BAD = "#d03b3b"
STATUS = {"equal": C_EQ, "credited": C_CR, "inapplicable": C_NA, "missing": C_MISS,
          "skipped": C_MISS, "failed": C_BAD, "mismatch": C_BAD}
TAGS.update({"e": C_EQ, "k": C_CR, "n": C_NA, "x": C_MISS, "f": C_BAD})
C_EVAL = PURPLE  # the evaluator, the thing under test

ROWS = 621  # data rows of MATRIX.expected.tsv

# One row of MATRIX.expected.tsv, and what the run at 59d5cbb9 printed and wrote for it.
CASE = "M14.ProjectionDiffers"
TEST_FILE = "src/eval/journal/candidate_checks_live_test.ail"
TEST_NAME = "m14_k2_projection_differs"
PRINTED = "Diverged(K2:ProjectionDiffers[ReplayMismatch]@interaction:14)"

# expected_verdict over the 621 rows; the last cell folds the five smallest classes.
EXPECTED = [("refused", 360), ("pass", 165), ("admitted", 33), ("diverged", 32),
            ("inapplicable", 11), ("five others", 20)]
OTHERS = "allowed 9 · hard_error 6 · reproduced 3 · fail 1 · error 1"

# Join statuses of two runs: PLAN-004 §6 (P1R R1) at d74079d, and matrix-logs/join.tsv at
# 59d5cbb9.
CLEAN = [("equal", 185), ("credited", 425), ("inapplicable", 11)]
TODAY = [("equal", 129), ("credited", 419), ("inapplicable", 11), ("missing", 33), ("failed", 29)]


def swatch(color, side=0.16):
    return Square(side_length=side, stroke_width=0, fill_color=color, fill_opacity=1)


def stack(counts, left, y, width, h=0.28):
    """A part-to-whole bar, ROWS wide: one fill per status, a gap of background between them."""
    gap, x, segs = 0.035, left, VGroup()
    for i, (key, n) in enumerate(counts):
        w = max(width * n / ROWS - gap, 0.03)
        end = min(0.04, w / 4)  # the data end is rounded, a little, and the rest is square
        radius = [end, 0.001, 0.001, end] if i == len(counts) - 1 else 0.001
        seg = RoundedRectangle(width=w, height=h, corner_radius=radius, stroke_width=0,
                               fill_color=STATUS[key], fill_opacity=1)
        seg.move_to([x + w / 2, y, 0])
        segs.add(seg)
        x += w + gap
    return segs


def tally(counts, size=15):
    """The same counts in words, each beside its colour: the bar's legend and its table."""
    items = VGroup(*[VGroup(swatch(STATUS[key]), T("{w|%d} %s" % (n, key), size=size,
                                                   color=GREY_B)).arrange(RIGHT, buff=0.1)
                     for key, n in counts])
    return items.arrange(RIGHT, buff=0.28)


def actor(name, sub, color, w=3.2, h=1.1):
    """A named box with a second, smaller line: what it is, then what it is made of."""
    box = RoundedRectangle(width=w, height=h, corner_radius=0.18, stroke_color=color,
                           stroke_width=3, fill_color=color, fill_opacity=0.14)
    top = T(name, size=24).move_to(box.get_center() + UP * 0.2)
    low = T(sub, size=17, color=GREY_B).move_to(box.get_center() + DOWN * 0.24)
    return VGroup(box, top, low)


def titled(title, sub, lines, x, top, size=16, w=None):
    """A card of code lines with a file name above it."""
    body = card(lines, size=size, w=w)
    name = T("{c|" + title + "}", size=19)
    note = T(sub, size=15, color=GREY_B)
    head = VGroup(name, note).arrange(RIGHT, buff=0.25)
    head.move_to([x, top, 0])
    body.next_to(head, DOWN, buff=0.14).set_x(x)
    group = VGroup(head, body)
    group.card, group.lines, group.head = body, body.lines, head
    return group


class S1_Question(Explainer):
    """What the evaluator does, and why something has to check it."""

    def construct(self):
        title = T("{c|make eval_matrix}", size=70)
        sub = T("the test contract of the journal evaluator", size=34, color=BLUE)
        tag = T("013 · ADR-004 · PLAN-004 §3", size=22, color=GREY_B)
        VGroup(title, sub, tag).arrange(DOWN, buff=0.4).move_to(UP * 0.3)
        self.speak("Make eval matrix.")
        self.play(Write(title), run_time=1.6)
        self.hush(0.1)
        self.speak("The test contract of the journal evaluator.")
        self.play(FadeIn(sub, shift=0.2 * UP), run_time=0.7)
        self.play(FadeIn(tag), run_time=0.5)
        self.wait(0.8)
        self.hush()
        self.play(FadeOut(VGroup(title, sub, tag), shift=0.4 * UP), run_time=0.7)

        self.header("The evaluator", "what project 013 built, and what checks it")
        self.source("ADR-004 TL;DR, D2, D3 (A1–A9, A9b, K0–K7, the verdicts)  ·  621: "
                    "MATRIX.expected.tsv  ·  “the test contract”: 011 spike note, Part 6")
        y = 1.25
        journal = actor("session journal", "one recorded run", GREY_B, w=2.7).move_to([-5.45, y, 0])
        admit = actor("admission", "checks A1–A9, A9b", C_EVAL).move_to([-0.75, y, 0])
        cand = actor("candidate replay", "checks K0–K7", C_EVAL, w=3.4).move_to([4.0, y, 0])
        frame = RoundedRectangle(width=9.4, height=3.35, corner_radius=0.2, stroke_color=C_EVAL,
                                 stroke_width=2).move_to([1.75, 0.9, 0])
        frame_l = T("the evaluator", size=20, color=C_EVAL)
        frame_l.move_to(frame.get_corner(UL) + RIGHT * 0.3 + DOWN * 0.3, aligned_edge=LEFT)
        feed = arrow(journal.get_right(), admit.get_left(), color=GREY_A)
        hand = arrow(admit.get_right(), cand.get_left(), color=GREY_A)
        hand_l = T("the program", size=15, color=GREY_B).next_to(hand, UP, buff=0.08)

        def verdicts(names, x):
            row = VGroup(*[pill(n, GREY_B, size=16, font=MONO, pad=0.36, text_color=WHITE)
                           for n in names])
            return row.arrange(RIGHT, buff=0.12).move_to([x, -0.1, 0])

        v_admit = verdicts(["admitted", "refused"], -0.75)
        v_cand = verdicts(["reproduced", "diverged", "refused"], 4.0)
        d_admit = arrow(admit.get_bottom(), v_admit.get_top(), color=GREY_B, width=3, tip=0.15)
        d_cand = arrow(cand.get_bottom(), v_cand.get_top(), color=GREY_B, width=3, tip=0.15)

        self.say("Project 013 built an {p|evaluator}: it replays one recorded session,",
                 "then judges a code change against that replay.")
        self.play(FadeIn(journal, shift=0.2 * UP), run_time=0.6)
        self.play(Create(frame), FadeIn(frame_l), run_time=0.8)
        self.play(GrowArrow(feed), FadeIn(admit, shift=0.2 * RIGHT), run_time=0.7)
        self.play(GrowArrow(hand), FadeIn(hand_l), FadeIn(cand, shift=0.2 * RIGHT), run_time=0.7)
        self.rest()

        self.say("First it {p|admits} the recording. Ten checks ask whether the replay",
                 "is faithful to its source.")
        self.play(Indicate(admit, color=WHITE, scale_factor=1.05), run_time=0.9)
        self.play(GrowArrow(d_admit), FadeIn(v_admit, shift=0.15 * DOWN), run_time=0.7)
        self.rest()

        self.say("Then a {p|candidate} change replays the recorded program.",
                 "The verdict is reproduced, diverged, or refused.")
        self.play(Indicate(cand, color=WHITE, scale_factor=1.05), run_time=0.9)
        self.play(GrowArrow(d_cand), FadeIn(v_cand, shift=0.15 * DOWN), run_time=0.7)
        self.rest()

        self.say("Every one of those answers could be wrong.",
                 "So the evaluator has a test contract of its own.")
        table = pill("621 cases whose answer is written down first", WHITE, size=20, fill=0.06)
        table.move_to([1.75, -1.75, 0])
        up = arrow(table.get_top(), frame.get_bottom(), color=WHITE, width=3, tip=0.16)
        self.play(FadeIn(table, shift=0.2 * UP), run_time=0.7)
        self.play(GrowArrow(up), run_time=0.5)
        self.rest(0.6)
        self.end()


class S2_Row(Explainer):
    """One row of the expected table, then the table as a whole."""

    def construct(self):
        self.header("The expected table", "621 cases, each with its answer written down first")
        self.source("src/eval/journal/testdata/MATRIX.expected.tsv at 59d5cbb9 (the row, 621, "
                    "the counts)  ·  PLAN-004 §3, “The D8 P1 matrix”  ·  ADR-004 D8")
        folder, _, module = TEST_FILE.rpartition("/")
        fields = [("case_id", CASE), ("test_name", folder + "/"), ("", "  " + module),
                  ("", "  :" + TEST_NAME), ("expected_verdict", "diverged"),
                  ("expected_first_finding", "K2:ProjectionDiffers"),
                  ("expected_position", "interaction:14")]
        row = titled("MATRIX.expected.tsv", "one of its rows, a field to a line",
                     ["{m|%-24s}{w|%s}" % f for f in fields], -2.72, 2.75, size=19)
        L = row.lines
        self.say("The contract is a table. Each row is one case",
                 "whose answer is known. Here is a row.")
        self.play(FadeIn(row, shift=0.2 * UP), run_time=0.8)
        self.rest()

        def note(lines, words):
            mid = VGroup(*lines).get_center()[1]
            x0 = row.card.get_right()[0]
            text = T(words, size=18, color=GREY_A).move_to([x0 + 0.5, mid, 0], aligned_edge=LEFT)
            lead = Line([x0 + 0.08, mid, 0], [x0 + 0.4, mid, 0], stroke_width=1.5, color=GREY_C)
            return VGroup(lead, text)

        def mark(lines):
            return SurroundingRectangle(VGroup(*lines), color=WHITE, buff=0.07, stroke_width=2,
                                        corner_radius=0.05)

        self.say("It names the case, and the one test that exercises it:",
                 "a suite file, then a test inside that file.")
        m1 = mark([L[0], L[1], L[2], L[3]])
        n1 = VGroup(note([L[0]], "the case, by family: M14, divergences"),
                    note([L[1], L[2], L[3]], "the suite file, then the test in it"))
        self.play(Create(m1), run_time=0.6)
        self.play(LaggedStart(*[FadeIn(n, shift=0.15 * LEFT) for n in n1], lag_ratio=0.5),
                  run_time=1.2)
        self.rest()

        self.say("Then the answer, in three parts: the verdict, the first finding,",
                 "and the position where it is found.")
        m2 = mark([L[4], L[5], L[6]])
        n2 = VGroup(note([L[4]], "what the evaluator must say"),
                    note([L[5]], "which check, and what it reports first"),
                    note([L[6]], "where: here, interaction 14 of the replay"))
        self.play(ReplacementTransform(m1, m2), n1.animate.set_opacity(0.35), run_time=0.7)
        self.play(LaggedStart(*[FadeIn(n, shift=0.15 * LEFT) for n in n2], lag_ratio=0.4),
                  run_time=1.4)
        self.rest()

        self.say("There are 621 rows. Each was written by the work that landed its case,",
                 "and reviewed with that commit.")
        head = T("{c|expected_verdict}, over all 621 rows", size=17, color=GREY_B)
        head.move_to([0, -0.78, 0])
        cells = VGroup()
        for name, n in EXPECTED:
            label = T(name if " " in name else "{c|" + name + "}", size=16, color=GREY_B)
            cells.add(VGroup(T(str(n), size=34), label).arrange(DOWN, buff=0.08))
        for cell, x in zip(cells, [-5.5, -3.3, -1.1, 1.1, 3.3, 5.5]):
            cell.move_to([x, -1.5, 0])
        rest = T(OTHERS, size=14, color=GREY_C).next_to(cells[5], DOWN, buff=0.14)
        rest.shift(RIGHT * (6.9 - rest.get_right()[0]))
        self.play(FadeOut(m2), FadeOut(n1), FadeOut(n2), run_time=0.5)
        self.play(FadeIn(head), LaggedStart(*[FadeIn(c, shift=0.15 * UP) for c in cells],
                                            lag_ratio=0.15), run_time=1.5)
        self.play(FadeIn(rest), run_time=0.4)
        self.rest()

        self.say("360 of them expect a refusal: the evaluator must say no,",
                 "at the right place, for the right reason.")
        ring = SurroundingRectangle(cells[0], color=WHITE, buff=0.14, stroke_width=2,
                                    corner_radius=0.08)
        self.play(Create(ring), run_time=0.6)
        self.rest(0.6)
        self.end()


class S3_Run(Explainer):
    """What the target runs, in what order, and what it writes."""

    def construct(self):
        self.header("A run", "every suite the table names, one at a time")
        self.source("Makefile:3357–3368  ·  candidate.py:108–134, :1598–1723  ·  27: test_name "
                    "in MATRIX.expected.tsv  ·  821 s: meta.txt at 59d5cbb9  ·  12 GiB: "
                    "mem_guard.py:88")
        chain = VGroup(*[pill(c, GREY_B, size=17, font=MONO, text_color=WHITE)
                         for c in ["make eval_matrix", "journal_replay.sh matrix",
                                   "candidate.py matrix"]])
        chain.arrange(RIGHT, buff=0.9).move_to([0, 2.6, 0])
        links = VGroup(*[arrow(chain[i].get_right(), chain[i + 1].get_left(), color=GREY_A,
                               width=3, tip=0.16) for i in range(2)])
        self.say("The target is one line. It hands over to a script that reads",
                 "the table and collects every file its rows name.")
        self.play(FadeIn(chain[0], shift=0.2 * RIGHT), run_time=0.5)
        self.play(GrowArrow(links[0]), FadeIn(chain[1], shift=0.2 * RIGHT), run_time=0.6)
        self.play(GrowArrow(links[1]), FadeIn(chain[2], shift=0.2 * RIGHT), run_time=0.6)
        self.rest()

        groups = [(17, "pure test modules", "ailang test --format json"),
                  (7, "live runners", "ailang run --ai-stub --entry main"),
                  (3, "Python suites", "selftest.py · gen_fixtures.py · test_candidate.py"),
                  (1, "gate, named by no row", "test_mem_guard.py")]
        rows, boxes = VGroup(), []
        for i, (n, name, how) in enumerate(groups):
            y = 1.45 - i * 0.95
            label = T("{w|%d} %s" % (n, name), size=22, color=GREY_A)
            label.move_to([-6.8, y + 0.18, 0], aligned_edge=LEFT)
            cmd = T("{c|" + how + "}", size=15, color=GREY_B)
            cmd.move_to([-6.8, y - 0.21, 0], aligned_edge=LEFT)
            cells = VGroup(*[Square(side_length=0.36, stroke_width=0, fill_color=GREY_C,
                                    fill_opacity=0.55) for _ in range(n)])
            cells.arrange(RIGHT, buff=0.08).move_to([-1.1, y, 0], aligned_edge=LEFT)
            rows.add(VGroup(label, cmd, cells))
            boxes.append(cells)
        self.say("That is 27 files, run one at a time. The memory guard's own tests",
                 "run last, as a gate: 28 suites.")
        self.play(LaggedStart(*[FadeIn(r, shift=0.2 * RIGHT) for r in rows[:3]], lag_ratio=0.3),
                  run_time=1.5)
        self.play(FadeIn(rows[3], shift=0.2 * RIGHT), run_time=0.6)
        every = [c for cells in boxes for c in cells]
        self.play(LaggedStart(*[c.animate(rate_func=there_and_back).set_fill(WHITE, 1)
                                for c in every], lag_ratio=0.35), run_time=2.8)
        self.rest()

        self.say("Seventeen are pure test modules. Seven are runners that execute",
                 "the evaluator on synthetic fixtures. Three are Python.")
        for cells in boxes[:3]:
            self.play(Indicate(cells, color=WHITE, scale_factor=1.08), run_time=0.9)
            self.wait(0.4)
        self.rest()

        cols_e = ["case_id", "test_name", "expected_verdict", "expected_first_finding",
                  "expected_position"]
        cols_o = ["case_id", "test_name", "{w|observed_verdict}", "{w|observed_first_finding}",
                  "{w|observed_position}", "{w|observed_by}", "{w|commit}"]
        exp = titled("MATRIX.expected.tsv", "frozen", cols_e, -3.7, 1.75, size=18, w=4.7)
        obs = titled("MATRIX.tsv", "written by this run", cols_o, 3.7, 1.75, size=18, w=4.7)
        exp.card.align_to(obs.card, UP)
        y_no = exp.card.get_center()[1]
        no = DashedLine([exp.card.get_right()[0] + 0.2, y_no, 0],
                        [obs.card.get_left()[0] - 0.2, y_no, 0], color=GREY_B, stroke_width=3,
                        dash_length=0.12)
        no_x = cross(RED, 0.3).move_to(no)
        no_l = T("nothing copied", size=16, color=GREY_A).next_to(no, DOWN, buff=0.28)
        self.say("It writes what it saw to a second file: the case, the test,",
                 "and observed fields only. Nothing is copied from the first.")
        self.play(FadeOut(rows), run_time=0.5)
        self.play(FadeIn(exp, shift=0.2 * UP), FadeIn(obs, shift=0.2 * UP), run_time=0.8)
        self.play(Create(no), run_time=0.5)
        self.play(Create(no_x), FadeIn(no_l), run_time=0.5)
        self.rest()

        self.say("It is slow. The Makefile says twenty-five to forty minutes;",
                 "this run, with its candidates refused early, took fourteen.")
        facts = VGroup(pill("28 suites, in sequence", GREY_B, size=16, text_color=WHITE),
                       pill("821 s at 59d5cbb9", GREY_B, size=16, text_color=WHITE),
                       pill("candidate runs go through a memory guard: refused at 12 GiB in use",
                            GREY_B, size=16, text_color=WHITE))
        facts.arrange(RIGHT, buff=0.25).move_to([0, -2.1, 0])
        self.play(LaggedStart(*[FadeIn(f, shift=0.15 * UP) for f in facts], lag_ratio=0.4),
                  run_time=1.4)
        self.rest(0.6)
        self.end()


class S4_Join(Explainer):
    """The join on case_id, one row per satisfied status, then the rest and the exit rule."""

    def construct(self):
        self.header("The join", "expected against observed, on the case id")
        self.source("scripts/eval/candidate.py:1584–1595 (join_row), :1715–1723 (exit)  ·  "
                    "rows: MATRIX.expected.tsv and the MATRIX.tsv of the run at 59d5cbb9")
        cases = [("M14.ProjectionDiffers", "diverged  K2:ProjectionDiffers  interaction:14",
                  "record", "diverged  K2:ProjectionDiffers  interaction:14", "equal"),
                 ("M6.D.gen", "pass  -  aggregate:digests",
                  "assertion", "pass  (asserted)  (asserted)", "credited"),
                 ("M15.EmptySegment", "inapplicable  reason: no evaluated call exists  -",
                  "reason", "inapplicable  (no test)  -", "inapplicable")]
        xl, xr, w, h = -4.1, 4.1, 5.7, 3.6
        ys = [1.5, 0.55, -0.4]

        def panel(x, name, sub):
            bg = RoundedRectangle(width=w, height=h, corner_radius=0.14, stroke_color=GREY_D,
                                  stroke_width=2, fill_color=PANEL, fill_opacity=1)
            bg.move_to([x, 0.95, 0])
            head = VGroup(T("{c|" + name + "}", size=18), T(sub, size=15, color=GREY_B))
            head.arrange(RIGHT, buff=0.22).move_to([x, 2.4, 0])
            return VGroup(bg, head)

        left = panel(xl, "MATRIX.expected.tsv", "frozen")
        right = panel(xr, "MATRIX.tsv", "this run")
        ids, exps, bys, obss, links, pills = [], [], [], [], [], []
        for (cid, exp, by, obs, status), y in zip(cases, ys):
            edge_l, edge_r = xl - w / 2 + 0.3, xr - w / 2 + 0.3
            ids.append(T("{c|" + cid + "}", size=18).move_to([edge_l, y + 0.2, 0],
                                                             aligned_edge=LEFT))
            exps.append(T("{c|" + exp + "}", size=14, color=GREY_A)
                        .move_to([edge_l, y - 0.18, 0], aligned_edge=LEFT))
            bys.append(T("{c|observed_by: " + by + "}", size=14, color=GREY_B)
                       .move_to([edge_r, y + 0.2, 0], aligned_edge=LEFT))
            obss.append(T("{c|" + obs + "}", size=14, color=GREY_A)
                        .move_to([edge_r, y - 0.18, 0], aligned_edge=LEFT))
            tag = pill(status, STATUS[status], size=16, text_color=WHITE).move_to([0, y, 0])
            pills.append(tag)
            links.append(VGroup(Line([xl + w / 2 + 0.08, y, 0], tag.get_left() + LEFT * 0.06,
                                     stroke_width=2, color=GREY_C),
                                Line(tag.get_right() + RIGHT * 0.06, [xr - w / 2 - 0.08, y, 0],
                                     stroke_width=2, color=GREY_C)))

        self.say("Now the two files are joined on the {c|case_id}, row by row.")
        self.play(FadeIn(left, shift=0.2 * RIGHT), FadeIn(right, shift=0.2 * LEFT), run_time=0.8)
        self.play(LaggedStart(*[FadeIn(i, shift=0.15 * RIGHT) for i in ids], lag_ratio=0.3),
                  run_time=1.1)
        self.rest()

        def show(k):
            self.play(FadeIn(exps[k]), run_time=0.4)
            self.play(FadeIn(bys[k]), FadeIn(obss[k]), run_time=0.5)
            self.play(Create(links[k]), FadeIn(pills[k], scale=0.8), run_time=0.7)

        self.say("Where the suite printed the evaluator's verdict, all three fields",
                 "must match. The row is {e|equal}.")
        show(0)
        self.rest()

        self.say("Where a test only passes or fails, there is nothing to compare.",
                 "A pass {k|credits} the row.")
        show(1)
        self.rest()

        self.say("Eleven rows have no test. Each carries a written reason",
                 "and is {n|inapplicable}.")
        show(2)
        self.rest()

        self.say("Anything else leaves a row unsatisfied: a {f|mismatch}, a {f|failed} test,",
                 "or one that was {x|skipped} or {x|missing}.")
        lead = T("not satisfied", size=17, color=GREY_A)
        bad = VGroup(lead, *[pill(s, STATUS[s], size=16, text_color=WHITE)
                             for s in ["mismatch", "failed", "skipped", "missing"]])
        bad.arrange(RIGHT, buff=0.22).move_to([0, -1.42, 0])
        self.play(FadeIn(lead), LaggedStart(*[FadeIn(b, shift=0.15 * UP) for b in bad[1:]],
                                            lag_ratio=0.3), run_time=1.4)
        self.rest()

        self.say("The command exits zero only when every row is satisfied",
                 "and every suite exited zero.")
        rule = T("exit 0:  every row {e|equal}, {k|credited} or {n|inapplicable},  "
                 "and every suite exit 0", size=18, color=GREY_A).move_to([0, -2.08, 0])
        self.play(FadeIn(rule, shift=0.1 * UP), run_time=0.6)
        self.play(*[Indicate(p, color=WHITE, scale_factor=1.1) for p in pills], run_time=1.0)
        self.rest(0.6)
        self.end()


class S5_Tiers(Explainer):
    """The two observation tiers, and how many rows each carried on a clean run."""

    def construct(self):
        self.header("Two tiers", "what the matrix compared, and what it took on a test's word")
        self.source("candidate.py:116–134  ·  the printed line: matrix-logs/"
                    "candidate_checks_live_test.ail.log at 59d5cbb9  ·  185, 425, 11: "
                    "PLAN-004 §6, P1R R1")
        xl, xr, w = -3.55, 3.55, 6.7

        def step(x, y, words, sample=None):
            text = T(words, size=18, color=GREY_A)
            body = VGroup(text) if sample is None else VGroup(
                text, T("{c|" + sample + "}", size=14, color=WHITE)).arrange(DOWN, buff=0.1)
            bg = RoundedRectangle(width=w, height=body.height + 0.32, corner_radius=0.1,
                                  stroke_color=GREY_D, stroke_width=1.5, fill_color=PANEL,
                                  fill_opacity=1)
            return VGroup(bg, body).move_to([x, y, 0])

        def column(x, name, color, steps, good, bad):
            head = pill(name, color, size=20, text_color=WHITE).move_to([x, 2.72, 0])
            boxes = VGroup(step(x, 1.83, *steps[0]), step(x, 0.83, steps[1]),
                           step(x, 0.05, steps[2]))
            downs = VGroup(*[arrow(boxes[i].get_bottom(), boxes[i + 1].get_top(), color=GREY_C,
                                   width=2.5, tip=0.1, buff=0.03) for i in range(2)])
            ends = VGroup(VGroup(check(STATUS[good], 0.22, 5),
                                 pill(good, STATUS[good], size=16, text_color=WHITE))
                          .arrange(RIGHT, buff=0.14),
                          VGroup(cross(STATUS[bad], 0.2, 5),
                                 pill(bad, STATUS[bad], size=16, text_color=WHITE))
                          .arrange(RIGHT, buff=0.14))
            ends.arrange(RIGHT, buff=0.7).move_to([x, -0.66, 0])
            return head, boxes, downs, ends

        rec = column(xl, "record tier", C_EQ,
                     [("a suite prints the evaluator's verdict", PRINTED),
                      "the matrix parses it into the three fields",
                      "and compares each with the expected row"], "equal", "mismatch")
        asr = column(xr, "assertion tier", C_CR,
                     [("a test compares the three fields itself", '"status": "pass"'),
                      "the suite reports only pass or fail",
                      "the matrix writes (asserted) for what it never saw"],
                     "credited", "failed")

        def build(col):
            head, boxes, downs, ends = col
            self.play(FadeIn(head, shift=0.15 * DOWN), run_time=0.5)
            self.play(FadeIn(boxes[0], shift=0.15 * DOWN), run_time=0.6)
            self.play(GrowArrow(downs[0]), FadeIn(boxes[1], shift=0.15 * DOWN), run_time=0.6)
            self.play(GrowArrow(downs[1]), FadeIn(boxes[2], shift=0.15 * DOWN), run_time=0.6)
            self.play(FadeIn(ends, shift=0.15 * DOWN), run_time=0.6)

        self.say("Those are two tiers of observation. In the {e|record} tier",
                 "the matrix reads the evaluator's verdict and compares it itself.")
        build(rec)
        self.rest()

        self.say("In the {k|assertion} tier the comparison is inside the test.",
                 "The matrix learns only that the test passed.")
        build(asr)
        self.rest()

        left, width, y = -4.6, 9.2, -1.8
        bar = stack(CLEAN, left, y, width)
        when = T("{c|d74079d}  ·  17 September  ·  exit 0, 28 of 28 suites", size=15,
                 color=GREY_B)
        when.move_to([left, y - 0.42, 0], aligned_edge=LEFT)
        names = VGroup(*[T("{w|%d} %s" % (n, key), size=17, color=GREY_A) for key, n in CLEAN])
        for name, seg in zip(names[:2], bar[:2]):
            name.next_to(seg, UP, buff=0.1)
        names[2].next_to(bar[2], RIGHT, buff=0.18)
        self.say("A clean run, recorded in the plan in September:",
                 "{e|185} equal, {k|425} credited, {n|11} inapplicable.")
        self.play(LaggedStart(*[GrowFromEdge(seg, LEFT) for seg in bar], lag_ratio=0.5),
                  run_time=1.6)
        self.play(FadeIn(names), FadeIn(when), run_time=0.6)
        self.rest()

        self.say("Two rows in three are credited, not compared. The plan calls that",
                 "a design point: seventeen modules would have to return their answers.")
        self.play(Indicate(bar[1], color=WHITE, scale_factor=1.04), run_time=1.0)
        self.rest(0.6)
        self.end()


class S6_Red(Explainer):
    """A red matrix at HEAD, why it is red, and why it is read as a difference."""

    def construct(self):
        self.header("A red matrix", "at this commit it is read as a difference, not a verdict")
        self.source("PLAN-004 §6 (d74079d)  ·  plan-011-baseline-2026-10-06/matrix-logs at "
                    "59d5cbb9  ·  011 spike note Part 6, results/part6-compare.txt, "
                    "part6-known-bad.txt")
        left, width = -3.7, 7.6

        def run(y, commit, when, counts, code_, suites):
            name = VGroup(T("{c|" + commit + "}", size=17), T(when, size=14, color=GREY_B))
            name.arrange(DOWN, buff=0.04, aligned_edge=LEFT)
            name.move_to([-6.85, y - 0.12, 0], aligned_edge=LEFT)
            bar = stack(counts, left, y, width)
            words = tally(counts).move_to([left, y - 0.4, 0], aligned_edge=LEFT)
            out = VGroup(T(code_, size=18), T(suites, size=14, color=GREY_B))
            out.arrange(DOWN, buff=0.04, aligned_edge=LEFT)
            out.move_to([left + width + 0.3, y - 0.12, 0], aligned_edge=LEFT)
            return name, bar, words, out

        a = run(2.45, "d74079d", "17 Sep, the plan", CLEAN, "make: exit 0", "28 of 28 suites")
        b = run(1.3, "59d5cbb9", "6 Oct, main", TODAY, "make: exit 2", "25 of 28 suites")
        self.play(FadeIn(VGroup(*a), shift=0.15 * UP), run_time=0.7)

        self.say("At today's main the same command is red:",
                 "{f|29} rows failed, {x|33} missing, and three suites exit non-zero.")
        self.play(FadeIn(b[0]), LaggedStart(*[GrowFromEdge(seg, LEFT) for seg in b[1]],
                                            lag_ratio=0.4), run_time=1.6)
        self.play(FadeIn(b[2]), FadeIn(b[3]), run_time=0.6)
        self.rest()

        red = [("scripts/eval/test_candidate.py",
                "27 failed, 1 error: candidates refused, the protected manifest is stale"),
               ("tools/eval_protected/selftest.py",
                "its generator fails a parser cross-check: 33 rows missing"),
               ("src/eval/journal/candidate_checks.ail",
                "1 pure test fails: effect FS requires a capability")]
        suites = VGroup()
        for i, (name, why) in enumerate(red):
            y = -0.05 - i * 0.74
            mark = cross(C_BAD, 0.18, 4).move_to([-6.7, y, 0])
            file_ = T("{c|" + name + "}", size=17).move_to([-6.4, y + 0.15, 0], aligned_edge=LEFT)
            text = T(why, size=16, color=GREY_B).move_to([-6.4, y - 0.17, 0], aligned_edge=LEFT)
            suites.add(VGroup(mark, file_, text))
        self.say("None of the three is news. A pinned manifest has gone stale,",
                 "a generator cross-check fails, and one test lacks a capability.")
        self.play(LaggedStart(*[FadeIn(s, shift=0.15 * RIGHT) for s in suites], lag_ratio=0.45),
                  run_time=1.8)
        self.rest()

        self.say("So at this commit a red matrix is no verdict on a change.",
                 "Like {c|make dst}, it has to be compared with a baseline.")
        self.rest()

        diff = titled("part6-compare.txt", "at 259265b5: unchanged, then changed",
                      ["suites: 28 and 28; rows: 621 and 621",
                       "suites whose exit code differs: {w|0}",
                       "rows whose observation differs: {w|0}",
                       "rows whose join status differs: {w|0}"], -3.6, 0.2, size=16)
        self.say("Run it on the unchanged tree, then with the change, and compare.",
                 "In the 011 spike no suite and no row differed.")
        self.play(FadeOut(suites), run_time=0.4)
        self.play(FadeIn(diff, shift=0.2 * UP), run_time=0.7)
        self.rest()

        bad = titled("part6-known-bad.txt", "a wrong change, on purpose",
                     ["witness_live_test {w|rc=1}", "candidate_checks_live_test {w|rc=1}"],
                     3.6, 0.2, size=16)
        self.say("A deliberately wrong change did turn two runners red,",
                 "so a difference of zero means something.")
        self.play(FadeIn(bad, shift=0.2 * UP), run_time=0.7)
        self.rest(0.6)
        self.end()


class S7_Not(Explainer):
    """What the matrix is not, and what it is for."""

    def construct(self):
        self.header("What it is not", "and what that leaves it for")
        self.source("Makefile:507–518  ·  .github/workflows/  ·  gen_fixtures.py, PLAN-004 "
                    "§0.6, §3  ·  621, 28: MATRIX.expected.tsv, suites.json  ·  011 note, Part 6")
        items = [("not part of {c|make dst}", "{c|DST_TARGETS} does not list it"),
                 ("not run by CI", "two workflows, {c|dst-corpora.yml} and "
                                   "{c|verify-extensions.yml}; neither names it"),
                 ("not a run on a real session", "synthetic fixtures only, their digests from "
                                                 "{c|gen_fixtures.py}, an independent generator"),
                 ("not an evaluation", "it scores no change; it tests the evaluator's answers "
                                       "on known cases")]
        rows = VGroup()
        for i, (what, sub) in enumerate(items):
            y = 2.45 - i * 0.98
            mark = cross(GREY_B, 0.22, 5).move_to([-6.3, y, 0])
            text = T(what, size=26).move_to([-5.85, y, 0], aligned_edge=LEFT)
            note = T(sub, size=17, color=GREY_B).move_to([-5.85, y - 0.38, 0], aligned_edge=LEFT)
            rows.add(VGroup(mark, text, note))

        self.say("What the matrix is not. It is not part of {c|make dst},",
                 "and no CI workflow runs it.")
        self.play(LaggedStart(*[FadeIn(r, shift=0.2 * RIGHT) for r in rows[:2]], lag_ratio=0.5),
                  run_time=1.6)
        self.rest()

        self.say("It reads no real session. Its fixtures are synthetic,",
                 "and their digests come from an independent generator.")
        self.play(FadeIn(rows[2], shift=0.2 * RIGHT), run_time=0.7)
        self.rest()

        self.say("It scores no change. It gated the evaluator's build, and now",
                 "it is a control: did a change move any answer?")
        self.play(FadeIn(rows[3], shift=0.2 * RIGHT), run_time=0.7)
        self.rest()

        self.say("One table of answers, one run of observations, one join.",
                 "At today's main, read the difference.")
        recap = VGroup(pill("621 expected answers", WHITE, size=18, fill=0.06),
                       pill("28 suites, observed", WHITE, size=18, fill=0.06),
                       pill("one status per row", WHITE, size=18, fill=0.06))
        recap.arrange(RIGHT, buff=0.9).move_to([0, -1.85, 0])
        joins = VGroup(*[arrow(recap[i].get_right(), recap[i + 1].get_left(), color=GREY_A,
                               width=3, tip=0.16) for i in range(2)])
        self.play(FadeIn(recap[0], shift=0.15 * UP), run_time=0.5)
        self.play(GrowArrow(joins[0]), FadeIn(recap[1], shift=0.15 * UP), run_time=0.6)
        self.play(GrowArrow(joins[1]), FadeIn(recap[2], shift=0.15 * UP), run_time=0.6)
        self.rest(0.8)

        self.play(*[FadeOut(m) for m in self.mobjects], run_time=0.7)
        self.cap = None
        end = VGroup(T("013 · PLAN-004 §3", size=26, color=BLUE),
                     T("{c|make eval_matrix}", size=46),
                     T("{c|.agent/projects/013_core_architecture_for_dst/}", size=18,
                       color=GREY_B))
        end.arrange(DOWN, buff=0.35)
        self.play(FadeIn(end, shift=0.2 * UP), run_time=0.9)
        self.wait(2.4)
        self.play(FadeOut(end), run_time=0.8)
        self.wait(0.3)
