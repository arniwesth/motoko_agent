import { describe, it, expect } from "@jest/globals";
import { formatResumedHistory } from "./ui.js";

// PLAN-003 P3 Part 5: the resumed TUI prints the folded history with ADR-003 D6's marker line.
const view = {
  type: "session_resume_view" as const,
  resume_count: 2,
  from_id: "0012",
  boundary: "open:history_appended",
  boundary_detail: "the process died mid-run, after a history_appended",
  suspended: false,
  profile_from: "dogfood",
  profile_to: "probe-budget",
  head_replaced: true,
  forced: false,
  dangling: ["call_7"],
  ext_artifacts_digest: "sha256:e",
  ext_artifacts_empty: true,
  messages: 3,
  provider_calls_started: 2,
  provider_calls_completed: 2,
};

describe("formatResumedHistory", () => {
  it("prints the history and a marker naming the count, the boundary, both profiles and the dangling call", () => {
    const out = formatResumedHistory(
      [
        { role: "system", content: "you are motoko", tool_calls: [], tool_call_id: "", images: [] },
        { role: "user", content: "list the files", tool_calls: [], tool_call_id: "", images: [] },
        { role: "assistant", content: "", tool_calls: [{ id: "c1", name: "bash", arguments: "{\"cmd\":\"ls\"}" }], tool_call_id: "", images: [] },
      ],
      view,
    );
    expect(out.history.map((l) => l.text)).toEqual(["[system prompt, 14 chars]", "> list the files", '→ bash({"cmd":"ls"})']);
    expect(out.marker).toContain("resumed session #2");
    expect(out.marker).toContain("the process died mid-run");
    expect(out.marker).toContain("profile dogfood → probe-budget");
    expect(out.marker).toContain("stripped 1 dangling tool call(s): call_7");
    expect(out.marker).toContain("2 provider call(s) carried");
  });

  it("names neither a switch nor dangling calls when there were none, and says a suspended run is held", () => {
    const out = formatResumedHistory([], { ...view, profile_from: "p", profile_to: "p", dangling: [], head_replaced: false, suspended: true });
    expect(out.marker).not.toContain("profile");
    expect(out.marker).not.toContain("dangling");
    expect(out.marker).toContain("the suspended run is held");
  });
});
