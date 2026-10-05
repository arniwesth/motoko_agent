"""034 ADR-001 explainer: the capabilities the ADR would enable.

A film for tools/explainer: one Explainer scene per beat, each caption also spoken. Render with
`tools/explainer/explainer render explainer.py`. Every claim on screen is the ADR's or the
scoping note's; README.md lists them with sources.
"""

from manim import *

from explainer_kit import *

OUTPUT = "effect-disclosure-explainer.mp4"

# Captions are written to be read; these make them sayable.
SAY = [
    (r"exit_code: 1", "exit code one"),
    (r"\bSpawnFailed\b", "spawn failed"),
    (r"65,536", "sixty-five thousand five hundred and thirty-six"),
    (r"\b12 of 12\b", "twelve of twelve"),
    (r"\bcode 124\b", "code one twenty-four"),
    (r"\bexited 0\b", "exited zero"),
    (r"\bP1\b", "P one"),
    (r"\bP2\b", "P two"),
    (r"\bP3\b", "P three"),
    (r"\bHEAD\b", "head"),
]

# Colour is meaning, and the kit's inline letters follow it: g none, y unknown, t the world.
C_NONE = GREEN  # effects: none
C_UNK = YELLOW  # effects: unknown
C_WORLD = TEAL  # what only the world knows
C_HARNESS = BLUE
C_AGENT = PURPLE
C_BAD = RED
K = 4  # the kit's text scale, for the one stamp set outside T()


class S1_Hook(Explainer):
    """The motivating failure: a write that landed, reported as failed, and retried."""

    def construct(self):
        title = T("Did it happen?", size=80)
        sub = T("Effect disclosure for tool faults", size=34, color=BLUE)
        tag = T("034 · ADR-001 · proposed", size=22, color=GREY_B)
        VGroup(title, sub, tag).arrange(DOWN, buff=0.4).move_to(UP * 0.3)
        self.speak("Did it happen?")
        self.play(Write(title), run_time=1.8)
        self.hush(0.1)
        self.speak("Effect disclosure for tool faults.")
        self.play(FadeIn(sub, shift=0.2 * UP), run_time=0.7)
        self.play(FadeIn(tag), run_time=0.5)
        self.wait(1.4)
        self.hush()
        self.play(FadeOut(VGroup(title, sub, tag), shift=0.4 * UP), run_time=0.7)

        agent = node("agent", C_AGENT, w=2.2).move_to([-5.6, 0.75, 0])
        tool = node("refund tool", C_HARNESS, w=2.8).move_to([-0.3, 0.75, 0])
        world = RoundedRectangle(width=3.9, height=3.4, corner_radius=0.18, stroke_color=C_WORLD,
                                 stroke_width=3, fill_color=C_WORLD, fill_opacity=0.07)
        world.move_to([4.75, 0.2, 0])
        wtitle = T("the world", size=24, color=C_WORLD).next_to(world.get_top(), DOWN, buff=0.18)
        wsub = T("refunds issued", size=18, color=GREY_B).next_to(wtitle, DOWN, buff=0.02)
        rule = Line(world.get_left() + RIGHT * 0.3, world.get_right() + LEFT * 0.3,
                    stroke_width=1.5, color=GREY_D).next_to(wsub, DOWN, buff=0.12)
        self.play(LaggedStart(FadeIn(agent, shift=0.2 * UP), FadeIn(tool, shift=0.2 * UP),
                              FadeIn(VGroup(world, wtitle, wsub, rule), shift=0.2 * UP),
                              lag_ratio=0.25), run_time=1.3)

        self.say("An agent asks a tool to issue a refund.")
        a1 = arrow(agent.get_right() + UP * 0.22, tool.get_left() + UP * 0.22)
        l1 = T("{c|refund(order 7, $40)}", size=18).next_to(a1, UP, buff=0.12)
        self.play(GrowArrow(a1), FadeIn(l1, shift=0.1 * UP), run_time=0.9)
        w1 = arrow(tool.get_right(), [world.get_left()[0], 0.75, 0], color=C_WORLD)
        row1 = T("{c|-$40   order 7}", size=22).move_to([4.55, 0.4, 0])
        ck1 = check(C_WORLD, 0.24).next_to(row1, RIGHT, buff=0.22)
        self.play(GrowArrow(w1), run_time=0.6)
        self.play(FadeIn(row1, shift=0.15 * RIGHT), Create(ck1), run_time=0.7)
        self.rest()

        self.say("The write lands. Then the tool reports that it {r|failed}.")
        a2 = arrow(tool.get_left() + DOWN * 0.22, agent.get_right() + DOWN * 0.22, color=C_BAD)
        l2 = T("{cr|error: failed}", size=18).next_to(a2, DOWN, buff=0.12)
        self.play(GrowArrow(a2), FadeIn(l2, shift=0.1 * DOWN), run_time=0.9)
        self.rest()

        self.say("So the agent retries, and the refund is paid {r|twice}.")
        a3 = CurvedArrow(agent.get_bottom() + RIGHT * 0.3, tool.get_bottom() + LEFT * 0.4,
                         angle=1.2, color=GOLD, stroke_width=4, tip_length=0.2)
        l3 = T("{o|retry:} {co|refund(order 7, $40)}", size=18).next_to(a3, DOWN, buff=0.1)
        self.play(Create(a3), FadeIn(l3, shift=0.1 * DOWN), run_time=1.0)
        row2 = T("{c|-$40   order 7}", size=22).next_to(row1, DOWN, buff=0.12)
        ck2 = check(C_WORLD, 0.24).next_to(row2, RIGHT, buff=0.22)
        self.play(FadeIn(row2, shift=0.15 * RIGHT), Create(ck2), run_time=0.7)
        rule2 = rule.copy().next_to(row2, DOWN, buff=0.16)
        total = T("{cr|-$80   total}", size=22).next_to(rule2, DOWN, buff=0.14)
        total.align_to(row2, LEFT)
        self.play(Create(rule2), FadeIn(total), run_time=0.6)
        self.play(Circumscribe(total, color=RED, buff=0.12), run_time=1.0)
        self.rest()

        self.say("{o|Havoc} measured this fault on a live model:",
                 "destructive in {r|12 of 12} runs.")
        self.rest()
        self.say("The agent was not careless. Nothing that reached it",
                 "told the two cases apart.")
        self.rest(0.6)
        self.end()


