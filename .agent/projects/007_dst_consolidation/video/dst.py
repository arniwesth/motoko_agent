"""Motoko DST at 7a48869a: sources, scope and authoring notes in README.md.

Built from tools/explainer/examples/minimal.py. Diagrams are explanatory,
not captured executions. All narration stays literal for the tool's collector.
"""
from manim import *
from explainer_kit import *

OUTPUT = "motoko-dst-explainer.mp4"
SAY = [
    (r"\bDST\b", "D S T"),
    (r"\bMotoko\b", "Moh toh koh"),
    (r"\bLedgerTrace\b", "ledger trace"),
    (r"\bRunSummary\b", "run summary"),
    (r"\bSystemRun\b", "system run"),
    (r"\bHarnessFailure\b", "harness failure"),
    (r"\bdriver_only\b", "driver only"),
    (r"\bdriver_plus_compose\b", "driver plus compose"),
    (r"\bmake dst\b", "make D S T"),
]


def label(text, x, y, color=GREY_A, size=24):
    return T(text, size=size, color=color).move_to([x, y, 0])


def panel(title, lines, x, y, color=BLUE, w=5.8, h=2.2):
    box = RoundedRectangle(width=w, height=h, corner_radius=0.16,
                           stroke_color=color, stroke_width=2,
                           fill_color=color, fill_opacity=0.07)
    heading = T(title, size=26, color=color)
    body = VGroup(*[T(line, size=22) for line in lines]).arrange(DOWN, buff=0.18)
    VGroup(heading, body).arrange(DOWN, buff=0.26).move_to(box)
    return VGroup(box, heading, body).move_to([x, y, 0])


class S1_Idea(Explainer):
    def construct(self):
        self.header("Motoko DST", "keep the driver; control its world")
        self.source("007 ADR D1–D2 · m-motoko-dst-framework: definition, architecture · dst_driver_only.ail")
        status = pill("BUILT · generated axis · driver_only", GREEN, size=20).move_to([0, 2.65, 0])
        driver = node("real session driver", BLUE, w=4.0).move_to([-3.7, 0.8, 0])
        live = panel("Live environment", ["provider · tools · approvals", "time · environment"], 3.5, 0.8, GREY_B, w=5.0)
        link = arrow(driver.get_right(), live.get_left())
        self.say("Motoko runs its real session driver", "against a world the test can control.")
        self.play(FadeIn(status), FadeIn(driver), FadeIn(live), GrowArrow(link), run_time=1)
        self.rest(0.15)

        world = panel("Deterministic world", ["typed outcomes · logical faults", "explicit state · virtual time"], 3.5, 0.8, TEAL, w=5.0)
        self.say("The world stands in for the provider, tools and time.", "Production code still makes the decisions.")
        self.play(FadeOut(live), run_time=0.3)
        self.play(FadeIn(world), run_time=0.5)
        self.rest(0.15)

        chain = VGroup(*[pill(s, c, size=22) for s, c in
                        [("seed", PURPLE), ("execution", TEAL), ("trace", BLUE), ("invariants", YELLOW)]])
        chain.arrange(RIGHT, buff=0.5).move_to([0, -1.25, 0])
        self.say("Seeds explore executions; invariants judge traces.", "Recorded programs make failures replayable.")
        self.play(LaggedStart(*[FadeIn(m, shift=UP * 0.1) for m in chain], lag_ratio=0.2), run_time=1)
        self.rest(0.15)

        note = label("single actor · logical faults · coverage belongs to a profile", 0, -2.15, GREY_B, 22)
        self.say("This is single-actor, logical-fault testing.", "Coverage belongs to a named profile.")
        self.play(FadeIn(note), run_time=0.5)
        self.rest(0.15)
        self.end()


