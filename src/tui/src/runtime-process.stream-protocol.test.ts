import { describe, it, expect } from "@jest/globals";
import { parseAgentEventLine } from "./runtime-process.js";

describe("stream protocol decoder", () => {
  it("parses context usage events", () => {
    const evt = parseAgentEventLine('{"type":"context_usage","step":3,"tokens_est":12345,"limit":200000}');
    expect(evt?.type).toBe("context_usage");
    if (evt?.type !== "context_usage") return;
    expect(evt.tokens_est).toBe(12345);
    expect(evt.limit).toBe(200000);
  });

  it("parses thinking stream lifecycle events", () => {
    const start = parseAgentEventLine('{"type":"thinking_stream_start","step":3,"stream_id":"step-3","model":"openai/gpt-4o-mini"}');
    const delta = parseAgentEventLine('{"type":"thinking_delta","step":3,"stream_id":"step-3","seq":0,"text_delta":"hel"}');
    const end = parseAgentEventLine('{"type":"thinking_stream_end","step":3,"stream_id":"step-3","status":"completed"}');

    expect(start?.type).toBe("thinking_stream_start");
    expect(delta?.type).toBe("thinking_delta");
    expect(end?.type).toBe("thinking_stream_end");
  });

  it("parses scratchpad_result events with structured cells intact", () => {
    const cells = [{ index: 0, language: "py", code: "print(1)", title: "setup", exit_code: 0, stdout: "1\n", stderr: "", displays: [{ type: "json", data: { ok: true } }], executionCount: 1, cancelled: false, truncated: false }];
    const evt = parseAgentEventLine(JSON.stringify({
      type: "scratchpad_result",
      step: 4,
      request_id: "step-4",
      tool_call_id: "call_scratchpad",
      cells_json: JSON.stringify(cells),
    }));

    expect(evt?.type).toBe("scratchpad_result");
    if (evt?.type !== "scratchpad_result") return;
    expect(evt.request_id).toBe("step-4");
    expect(evt.tool_call_id).toBe("call_scratchpad");
    expect(JSON.parse(evt.cells_json)).toEqual(cells);
  });

  it("parses session_resume events", () => {
    const evt = parseAgentEventLine('{"type":"session_resume","session_id":"session_a","model":"test/model","restored_messages":4}');
    expect(evt?.type).toBe("session_resume");
    if (evt?.type !== "session_resume") return;
    expect(evt.model).toBe("test/model");
    expect(evt.restored_messages).toBe(4);
  });

  it("returns null for malformed or non-event lines", () => {
    expect(parseAgentEventLine("")).toBeNull();
    expect(parseAgentEventLine("not-json")).toBeNull();
    expect(parseAgentEventLine('{"foo":"bar"}')).toBeNull();
  });
});