class S2_Today(Explainer):
    """Probe cases A and B: two different worlds, one typed signal."""

    def construct(self):
        self.header("Motoko today", "two different worlds, one typed signal")
        self.source("ADR §0, probe cases A and B  ·  what the model is told is read from "
                    "tool_runtime.ail:920–930 and :1012–1019, not run")
        xl, xr, w = -3.5, 3.5, 6.4
        self.say("Here is the same ambiguity in Motoko, with nothing injected.")
        tl = card(["{m|$} definitely-not-a-command-034"], size=19, w=w, h=1.2)
        tr = card(["{m|$} echo DONE; touch m_fg;", "  (sleep 9; touch m_bg) & exit 0"], size=19,
                  w=w, h=1.2)
        tl.move_to([xl, 2.4, 0])
        tr.move_to([xr, 2.4, 0])
        self.play(FadeIn(tl, shift=0.2 * UP), FadeIn(tr, shift=0.2 * UP), run_time=0.8)
        self.rest()

        self.say("One command never started.", "The other exited 0, with its work done.")
        gl = pill("nothing ran", C_NONE, size=19).next_to(tl, DOWN, buff=0.16)
        gr = pill("exited 0 · m_fg is on disk", C_WORLD, size=19).next_to(tr, DOWN, buff=0.16)
        self.play(FadeIn(gl, shift=0.1 * DOWN), run_time=0.5)
        self.wait(0.7)
        self.play(FadeIn(gr, shift=0.1 * DOWN), run_time=0.5)
        self.rest()

        el = T("{c|Err(NotFound(...))}", size=20, color=GREY_A).move_to([xl, 0.62, 0])
        er = T('{c|Err(SpawnFailed("...WaitDelay expired..."))}', size=20, color=GREY_A)
        er.move_to([xr, 0.62, 0])
        dl = arrow(gl.get_bottom(), el.get_top(), color=GREY_B, width=3, buff=0.06, tip=0.15)
        dr = arrow(gr.get_bottom(), er.get_top(), color=GREY_B, width=3, buff=0.06, tip=0.15)
        ret = T("exec returned", size=16, color=GREY_B).move_to([-0.95, 0.62, 0])
        self.play(GrowArrow(dl), GrowArrow(dr), FadeIn(el), FadeIn(er), FadeIn(ret), run_time=0.9)

        self.say("Both come back as {c|exit_code: 1}, with an empty {c|stdout}.")
        cl = card(["exit_code: {y|1}", 'stdout:    {y|""}', 'stderr:    "not found: ..."'],
                  size=19, w=w, h=2.0)
        cr = card(["exit_code: {y|1}", 'stdout:    {y|""}',
                   'stderr:    "spawn failed: exec: WaitDelay', '   expired before I/O complete"'],
                  size=19, w=w, h=2.0)
        cl.move_to([xl, -1.1, 0])
        cr.move_to([xr, -1.1, 0])
        dl2 = arrow(el.get_bottom(), cl.get_top(), color=GREY_B, width=3, buff=0.06, tip=0.15)
        dr2 = arrow(er.get_bottom(), cr.get_top(), color=GREY_B, width=3, buff=0.06, tip=0.15)
        self.play(GrowArrow(dl2), GrowArrow(dr2), FadeIn(cl, shift=0.15 * DOWN),
                  FadeIn(cr, shift=0.15 * DOWN), run_time=0.9)
        bl = SurroundingRectangle(VGroup(cl.lines[0], cl.lines[1]), color=YELLOW, buff=0.09,
                                  stroke_width=2.5, corner_radius=0.06)
        br = SurroundingRectangle(VGroup(cr.lines[0], cr.lines[1]), color=YELLOW, buff=0.09,
                                  stroke_width=2.5, corner_radius=0.06)
        eq = T("=", size=44, color=YELLOW).move_to([0, bl.get_center()[1], 0])
        self.play(Create(bl), Create(br), run_time=0.7)
        self.play(FadeIn(eq, scale=1.4), run_time=0.4)
        self.rest()

        self.say("Only the {c|stderr} prose differs, and no property can check prose.")
        sl = SurroundingRectangle(VGroup(cl.lines[2]), color=GREY_B, buff=0.09, stroke_width=2,
                                  corner_radius=0.06)
        sr = SurroundingRectangle(VGroup(cr.lines[2], cr.lines[3]), color=GREY_B, buff=0.09,
                                  stroke_width=2, corner_radius=0.06)
        differ = neq(GREY_A).move_to([0, sl.get_center()[1], 0])
        self.play(FadeOut(bl), FadeOut(br), FadeOut(eq), Create(sl), Create(sr), run_time=0.7)
        self.play(FadeIn(differ, scale=1.4), run_time=0.4)
        self.rest(0.6)
        self.end()