class S2_Boundary(Explainer):
    def construct(self):
        self.header("Built here", "the boundary is an explicit value")
        self.source("009 ADR D1, D4–D6 · dst_execution.ail: execution_of · ports.ail: WorldState / virtual_clock · session.ail")
        core = panel("Production code", ["session → step_machine", "model / tool / hook phases"], -3.6, 1.35, BLUE, w=5.5)
        world = panel("World state", ["generator or replay position", "clock · queues · environment"], 3.6, 1.35, TEAL, w=5.5)
        self.say("The driver runs the state machine and phases.", "Adapters supply external answers.")
        self.play(FadeIn(core), FadeIn(world), run_time=0.8)
        self.rest(0.15)

        rails = VGroup(Line(core.get_bottom(), [-3.6, -1.1, 0], color=GREY_D),
                       Line(world.get_bottom(), [3.6, -1.1, 0], color=GREY_D))
        req = arrow([-3.6, -0.3, 0], [3.6, -0.3, 0], color=BLUE)
        reqt = label("typed request", 0, 0.12, BLUE, 21)
        res = arrow([3.6, -1.1, 0], [-3.6, -1.1, 0], color=TEAL)
        restxt = label("response + successor state", 0, -1.52, TEAL, 21)
        self.say("Typed ports return a response", "and the successor world state.")
        self.play(Create(rails), GrowArrow(req), FadeIn(reqt), GrowArrow(res), FadeIn(restxt), run_time=0.9)
        self.rest(0.15)

        self.say("Here, a clock read returns world time, then adds one millisecond.", "The recorder logs that advance.")
        self.play(Circumscribe(world[2], color=TEAL), run_time=1)
        self.rest(0.15)

        ledger = pill("returned trace + emission witness → invariant checks", YELLOW, size=22).move_to([0, -2.2, 0])
        self.say("The bridge gives the invariant checker", "the returned trace and emission witness.")
        self.play(FadeIn(ledger), run_time=0.5)
        self.rest(0.15)
        self.end()


class S3_DiscoveryReplay(Explainer):
    def construct(self):
        self.header("Built here", "discover once; replay the exact program")
        self.source("dst_generator.ail · dst_program.ail · dst_replay.ail: compare / regression_fatal · 009 ADR D2, D8")
        d = node("real driver", BLUE, w=3).move_to([-4.7, 1.5, 0])
        g = node("seeded generator", PURPLE, w=3.6).move_to([0, 1.5, 0])
        p = node("exact program", TEAL, w=3).move_to([4.7, 1.5, 0])
        self.say("In discovery, the generator answers actual driver requests", "with seeded outcomes, faults and latency.")
        self.play(FadeIn(d), FadeIn(g), GrowArrow(arrow(d.get_right(), g.get_left())), run_time=0.8)
        self.rest(0.15)

        back = arrow([-1.6, 0.65, 0], [-4.4, 0.65, 0], color=PURPLE)
        btxt = label("answer changes the next request", -3.0, 0.15, GREY_A, 19)
        self.say("Answers shape the next request.", "The recorder preserves the interaction order.")
        self.play(GrowArrow(back), FadeIn(btxt), FadeIn(p), GrowArrow(arrow(g.get_right(), p.get_left(), color=TEAL)), run_time=0.9)
        self.rest(0.15)

        strict = panel("Strict replay", ["same identity + request projection", "same manifest and profile"], -3.4, -1.35, TEAL, w=6.0, h=1.9)
        self.say("Strict replay consumes the exact program.", "A seed alone is not the reproduction key.")
        self.play(FadeIn(strict), run_time=0.6)
        self.rest(0.15)

        reg = panel("Regression replay", ["record allowed differences", "reject unsafe request mismatches"], 3.4, -1.35, YELLOW, w=6.0, h=1.9)
        self.say("Regression replay can record changes after a fix.", "Wrong identities or unused interactions still fail.")
        self.play(FadeIn(reg), run_time=0.6)
        self.rest(0.15)
        self.end()


