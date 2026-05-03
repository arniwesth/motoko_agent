import { describe, expect, it } from "@jest/globals";
import { createClaimCheckTelemetry, runClaimCheck, type ClaimCheckStreamCall } from "./compose-claimcheck.js";

function mkBase(callStream: ClaimCheckStreamCall) {
  return {
    enabled: true,
    intentKind: "analyze",
    intent: "Analyze command flow in src/core/rpc.ail",
    certificateStdout: "PREMISES\nsrc/core/rpc.ail -> has rpc_loop\nTRACE\npremise supports flow\nCONCLUSION\nrpc_loop handles flow",
    informalizerModel: "m1",
    comparatorModel: "m2",
    timeoutMs: 2000,
    maxInvocations: 10,
    stdoutMaxBytes: 4000,
    telemetry: createClaimCheckTelemetry(),
    callStream,
    emitEvent: () => {},
    step: 1,
    composeId: "c1",
    attempt: 1,
  } as const;
}

describe("compose claimcheck", () => {
  it("forces retry on high-confidence disputed verdict", async () => {
    const callStream: ClaimCheckStreamCall = async (_model, prompt) => {
      if (prompt.includes("Certificate:")) return { output: "It concludes a different claim.", streamed: false };
      return { output: '{"verdict":"disputed","confidence":"high","reason":"different conclusion"}', streamed: false };
    };
    const r = await runClaimCheck(mkBase(callStream));
    expect(r.ran).toBe(true);
    expect(r.shouldRetry).toBe(true);
    expect(r.verdict).toBe("disputed");
  });

  it("accepts when informalizer returns empty text", async () => {
    const callStream: ClaimCheckStreamCall = async (_model, prompt) => {
      if (prompt.includes("Certificate:")) return { output: "   ", streamed: false };
      return { output: '{"verdict":"confirmed","confidence":"high","reason":"ok"}', streamed: false };
    };
    const r = await runClaimCheck(mkBase(callStream));
    expect(r.accepted).toBe(true);
    expect(r.verdict).toBe("inconclusive");
  });

  it("preserves separation invariant in prompts", async () => {
    const prompts: string[] = [];
    const callStream: ClaimCheckStreamCall = async (_model, prompt) => {
      prompts.push(prompt);
      if (prompt.includes("Certificate:")) return { output: "certificate talks about module boundaries", streamed: false };
      return { output: '{"verdict":"confirmed","confidence":"high","reason":"aligned"}', streamed: false };
    };
    const p = mkBase(callStream);
    await runClaimCheck(p);
    expect(prompts.length).toBeGreaterThanOrEqual(2);
    const pass1 = prompts[0] ?? "";
    const pass2 = prompts[1] ?? "";
    expect(pass1).not.toContain(p.intent);
    expect(pass2).not.toContain(p.certificateStdout);
  });

  it("skips when invocation budget is exhausted", async () => {
    const telemetry = createClaimCheckTelemetry();
    telemetry.invocations = 10;
    const r = await runClaimCheck({
      ...mkBase(async () => ({ output: "", streamed: false })),
      telemetry,
      maxInvocations: 10,
    });
    expect(r.ran).toBe(false);
    expect(r.accepted).toBe(true);
    expect(telemetry.budget_exhausted).toBe(true);
  });
});