class S3_Line(Explainer):
    """D1 and D2: two values, split by whether the harness entered the effect."""

    def construct(self):
        self.header("The idea", "one line, and which side of it the fault was seen on")
        self.source("ADR D1, D2  ·  the note's Phase 0 lists SpawnFailed as never started; "
                    "the ADR's §5 records the change")
        y_axis, x_wall = -1.1, -0.3
        axis = Arrow([-6.7, y_axis, 0], [6.8, y_axis, 0], buff=0, stroke_width=3, color=GREY_A,
                     tip_length=0.2, max_tip_length_to_length_ratio=1)
        ticks = VGroup()
        for x, name in [(-5.5, "decode"), (-3.8, "policy"), (-2.1, "validate"),
                        (2.3, "write, exec"), (5.2, "result")]:
            mark = Line([x, y_axis - 0.09, 0], [x, y_axis + 0.09, 0], stroke_width=3, color=GREY_A)
            ticks.add(VGroup(mark, T(name, size=17, color=GREY_B).next_to(mark, DOWN, buff=0.06)))
        wall = DashedLine([x_wall, y_axis - 0.3, 0], [x_wall, 2.45, 0], color=WHITE,
                          stroke_width=3, dash_length=0.13)
        wall_label = T("the effect is entered", size=22).next_to(wall, UP, buff=0.06)

        self.say("The harness cannot see what the world did.",
                 "It can see whether it ever {b|entered} the effect.")
        self.play(GrowArrow(axis), run_time=0.9)
        self.play(LaggedStart(*[FadeIn(t, shift=0.1 * UP) for t in ticks], lag_ratio=0.15),
                  run_time=1.0)
        self.play(Create(wall), FadeIn(wall_label, shift=0.1 * DOWN), run_time=0.9)
        self.rest()

        xl, xr = -3.75, 3.3
        none_t = T("{c|none}", size=40, color=C_NONE).move_to([xl, 2.25, 0])
        none_d = T("the harness never entered the tool's effect", size=19, color=GREY_A)
        none_d.move_to([xl, 1.68, 0])
        unk_t = T("{c|unknown}", size=40, color=C_UNK).move_to([xr, 2.25, 0])
        unk_d = T("entered, and no completion it can report", size=19, color=GREY_A)
        unk_d.move_to([xr, 1.68, 0])
        self.say("Before that line, the effect never started: {cg|none}.",
                 "After it, the harness can only say {cy|unknown}.")
        self.play(FadeIn(none_t, shift=0.15 * UP), FadeIn(none_d), run_time=0.7)
        self.play(FadeIn(unk_t, shift=0.15 * UP), FadeIn(unk_d), run_time=0.7)
        self.rest()

        def row(names, color, x, y, dashed=False):
            chips = VGroup(*[pill(n, color, size=18, font=MONO if n[0].isupper() else SERIF,
                                  dashed=dashed) for n in names])
            return chips.arrange(RIGHT, buff=0.22).move_to([x, y, 0])

        ys = [0.98, 0.34, -0.3]
        left = [row(["arguments not valid JSON", "policy denial"], C_NONE, xl, ys[0]),
                row(["validation refusal", "a failed read or search"], C_NONE, xl, ys[1]),
                row(["NotFound", "SpawnFailed"], C_NONE, xl, ys[2])]
        right = [row(["the write was started", "Timeout"], C_UNK, xr, ys[0]),
                 row(["OutputLimitExceeded", "AbnormalExit"], C_UNK, xr, ys[1])]
        last = row(["SpawnFailed", "NotAllowed", "PermissionDenied"], C_UNK, xr + 0.02, ys[2])
        moved = left[2][1]
        self.say("{cg|none} only where the effect was provably not entered.",
                 "Everything else is {cy|unknown}, which is always sound.")
        self.play(LaggedStart(*[FadeIn(c, shift=0.25 * DOWN) for r in left for c in r],
                              lag_ratio=0.18), run_time=1.6)
        self.play(LaggedStart(*[FadeIn(c, shift=0.25 * DOWN) for r in right for c in r],
                              lag_ratio=0.18), run_time=1.3)
        self.rest()

        self.say("The scoping note had {c|SpawnFailed} on the left.",
                 "Case A, a command that exited 0, moved it.")
        self.play(Indicate(moved, color=WHITE, scale_factor=1.12), run_time=0.9)
        self.play(Transform(moved, last[0], path_arc=-0.9), run_time=1.4)
        self.rest()

        self.say("Two more arms are not yet established on the pinned binary.",
                 "They render {cy|unknown} until a probe or upstream says otherwise.")
        held = VGroup(*[pill(n, C_UNK, size=18, font=MONO, dashed=True).move_to(last[i + 1])
                        for i, n in enumerate(["NotAllowed", "PermissionDenied"])])
        self.play(LaggedStart(*[FadeIn(h, shift=0.25 * DOWN) for h in held], lag_ratio=0.3),
                  run_time=1.0)
        self.rest()

        self.say("There is no third value. Whether it {t|applied}",
                 "is something only the world knows.")
        third = T("a third value?   {ct|effects: applied}", size=24, color=GREY_A)
        third.move_to([0, -2.12, 0])
        strike = Line(third.get_left() + LEFT * 0.12, third.get_right() + RIGHT * 0.12,
                      color=RED, stroke_width=4)
        self.play(FadeIn(third, shift=0.1 * UP), run_time=0.6)
        self.wait(0.8)
        self.play(Create(strike), run_time=0.5)
        self.rest(0.6)
        self.end()


