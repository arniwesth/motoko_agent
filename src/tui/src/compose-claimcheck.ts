export type ClaimCheckVerdict =
  | "confirmed"
  | "disputed"
  | "vacuous"
  | "surprising_restriction"
  | "inconclusive";

export type ClaimCheckConfidence = "high" | "low";

export type ClaimCheckTelemetry = {
  invocations: number;
  verdicts: Record<ClaimCheckVerdict, number>;
  informalizer_ms: number[];
  comparator_ms: number[];
  informalizer_timeouts: number;
  informalizer_errors: number;
  informalizer_empty: number;
  comparator_timeouts: number;
  comparator_errors: number;
  comparator_json_repair_attempts: number;
  comparator_json_repair_failures: number;
  budget_exhausted: boolean;
  truncated_stdout_cases: number;
  budget_exhausted_emitted: boolean;
};

export type ClaimCheckStreamCall = (
  model: string,
  prompt: string,
  onDelta: (delta: string) => void,
  timeoutMs: number,
) => Promise<{ output: string; streamed: boolean }>;

export type ClaimCheckEvent = {
  type:
    | "compose_claimcheck_informalize_delta"
    | "compose_claimcheck_informalize_result"
    | "compose_claimcheck_compare_delta"
    | "compose_claimcheck_compare_result";
  step: number;
  compose_id: string;
  attempt: number;
  delta?: string;
  informalization?: string;
  verdict?: ClaimCheckVerdict;
  confidence?: ClaimCheckConfidence;
  reason?: string;
};

export type RunClaimCheckParams = {
  enabled: boolean;
  intentKind: string;
  intent: string;
  certificateStdout: string;
  informalizerModel: string;
  comparatorModel: string;
  timeoutMs: number;
  maxInvocations: number;
  stdoutMaxBytes: number;
  telemetry: ClaimCheckTelemetry;
  callStream: ClaimCheckStreamCall;
  emitEvent: (evt: ClaimCheckEvent) => void;
  step: number;
  composeId: string;
  attempt: number;
};

export type RunClaimCheckResult = {
  ran: boolean;
  accepted: boolean;
  shouldRetry: boolean;
  verdict: ClaimCheckVerdict;
  confidence: ClaimCheckConfidence;
  reason: string;
  informalization: string;
  correctiveHint: string;
};

export function createClaimCheckTelemetry(): ClaimCheckTelemetry {
  return {
    invocations: 0,
    verdicts: {
      confirmed: 0,
      disputed: 0,
      vacuous: 0,
      surprising_restriction: 0,
      inconclusive: 0,
    },
    informalizer_ms: [],
    comparator_ms: [],
    informalizer_timeouts: 0,
    informalizer_errors: 0,
    informalizer_empty: 0,
    comparator_timeouts: 0,
    comparator_errors: 0,
    comparator_json_repair_attempts: 0,
    comparator_json_repair_failures: 0,
    budget_exhausted: false,
    truncated_stdout_cases: 0,
    budget_exhausted_emitted: false,
  };
}

function truncateUtf8ByBytes(s: string, maxBytes: number): { text: string; truncated: boolean; omittedBytes: number } {
  const b = Buffer.from(s, "utf8");
  if (b.byteLength <= maxBytes) return { text: s, truncated: false, omittedBytes: 0 };
  const kept = b.subarray(0, Math.max(0, maxBytes)).toString("utf8");
  return { text: kept, truncated: true, omittedBytes: Math.max(0, b.byteLength - Buffer.byteLength(kept, "utf8")) };
}

function isTimeoutError(e: unknown): boolean {
  return String((e as any)?.message ?? e).toLowerCase().includes("timed out");
}

function informalizerPrompt(certificate: string): string {
  return [
    "Read the certificate below. In <=40 words, describe what it demonstrates,",
    "based only on its PREMISES, TRACE, and CONCLUSION lines.",
    "Do not speculate about the author's goal; describe only what the certificate's own text says was shown.",
    "",
    "Certificate:",
    certificate,
  ].join("\n");
}

function comparatorPrompt(intent: string, informalization: string): string {
  return [
    `Original request: ${intent}`,
    `Observed summary:  ${informalization}`,
    "",
    "Does the observed summary describe the same conclusion the request was asking for?",
    "Respond with JSON:",
    "{",
    '  "verdict": "confirmed" | "disputed" | "vacuous" | "surprising_restriction" | "inconclusive",',
    '  "confidence": "high" | "low",',
    '  "reason": "<one sentence>"',
    "}",
  ].join("\n");
}

function comparatorRepairPrompt(raw: string): string {
  return [
    "Repair this output into strict JSON with keys verdict, confidence, reason.",
    "Output JSON only.",
    "",
    "Raw output:",
    raw,
  ].join("\n");
}

function parseComparatorJson(text: string): { verdict: ClaimCheckVerdict; confidence: ClaimCheckConfidence; reason: string } | null {
  const raw = (text ?? "").trim();
  if (!raw) return null;
  const first = raw.indexOf("{");
  const last = raw.lastIndexOf("}");
  const candidate = first >= 0 && last > first ? raw.slice(first, last + 1) : raw;
  try {
    const parsed = JSON.parse(candidate) as Record<string, unknown>;
    const verdict = String(parsed.verdict ?? "");
    const confidence = String(parsed.confidence ?? "");
    const reason = String(parsed.reason ?? "");
    if (
      (verdict === "confirmed" ||
        verdict === "disputed" ||
        verdict === "vacuous" ||
        verdict === "surprising_restriction" ||
        verdict === "inconclusive") &&
      (confidence === "high" || confidence === "low")
    ) {
      return { verdict, confidence, reason: reason.trim() || "no reason provided" };
    }
    return null;
  } catch {
    return null;
  }
}