class S4_FaultsTime(Explainer):
    def construct(self):
        self.header("Built here", "faults arrive through the environment")
        self.source("dst_fault_catalogue.ail: required_class_ids / fault_catalogue / catalogue_coverage_gaps · dst_generator.ail")
        cats = VGroup(*[pill(s, c, size=23) for s, c in
                       [("provider", PURPLE), ("tool", BLUE), ("approval", YELLOW), ("extension", TEAL)]])
        cats.arrange(RIGHT, buff=0.6).move_to([0, 2.1, 0])
        count = label("11 catalogue classes · applicability is profile-dependent", 0, 1.28, GREY_A, 24)
        self.say("The catalogue defines eleven fault classes.", "Applicability and recovery branches are explicit.")
        self.play(FadeIn(cats), FadeIn(count), run_time=0.8)
        self.rest(0.15)

        examples = label("retryable error     wrong tool-call id     explicit denial", 0, 0.5, RED, 24)
        self.say("Provider errors and wrong tool-call identities", "reach the real driver at its boundaries.")
        self.play(FadeIn(examples), run_time=0.5)
        self.rest(0.15)

        axis = arrow([-5.5, -0.7, 0], [5.5, -0.7, 0], color=TEAL)
        deadline = DashedLine([0.8, -1.08, 0], [0.8, -0.25, 0], color=YELLOW)
        early = Dot([-2.7, -0.7, 0], color=GREEN)
        late = Dot([3.7, -0.7, 0], color=RED)
        labels = VGroup(label("completion", -2.7, -1.35, GREEN, 21),
                        label("deadline", 0.8, -1.35, YELLOW, 21),
                        label("late completion", 3.7, -1.35, RED, 21))
        self.say("Virtual latency can move completion past a deadline.", "The positions here are illustrative.")
        self.play(GrowArrow(axis), Create(deadline), FadeIn(early), FadeIn(late), FadeIn(labels), run_time=1)
        self.rest(0.15)

        caveat = label("approval clock deadline: no declaring production policy", 0, -2.12, YELLOW, 22)
        self.say("Approval is different: no production policy declares", "a clock deadline. That catalogue class is waived.")
        self.play(FadeIn(caveat), run_time=0.5)
        self.rest(0.15)
        self.end()


class S5_Oracle(Explainer):
    def construct(self):
        self.header("Built here", "judge the execution, not the final prose")
        self.source("dst_invariants.ail: all_families / family_obligation · dst_execution.ail · dst_result.ail: DstResult")
        trace = VGroup(*[node(s, c, w=2.7, h=0.8, size=23) for s, c in
                        [("provider call", BLUE), ("tool result", TEAL), ("journal", PURPLE), ("RunSummary", YELLOW)]])
        trace.arrange(RIGHT, buff=0.35).move_to([0, 2.08, 0])
        self.say("The returned LedgerTrace is the oracle.", "The code defines thirteen invariant families.")
        self.play(LaggedStart(*[FadeIn(m) for m in trace], lag_ratio=0.15), run_time=1)
        self.rest(0.15)

        checks = panel("Examples of obligations", ["tool calls pair with results · budgets stay valid",
                       "progress stays bounded · journal folds to final state"], 0, 0.35, YELLOW, w=11.3, h=1.9)
        self.say("They check pairing, budgets and bounded progress.", "Journal records must fold back to the returned final state.")
        self.play(FadeIn(checks), run_time=0.7)
        self.rest(0.15)

        run = panel("SystemRun", ["success or provider failure", "one final RunSummary"], -3.4, -1.63, GREEN, w=5.7, h=1.6)
        self.say("A provider failure is still a system run.", "Its trace must end with exactly one RunSummary.")
        self.play(FadeIn(run), run_time=0.6)
        self.rest(0.15)

        fail = panel("HarnessFailure", ["invalid program or unsafe mismatch", "partial evidence; no invented summary"], 3.4, -1.63, RED, w=5.7, h=1.6)
        self.say("An invalid program is a harness failure.", "It must not masquerade as a successful test.")
        self.play(FadeIn(fail), run_time=0.6)
        self.rest(0.15)
        self.end()


class S6_Profiles(Explainer):
    def construct(self):
        self.header("Built here", "coverage has a name and a boundary")
        self.source("dst_driver_only.ail · dst_driver_plus_no_ops.ail · dst_driver_plus_compose.ail · dst_profile_coverage.ail")
        base = panel("driver_only / 32", ["real driver", "no installed extensions"], -3.35, 1.5, BLUE, w=6.0)
        comp = panel("driver_plus_compose / 13", ["compose response interceptor", "world-mediated effects in a graded run"], 3.35, 1.5, TEAL, w=6.0)
        self.say("The baseline driver_only profile installs no extensions.", "Its extension coverage is zero.")
        self.play(FadeIn(base), run_time=0.6)
        self.rest(0.15)

        self.say("The compose profile exercises mediated effects", "through its response interceptor.")
        self.play(FadeIn(comp), run_time=0.6)
        self.rest(0.15)

        noops = pill("driver_plus_no_ops: no world-mediating hooks", YELLOW, size=23).move_to([0, -0.2, 0])
        self.say("The no-ops profile has no world-mediating hooks.", "No-op coverage cannot prove mediation.")
        self.play(FadeIn(noops), run_time=0.6)
        self.rest(0.15)

        guard = panel("Profile contract", ["included boundaries · covered hooks · exclusions",
                      "coverage does not transfer to untested behavior"], 0, -1.5, GREY_B, w=10.5, h=1.85)
        self.say("Read each profile's boundaries and exclusions.", "A covered session is not universal extension coverage.")
        self.play(FadeIn(guard), run_time=0.6)
        self.rest(0.15)
        self.end()