class S4_Read(Explainer):
    """D3, Phase 0: the fault object, and why it comes first."""

    def construct(self):
        self.header("Capability 1", "the model can read whether the effect started")
        self.source("ADR D3  ·  Phase 0, which ships on its own, first  ·  "
                    "cap_tool_message_content, phase_vocab.ail:1559–1568")
        lines = ['{ "tool": "BashExec", "cmd": "make build",',
                 '  "exit_code": 1,',
                 '  {y|"fault"}: { "kind": "output_limit",',
                 '             {y|"effects": "unknown"},',
                 '             "note": "..." },',
                 '  "stdout": "",',
                 '  "stderr": "output limit exceeded: 1000 bytes" }']
        full = code(lines, size=20)
        full.move_to([-3.05, 1.2, 0])
        lh = full[1][0].get_center()[1] - full[2][0].get_center()[1]
        pad = 0.32
        bg1 = RoundedRectangle(width=full.width + 2 * pad, height=full.height + 2 * pad,
                               corner_radius=0.14, stroke_color=GREY_D, stroke_width=2,
                               fill_color=PANEL, fill_opacity=1).move_to(full)
        bg0 = RoundedRectangle(width=bg1.width, height=bg1.height - 3 * lh, corner_radius=0.14,
                               stroke_color=GREY_D, stroke_width=2, fill_color=PANEL,
                               fill_opacity=1).align_to(bg1, UP).align_to(bg1, LEFT)
        tail = VGroup(full[5], full[6])
        tail.shift(UP * 3 * lh)

        self.say("Today a faulted result is an exit code and a line of prose.")
        self.play(FadeIn(bg0), FadeIn(VGroup(full[0], full[1], tail)), run_time=0.8)
        self.rest()

        self.say("With the ADR, every fault the harness reports", "carries one small object.")
        self.play(Transform(bg0, bg1), tail.animate.shift(DOWN * 3 * lh), run_time=0.8)
        self.play(LaggedStart(*[FadeIn(full[i], shift=0.2 * RIGHT) for i in (2, 3, 4)],
                              lag_ratio=0.35), run_time=1.3)
        notes = VGroup()
        x_note = bg1.get_right()[0] + 0.75
        for i, words in [(2, "the observation, never the world's truth"),
                         (3, "{cg|none} or {cy|unknown}"),
                         (4, "one fixed sentence per value")]:
            y = full[i][0].get_center()[1]
            text = T(words, size=19, color=GREY_A).move_to([x_note, y, 0], aligned_edge=LEFT)
            lead = Line([bg1.get_right()[0] + 0.1, y, 0], [x_note - 0.12, y, 0],
                        stroke_width=1.5, color=GREY_C)
            notes.add(VGroup(lead, text))
        self.play(LaggedStart(*[FadeIn(n, shift=0.15 * LEFT) for n in notes], lag_ratio=0.4),
                  run_time=1.6)
        eff = VGroup(*full[3])
        self.play(Indicate(eff, color=YELLOW, scale_factor=1.08), run_time=0.9)
        self.rest()

        self.say("It comes first, because a tool message keeps", "only its first 65,536 bytes.")
        y = -1.75
        kept = Rectangle(width=6.6, height=0.34, stroke_color=BLUE, stroke_width=2,
                         fill_color=BLUE, fill_opacity=0.3).move_to([-2.0, y, 0])
        lost = DashedVMobject(Rectangle(width=4.2, height=0.34, stroke_color=GREY_C,
                                        stroke_width=2), num_dashes=40)
        lost.next_to(kept, RIGHT, buff=0)
        mark = Rectangle(width=0.9, height=0.34, stroke_width=0, fill_color=YELLOW,
                         fill_opacity=0.9).align_to(kept, LEFT).align_to(kept, UP)
        mark_l = T("{c|fault}", size=16, color=YELLOW).next_to(mark, UP, buff=0.06)
        kept_l = T("kept: the first 65,536 bytes", size=17, color=BLUE)
        kept_l.next_to(kept, UP, buff=0.06).shift(RIGHT * 0.8)
        lost_l = T("cut", size=17, color=GREY_B).next_to(lost, UP, buff=0.06)
        self.play(FadeIn(kept), FadeIn(kept_l), Create(lost), FadeIn(lost_l), run_time=0.9)
        self.play(FadeIn(mark, shift=0.3 * RIGHT), FadeIn(mark_l), run_time=0.6)
        self.rest()

        strip = VGroup(kept, lost, mark, mark_l, kept_l, lost_l)
        self.say("What the model does next is still its own decision.",
                 "Now it has something to decide with.")
        agent = node("agent", C_AGENT, w=2.0, h=0.9).move_to([-4.6, -1.7, 0])
        got = pill("effects: unknown", C_UNK, size=18, font=MONO).move_to([-1.55, -1.7, 0])
        opts = VGroup(pill("retry?", GREY_B, size=19), pill("check first?", GREY_B, size=19))
        opts.arrange(RIGHT, buff=0.3).move_to([2.9, -1.7, 0])
        link = arrow(got.get_left(), agent.get_right(), color=C_UNK, width=3, tip=0.16)
        fork = arrow(got.get_right(), opts.get_left(), color=GREY_B, width=3, tip=0.16)
        self.play(FadeOut(strip), run_time=0.4)
        self.play(FadeIn(agent, shift=0.2 * UP), TransformFromCopy(eff, got), run_time=0.9)
        self.play(GrowArrow(link), run_time=0.5)
        self.play(GrowArrow(fork), FadeIn(opts, shift=0.2 * RIGHT), run_time=0.7)
        self.rest(0.6)
        self.end()