export async function runClaimCheck(params: RunClaimCheckParams): Promise<RunClaimCheckResult> {
  const {
    enabled,
    intentKind,
    intent,
    certificateStdout,
    informalizerModel,
    comparatorModel,
    timeoutMs,
    maxInvocations,
    stdoutMaxBytes,
    telemetry,
    callStream,
    emitEvent,
    step,
    composeId,
    attempt,
  } = params;

  if (!enabled || intentKind !== "analyze") {
    return {
      ran: false,
      accepted: true,
      shouldRetry: false,
      verdict: "inconclusive",
      confidence: "low",
      reason: "claimcheck disabled or non-analysis intent",
      informalization: "",
      correctiveHint: "",
    };
  }
  if (telemetry.invocations >= maxInvocations) {
    telemetry.budget_exhausted = true;
    return {
      ran: false,
      accepted: true,
      shouldRetry: false,
      verdict: "inconclusive",
      confidence: "low",
      reason: "sf5 budget exhausted",
      informalization: "",
      correctiveHint: "",
    };
  }

  telemetry.invocations += 1;

  const trunc = truncateUtf8ByBytes(certificateStdout, Math.max(1, stdoutMaxBytes));
  let certForPrompt = trunc.text;
  if (trunc.truncated) {
    telemetry.truncated_stdout_cases += 1;
    certForPrompt = `${trunc.text}\n[truncated: ${trunc.omittedBytes} bytes omitted]`;
  }

  let informalization = "";
  try {
    const t0 = Date.now();
    const r = await callStream(
      informalizerModel,
      informalizerPrompt(certForPrompt),
      (delta) => {
        emitEvent({
          type: "compose_claimcheck_informalize_delta",
          step,
          compose_id: composeId,
          attempt,
          delta,
        });
      },
      timeoutMs,
    );
    telemetry.informalizer_ms.push(Date.now() - t0);
    informalization = String(r.output ?? "").trim();
  } catch (e) {
    if (isTimeoutError(e)) telemetry.informalizer_timeouts += 1;
    else telemetry.informalizer_errors += 1;
    telemetry.verdicts.inconclusive += 1;
    return {
      ran: true,
      accepted: true,
      shouldRetry: false,
      verdict: "inconclusive",
      confidence: "low",
      reason: isTimeoutError(e) ? "informalizer timeout" : "informalizer error",
      informalization: "",
      correctiveHint: "",
    };
  }

  emitEvent({
    type: "compose_claimcheck_informalize_result",
    step,
    compose_id: composeId,
    attempt,
    informalization,
  });

  if (informalization === "") {
    telemetry.informalizer_empty += 1;
    telemetry.verdicts.inconclusive += 1;
    return {
      ran: true,
      accepted: true,
      shouldRetry: false,
      verdict: "inconclusive",
      confidence: "low",
      reason: "informalizer empty output",
      informalization: "",
      correctiveHint: "",
    };
  }

  let compareRaw = "";
  try {
    const t0 = Date.now();
    const r = await callStream(
      comparatorModel,
      comparatorPrompt(intent, informalization),
      (delta) => {
        emitEvent({
          type: "compose_claimcheck_compare_delta",
          step,
          compose_id: composeId,
          attempt,
          delta,
        });
      },
      timeoutMs,
    );
    telemetry.comparator_ms.push(Date.now() - t0);
    compareRaw = String(r.output ?? "");
  } catch (e) {
    if (isTimeoutError(e)) telemetry.comparator_timeouts += 1;
    else telemetry.comparator_errors += 1;
    telemetry.verdicts.inconclusive += 1;
    return {
      ran: true,
      accepted: true,
      shouldRetry: false,
      verdict: "inconclusive",
      confidence: "low",
      reason: isTimeoutError(e) ? "comparator timeout" : "comparator error",
      informalization,
      correctiveHint: "",
    };
  }

  let parsed = parseComparatorJson(compareRaw);
  if (!parsed) {
    telemetry.comparator_json_repair_attempts += 1;
    try {
      const repaired = await callStream(comparatorModel, comparatorRepairPrompt(compareRaw), () => {}, timeoutMs);
      parsed = parseComparatorJson(String(repaired.output ?? ""));
    } catch {
      parsed = null;
    }
    if (!parsed) {
      telemetry.comparator_json_repair_failures += 1;
      telemetry.comparator_errors += 1;
      telemetry.verdicts.inconclusive += 1;
      return {
        ran: true,
        accepted: true,
        shouldRetry: false,
        verdict: "inconclusive",
        confidence: "low",
        reason: "comparator malformed JSON",
        informalization,
        correctiveHint: "",
      };
    }
  }

  telemetry.verdicts[parsed.verdict] += 1;
  emitEvent({
    type: "compose_claimcheck_compare_result",
    step,
    compose_id: composeId,
    attempt,
    verdict: parsed.verdict,
    confidence: parsed.confidence,
    reason: parsed.reason,
    informalization,
  });

  const forceRetry =
    parsed.confidence === "high" &&
    (parsed.verdict === "disputed" || parsed.verdict === "vacuous" || parsed.verdict === "surprising_restriction");
  const correctiveHint = forceRetry
    ? [
        "ClaimCheck flagged the previous certificate as off-target.",
        `Observed summary from certificate: ${informalization}`,
        "Revise premises/trace/conclusion so the conclusion directly answers the original intent.",
      ].join("\n")
    : "";
  return {
    ran: true,
    accepted: !forceRetry,
    shouldRetry: forceRetry,
    verdict: parsed.verdict,
    confidence: parsed.confidence,
    reason: parsed.reason,
    informalization,
    correctiveHint,
  };
}