class S7_Gates(Explainer):
    def construct(self):
        self.header("Built here", "a suite around the generated axis")
        self.source("Makefile: DST_TARGETS / dst / corpus_pr · dst_corpus.ail · m-motoko-dst-framework: layers")
        umbrella = node("make dst", BLUE, w=3.3).move_to([0, 2.3, 0])
        layers = panel("Established deterministic tests", ["pure policy · fixed loop scenarios",
                       "TypeScript harness · event parity"], -3.4, 0.55, BLUE, w=6.0)
        generated = panel("Generated world + gates", ["discovery · replay · fault catalogue",
                          "profiles · invariants · corpus"], 3.4, 0.55, TEAL, w=6.0)
        self.say("The make dst umbrella also runs policy, loop scenarios,", "harness checks and event parity.")
        self.play(FadeIn(umbrella), FadeIn(layers), run_time=0.8)
        self.rest(0.15)

        self.say("It also runs the world, replay and invariant gates.", "The generated axis earns the simulation label separately.")
        self.play(FadeIn(generated), run_time=0.6)
        self.rest(0.15)

        bank = pill("fixed seeds + exact promoted failures", PURPLE, size=23).move_to([-3.3, -1.4, 0])
        window = pill("rotating seed windows", TEAL, size=23).move_to([3.4, -1.4, 0])
        self.say("The corpus combines fixed seeds and promoted failures.", "Rotating windows explore additional trajectories.")
        self.play(FadeIn(bank), FadeIn(window), run_time=0.6)
        self.rest(0.15)

        mincheck = label("declared minimums · reached fault classes · reached branches", 0, -2.25, YELLOW, 22)
        self.say("Gates check minimums and fault reachability.", "This film does not rerun the test suite.")
        self.play(FadeIn(mincheck), run_time=0.5)
        self.rest(0.15)
        self.end()


class S8_Limits(Explainer):
    def construct(self):
        self.header("The limits", "a deterministic model is still a model")
        self.source("007 ADR D1.3, D2 · dst_fault_catalogue.ail · dst_replay.ail · dst-discovery-replay.mmd")
        yes = panel("CAN EXPOSE", ["broken transitions and pairing", "bad accounting · missing trace records"], -3.4, 1.45, GREEN, w=6.0)
        no = panel("OUT OF SCOPE", ["model answer quality · live wire parser", "physical faults · multi-actor interleavings"], 3.4, 1.45, GREY_B, w=6.0)
        self.say("It can expose broken transitions and missing trace records", "within the modeled behavior.")
        self.play(FadeIn(yes), run_time=0.6)
        self.rest(0.15)

        self.say("Model quality, wire parsing, physical faults", "and multi-actor interleavings are outside this scope.")
        self.play(FadeIn(no), run_time=0.6)
        self.rest(0.15)

        designed = pill("DESIGNED: failure-preserving program shrinking", YELLOW, size=22, dashed=True).move_to([0, -0.45, 0])
        small = label("not implemented in the inspected DST code", 0, -1.05, GREY_B, 21)
        self.say("Program shrinking appears in the design.", "The inspected DST code does not implement that reducer.")
        self.play(FadeIn(designed), FadeIn(small), run_time=0.6)
        self.rest(0.15)

        lesson = label("same wrong result twice is still wrong", 0, -1.95, YELLOW, 31)
        self.say("Determinism alone can repeat the same mistake.", "Independent witnesses and negative controls test the tester.")
        self.play(FadeIn(lesson), run_time=0.7)
        self.rest(0.8)
        self.end()