class S5_Partial(Explainer):
    """D6, Phase 0b: a deadline inside the runtime's wall keeps the partial output.

    Both sides run the note's case 3 command; the right side is case 5, the same command under
    coreutils `timeout -k 1 2`.
    """

    def construct(self):
        self.header("Capability 2", "partial output survives a deadline")
        self.source("note §6.1 cases 3 and 5, by direct exec probe  ·  ADR D6: Phase 0b needs "
                    "its own probe through run_process_result")
        xl, xr, w = -3.5, 3.5, 6.3

        def side(x, title, color, result):
            head = T(title, size=22, color=color).move_to([x, 2.72, 0])
            term = card(["{m|$} echo PARTIAL;", "  (sleep 8; touch m_late) & sleep 30",
                         "{w|PARTIAL}", result], size=19, w=w, h=2.15).move_to([x, 1.35, 0])
            track = Line([x - w / 2, 0.08, 0], [x + w / 2, 0.08, 0], stroke_width=6, color=GREY_E)
            fill = Line([x - w / 2, 0.08, 0], [x + w / 2, 0.08, 0], stroke_width=6, color=GOLD)
            label = T("deadline", size=15, color=GREY_B).next_to(track, DOWN, buff=0.03)
            label.align_to(track, LEFT)
            return head, term, track, fill, label

        hl, tl, kl, fl, ll = side(xl, "today", GREY_A, "{r|Err(Timeout(7005))}")
        hr, tr, kr, fr, lr = side(xr, "a deadline inside the wall: {c|timeout -k 1 2}", BLUE,
                                  "{g|Ok}, exit 124")
        for term in (tl, tr):
            term.lines[2].set_opacity(0)
            term.lines[3].set_opacity(0)

        self.say("Today, a deadline throws away everything the command printed.")
        self.play(FadeIn(VGroup(hl, tl, kl, ll), shift=0.2 * UP), run_time=0.7)
        self.play(tl.lines[2].animate.set_opacity(1), run_time=0.4)
        self.play(Create(fl), run_time=1.6, rate_func=linear)
        gone = Line(tl.lines[2].get_left() + LEFT * 0.08, tl.lines[2].get_right() + RIGHT * 0.08,
                    color=RED, stroke_width=3)
        nl = pill("its output is gone · the background write still lands", C_BAD, size=17)
        nl.move_to([xl, -0.85, 0])
        self.play(Flash(fl.get_end(), color=RED, flash_radius=0.3),
                  tl.lines[3].animate.set_opacity(1), tl.lines[2].animate.set_opacity(0.35),
                  Create(gone), run_time=0.7)
        self.play(FadeIn(nl, shift=0.1 * DOWN), run_time=0.5)
        self.rest()

        self.say("A deadline inside the runtime's wall becomes an ordinary exit:",
                 "code 124, with the output intact.")
        self.play(FadeIn(VGroup(hr, tr, kr, lr), shift=0.2 * UP), run_time=0.7)
        self.play(tr.lines[2].animate.set_opacity(1), run_time=0.4)
        self.play(Create(fr), run_time=1.6, rate_func=linear)
        keep = SurroundingRectangle(tr.lines[2], color=GREEN, buff=0.08, stroke_width=2.5,
                                    corner_radius=0.05)
        nr = pill("output intact · the kill reaches the process group", C_NONE, size=17)
        nr.move_to([xr, -0.85, 0])
        self.play(Flash(fr.get_end(), color=GOLD, flash_radius=0.3),
                  tr.lines[3].animate.set_opacity(1), Create(keep), run_time=0.7)
        self.play(FadeIn(nr, shift=0.1 * DOWN), run_time=0.5)
        self.rest()

        self.say("It narrows the ambiguity and does not close it.",
                 "The disclosure stays {cy|unknown}.")
        both = T("either way, the model is told", size=22, color=GREY_A)
        eff = pill("effects: unknown", C_UNK, size=20, font=MONO)
        VGroup(both, eff).arrange(RIGHT, buff=0.3).move_to([0, -1.9, 0])
        self.play(FadeIn(both), FadeIn(eff, scale=0.9), run_time=0.7)
        self.rest(0.6)
        self.end()


class S6_World(Explainer):
    """D4, Phase 1: the applied bit lives in the world and never crosses to the harness."""

    def construct(self):
        self.header("Capability 3", "the test world can hold the case the harness cannot see")
        self.source("ADR D4  ·  Phase 1  ·  fault-catalogue/2 has eleven rows; /3 would have "
                    "thirteen")
        x_wall = 1.0
        wall = DashedLine([x_wall, 2.5, 0], [x_wall, -2.3, 0], color=GREY_A, dash_length=0.13,
                          stroke_width=3)
        lw = T("the deterministic world", size=22, color=C_WORLD).move_to([-2.85, 2.72, 0])
        lh = T("the harness", size=22, color=C_HARNESS).move_to([4.1, 2.72, 0])

        def run(y, name, applied):
            box = RoundedRectangle(width=6.6, height=1.75, corner_radius=0.16,
                                   stroke_color=C_WORLD, stroke_width=2.5, fill_color=C_WORLD,
                                   fill_opacity=0.06).move_to([-2.85, y, 0])
            tag = T(name, size=17, color=GREY_B)
            tag.move_to(box.get_corner(UL) + RIGHT * 0.25 + DOWN * 0.27, aligned_edge=LEFT)
            bit = T("{c|applied:} " + ("{ct|yes}" if applied else "{cm|no}"), size=24)
            bit.move_to([-4.55, y - 0.18, 0])
            log = RoundedRectangle(width=2.5, height=0.8, corner_radius=0.1, stroke_color=GREY_C,
                                   stroke_width=1.5).move_to([-1.35, y - 0.25, 0])
            log_l = T("effect log", size=16, color=GREY_B).next_to(log, UP, buff=0.02)
            entry = pill("the update", C_WORLD, size=16).move_to(log)
            pkt = pill("ToolFailed, after dispatch", C_BAD, size=17, font=MONO)
            pkt.move_to([4.05, y + 0.32, 0])
            eff = pill("effects: unknown", C_UNK, size=17, font=MONO).move_to([4.05, y - 0.5, 0])
            send = arrow(box.get_right() + UP * 0.32, pkt.get_left(), color=C_BAD, width=3,
                         tip=0.16, buff=0.08)
            down = arrow(pkt.get_bottom(), eff.get_top(), color=GREY_B, width=3, tip=0.14,
                         buff=0.05)
            return VGroup(box, tag, bit, log, log_l), entry, pkt, eff, send, down

        a, _, pkt_a, eff_a, send_a, down_a = run(1.3, "run A", False)
        b, entry_b, pkt_b, eff_b, send_b, down_b = run(-1.1, "run B", True)

        self.say("In the deterministic test world, the script decides",
                 "what really happened.")
        self.play(Create(wall), FadeIn(lw), FadeIn(lh), run_time=0.8)
        self.play(FadeIn(a, shift=0.2 * RIGHT), FadeIn(b, shift=0.2 * RIGHT), run_time=0.8)
        self.rest()

        self.say("Two runs. In one the update {t|applied};", "in the other it did not.")
        self.play(FadeIn(entry_b, scale=0.6), run_time=0.6)
        self.play(Indicate(b[2], color=TEAL, scale_factor=1.12), run_time=0.9)
        self.rest()

        self.say("The same fault crosses to the harness in both.",
                 "The {t|applied} bit stays behind the wall.")
        self.play(GrowArrow(send_a), GrowArrow(send_b), run_time=0.7)
        self.play(FadeIn(pkt_a, shift=0.3 * RIGHT), FadeIn(pkt_b, shift=0.3 * RIGHT), run_time=0.6)
        self.play(GrowArrow(down_a), GrowArrow(down_b), FadeIn(eff_a), FadeIn(eff_b), run_time=0.7)
        eq = T("=", size=44, color=WHITE).rotate(PI / 2).move_to([4.05, 0.1, 0])
        same = T("identical", size=20, color=GREY_A).next_to(eq, RIGHT, buff=0.25)
        self.play(FadeIn(eq, scale=1.4), FadeIn(same), run_time=0.6)
        self.rest()

        runs = VGroup(wall, lw, lh, a, b, entry_b, pkt_a, pkt_b, eff_a, eff_b, send_a, send_b,
                      down_a, down_b, eq, same)
        self.say("Two new catalogue rows, each the twin of a wire row,",
                 "and never shown to the model.")
        self.play(FadeOut(runs), run_time=0.6)
        x_cat, top, step = -3.9, 2.05, 0.37
        bars = VGroup(*[RoundedRectangle(width=4.6, height=0.27, corner_radius=0.06,
                                         stroke_color=GREY_D, stroke_width=1.5, fill_color=GREY_E,
                                         fill_opacity=0.7).move_to([x_cat, top - i * step, 0])
                        for i in range(11)])
        names = {2: "ToolFailed", 4: "ToolDeadlineExceeded"}
        wire = VGroup()
        for i, name in names.items():
            bars[i].set_stroke(BLUE, 2).set_fill(BLUE, 0.2)
            wire.add(T("{c|" + name + "}", size=15).move_to(bars[i]))
        cat_t = T("fault catalogue", size=22).move_to([x_cat - 0.9, 2.65, 0])
        count0 = T("{c|/2}, 11 rows", size=20, color=GREY_A).next_to(cat_t, RIGHT, buff=0.3)
        count1 = T("{c|/3}, 13 rows", size=20, color=C_WORLD).move_to(count0, aligned_edge=LEFT)
        self.play(FadeIn(cat_t), FadeIn(count0),
                  LaggedStart(*[FadeIn(bar, shift=0.15 * RIGHT) for bar in bars], lag_ratio=0.06),
                  run_time=1.2)
        self.play(FadeIn(wire), run_time=0.5)
        twins, links = VGroup(), VGroup()
        for i, name in [(2, "tool_effect_applied_then_failed"),
                        (4, "tool_effect_applied_then_deadline")]:
            twin = pill(name, C_WORLD, size=15, font=MONO, dashed=True)
            twin.move_to([3.3, bars[i].get_center()[1], 0])
            twins.add(twin)
            links.add(DashedLine(bars[i].get_right(), twin.get_left(), color=C_WORLD,
                                 stroke_width=2.5, dash_length=0.09, buff=0.08))
        twin_l = T("twin", size=16, color=C_WORLD).next_to(links[0], UP, buff=0.04)
        self.play(LaggedStart(*[AnimationGroup(Create(links[i]), FadeIn(twins[i], shift=0.3 * LEFT))
                                for i in range(2)], lag_ratio=0.4), FadeIn(twin_l), run_time=1.5)
        self.play(Transform(count0, count1), run_time=0.6)
        only = pill("world-only · never on the wire", C_WORLD, size=19).move_to([3.3, -0.25, 0])
        same_c = T("each copies its twin's constructor and recovery branch", size=18,
                   color=GREY_A).move_to([3.3, -0.95, 0])
        self.play(FadeIn(only, shift=0.15 * UP), FadeIn(same_c), run_time=0.7)
        self.rest(0.6)
        self.end()


class S7_Props(Explainer):
    """§2, Phase 2: the three properties and the mutation each must be seen red on."""

    def construct(self):
        self.header("Capability 4", "three properties, each with a mutation that must go red")
        self.source("ADR §2  ·  Phase 2  ·  P3 holds trivially today: no retry path exists in "
                    "the driver")

        # P1: a 2x2 of what the model is told against what the world did
        title = T("{b|P1}   the disclosure is sound", size=28).move_to([0, 2.65, 0])
        cw, ch, x0, y0 = 3.1, 1.1, 0.1, 0.65
        cell = lambda i, j: np.array([x0 + j * cw, y0 - i * ch, 0])
        grid = VGroup(*[Rectangle(width=cw, height=ch, stroke_color=GREY_C, stroke_width=1.5)
                        .move_to(cell(i, j)) for i in range(2) for j in range(2)])
        col_t = T("what the world did", size=17, color=GREY_B).move_to([x0 + cw / 2, y0 + 1.25, 0])
        cols = VGroup(T("not applied", size=22, color=GREY_A).move_to(cell(0, 0) + UP * 0.8),
                      T("applied", size=22, color=C_WORLD).move_to(cell(0, 1) + UP * 0.8))
        row_t = T("what the model is told", size=17, color=GREY_B)
        row_t.move_to([x0 - cw / 2 - 1.75, y0 + 0.8, 0])
        rows = VGroup(T("{c|none}", size=26, color=C_NONE), T("{c|unknown}", size=26, color=C_UNK))
        for i, r in enumerate(rows):
            r.move_to(cell(i, 0) + LEFT * (cw / 2 + 0.25), aligned_edge=RIGHT)
        ok = VGroup(check(GREEN, 0.34).move_to(cell(0, 0)), check(GREEN, 0.34).move_to(cell(1, 0)),
                    check(GREEN, 0.34).move_to(cell(1, 1)))
        bad_fill = Rectangle(width=cw, height=ch, stroke_width=0, fill_color=RED,
                             fill_opacity=0.22).move_to(cell(0, 1))
        bad = VGroup(cross(RED, 0.34), T("unsound", size=19, color=RED)).arrange(RIGHT, buff=0.2)
        bad.move_to(cell(0, 1))
        rule = T("{cg|effects = none}   ⇒   the world did {t|not} apply it", size=24)
        rule.move_to([0, -1.85, 0])

        self.say("{b|P1.} If the harness says {cg|none},", "the world did not apply the update.")
        self.play(FadeIn(title, shift=0.1 * DOWN), Create(grid), FadeIn(col_t), FadeIn(cols),
                  FadeIn(row_t), FadeIn(rows), run_time=1.1)
        self.play(Create(ok[0]), run_time=0.4)
        self.play(FadeIn(bad_fill), FadeIn(bad, scale=1.2), run_time=0.6)
        self.play(FadeIn(rule, shift=0.1 * UP), run_time=0.5)
        self.rest()
        self.say("It is one-sided: {cy|unknown} is always allowed after dispatch.")
        self.play(LaggedStart(Create(ok[1]), Create(ok[2]), lag_ratio=0.4), run_time=0.8)
        self.rest()
        self.say("Its mutation: say {cg|none} after dispatch.", "The oracle must go {r|red}.")
        self.play(Indicate(bad_fill, color=RED, scale_factor=1.06),
                  Indicate(bad, color=RED, scale_factor=1.1), run_time=1.0)
        self.rest()
        p1 = VGroup(title, grid, col_t, cols, row_t, rows, ok, bad_fill, bad, rule)

        # P2: a pair of runs that differ in one bit
        title2 = T("{b|P2}   nothing leaks, nothing is invented", size=28).move_to([0, 2.65, 0])

        def strip(y):
            cells = VGroup(*[Square(side_length=0.46, stroke_color=BLUE, stroke_width=2,
                                    fill_color=BLUE, fill_opacity=0.35) for _ in range(12)])
            return cells.arrange(RIGHT, buff=0.1).move_to([1.6, y, 0])

        sa, sb = strip(1.3), strip(-0.1)
        la = T("run A   {c|applied:} {cm|no}", size=21).move_to([-4.6, 1.3, 0])
        lb = T("run B   {c|applied:} {ct|yes}", size=21).move_to([-4.6, -0.1, 0])
        tr_l = T("the trace the harness produces", size=17, color=GREY_B).next_to(sa, UP, buff=0.12)
        self.say("{b|P2.} Flip the {t|applied} bit in one run.",
                 "Nothing the harness produces may change.")
        self.play(FadeOut(p1), run_time=0.5)
        self.play(FadeIn(title2, shift=0.1 * DOWN), FadeIn(la), FadeIn(lb), FadeIn(tr_l),
                  LaggedStart(*[FadeIn(c, scale=0.6) for c in sa], lag_ratio=0.06),
                  LaggedStart(*[FadeIn(c, scale=0.6) for c in sb], lag_ratio=0.06), run_time=1.3)
        self.wait(0.5)
        self.play(sa.animate.move_to([1.6, 0.6, 0]), sb.animate.move_to([1.6, 0.6, 0]),
                  FadeOut(tr_l), run_time=1.0)
        frame = SurroundingRectangle(sa, color=GREEN, buff=0.1, stroke_width=3, corner_radius=0.08)
        same = VGroup(check(GREEN, 0.3), T("identical", size=21, color=GREEN))
        same.arrange(RIGHT, buff=0.18).next_to(frame, DOWN, buff=0.18)
        self.play(Create(frame), FadeIn(same, shift=0.1 * UP), run_time=0.7)
        self.rest()

        self.say("Its mutation: read the bit into the message.", "The pair must go {r|red}.")
        self.play(FadeOut(frame), FadeOut(same), sa.animate.move_to([1.6, 1.3, 0]),
                  sb.animate.move_to([1.6, -0.1, 0]), run_time=0.8)
        leak = CurvedArrow(lb.get_right() + RIGHT * 0.05 + DOWN * 0.12,
                           sb[7].get_bottom() + DOWN * 0.04, angle=0.9, color=RED,
                           stroke_width=3.5, tip_length=0.18)
        differ = neq(RED).move_to([1.6, 0.6, 0])
        self.play(Create(leak), run_time=0.8)
        self.play(sb[7].animate.set_fill(RED, 0.7).set_stroke(RED), run_time=0.4)
        self.play(FadeIn(differ, scale=1.4), run_time=0.4)
        self.rest()
        p2 = VGroup(title2, sa, sb, la, lb, leak, differ)

        # P3: one call id, dispatched once
        title3 = T("{b|P3}   no call is dispatched twice", size=28).move_to([0, 2.65, 0])
        driver = node("driver", C_HARNESS, w=2.3).move_to([-4.2, 1.0, 0])
        world = node("world", C_WORLD, w=2.3).move_to([2.2, 1.0, 0])
        log = RoundedRectangle(width=3.4, height=1.5, corner_radius=0.12, stroke_color=GREY_C,
                               stroke_width=1.5).move_to([2.2, -0.9, 0])
        log_l = T("what the world served", size=16, color=GREY_B).next_to(log, UP, buff=0.02)
        send = arrow(driver.get_right() + UP * 0.15, world.get_left() + UP * 0.15)
        send_l = T("{c|dispatch call_7}", size=18).next_to(send, UP, buff=0.1)
        e1 = pill("call_7", GREY_A, size=17, font=MONO).move_to(log.get_center() + UP * 0.33)
        once = VGroup(check(GREEN, 0.28), T("once", size=20, color=GREEN))
        once.arrange(RIGHT, buff=0.15).next_to(log, RIGHT, buff=0.35)
        self.say("{b|P3.} The driver never dispatches the same call twice.")
        self.play(FadeOut(p2), run_time=0.5)
        self.play(FadeIn(title3, shift=0.1 * DOWN), FadeIn(driver), FadeIn(world), FadeIn(log),
                  FadeIn(log_l), run_time=0.8)
        self.play(GrowArrow(send), FadeIn(send_l, shift=0.1 * UP), run_time=0.7)
        self.play(FadeIn(e1, shift=0.2 * DOWN), FadeIn(once), run_time=0.6)
        self.rest()

        self.say("That holds trivially today: no retry path exists.",
                 "So its mutation is its only evidence.")
        again = CurvedArrow(driver.get_bottom() + RIGHT * 0.2, world.get_bottom() + LEFT * 0.5,
                            angle=0.75, color=RED, stroke_width=3.5, tip_length=0.18)
        again_l = T("{r|retry on deadline}", size=18).next_to(again, DOWN, buff=0.08)
        e2 = pill("call_7", RED, size=17, font=MONO).move_to(log.get_center() + DOWN * 0.33)
        twice = VGroup(cross(RED, 0.28), T("twice", size=20, color=RED))
        twice.arrange(RIGHT, buff=0.15).move_to(once, aligned_edge=LEFT)
        self.play(Create(again), FadeIn(again_l), run_time=0.9)
        self.play(FadeIn(e2, shift=0.2 * DOWN), FadeOut(once), FadeIn(twice), run_time=0.6)
        self.rest()

        self.say("A property counts only after its mutation", "has been seen {r|red}.")
        self.rest(0.8)
        self.end()


class S8_Recap(Explainer):
    """§4: the phases in order, and the status of all of it."""

    def construct(self):
        self.header("What the ADR would enable", "in the order a plan would sequence it")
        self.source("ADR §4, §6  ·  .agent/projects/034_ambiguous_tool_outcomes/"
                    "ADR-001-effect-disclosure-for-tool-faults.md")
        items = [("Phase 0", C_HARNESS, "The model can read whether the effect started",
                  "ships on its own, first"),
                 ("Phase 0b", C_HARNESS, "Partial output survives a deadline",
                  "its own probe, its own baseline pass"),
                 ("Phase 1", C_WORLD,
                  "The test world can hold “applied, and the call still faulted”",
                  "two world-only catalogue rows"),
                 ("Phase 2", C_WORLD, "P1 sound  ·  P2 no leak  ·  P3 no re-dispatch",
                  "each seen red on its mutation first"),
                 ("Phase 3", C_WORLD, "A count of duplicate effect keys",
                  "a metric, not a verdict"),
                 ("upstream", PURPLE, "Four asks to AILANG, in parallel",
                  "filing waits for the ruling")]
        x_dot, top, step = -6.2, 2.5, 0.84
        spine = Line([x_dot, top, 0], [x_dot, top - 4 * step, 0], color=GREY_D, stroke_width=3)
        rows = VGroup()
        for i, (phase, color, what, sub) in enumerate(items):
            y = top - i * step
            dot = Dot([x_dot, y, 0], radius=0.09, color=color)
            name = T("{c|" + phase + "}", size=20, color=color)
            name.move_to([x_dot + 0.35, y, 0], aligned_edge=LEFT)
            text = T(what, size=24).move_to([x_dot + 2.0, y, 0], aligned_edge=LEFT)
            note = T(sub, size=17, color=GREY_B)
            note.move_to([x_dot + 2.0, y - 0.36, 0], aligned_edge=LEFT)
            rows.add(VGroup(dot, name, text, note))

        self.say("Five phases, in the order a plan would sequence them,",
                 "and four asks upstream alongside.")
        self.play(Create(spine), run_time=0.6)
        self.play(LaggedStart(*[FadeIn(r, shift=0.25 * RIGHT) for r in rows], lag_ratio=0.45),
                  run_time=4.2)
        self.rest()

        self.say("All of it is {o|proposed}. The operator has ruled on nothing,",
                 "and none of it exists at HEAD.")
        word = Text("PROPOSED", font=SERIF, weight=BOLD, font_size=46 * K, color=GOLD).scale(1 / K)
        box = RoundedRectangle(width=word.width + 0.7, height=word.height + 0.55,
                               corner_radius=0.12, stroke_color=GOLD, stroke_width=5)
        stamp = VGroup(box, word).rotate(0.16).move_to([4.1, -1.2, 0])
        self.play(FadeIn(stamp, scale=1.7), run_time=0.45)
        self.rest(0.8)

        self.play(*[FadeOut(m) for m in self.mobjects], run_time=0.7)
        self.cap = None
        end = VGroup(T("034 · ADR-001", size=26, color=BLUE),
                     T("Effect disclosure for tool faults", size=46),
                     T("{c|.agent/projects/034_ambiguous_tool_outcomes/}", size=18, color=GREY_B))
        end.arrange(DOWN, buff=0.35)
        self.play(FadeIn(end, shift=0.2 * UP), run_time=0.9)
        self.wait(2.6)
        self.play(FadeOut(end), run_time=0.8)
        self.wait(0.3)
