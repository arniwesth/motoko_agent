// tui/src/context-limit.ts
//
// The operator-facing half of "`Unknown` is loud" (013 ADR-001 D1, issue #237).
//
// The core resolves the context limit once per run and says how in a
// `context_limit_resolved` record (`phase_vocab.ail`'s `ContextLimitResolved`).
// When neither the profile's `agent.context_limit` nor the model catalogue
// yields a window the arm is `unknown`, the int every extension reads is 0,
// and both shipped compactors pass through on 0: they take a percentage of the
// window and have none to take. Until this file that record was the only trace
// — on the wire and in the session log, where nobody reads it until the bill
// arrives (#237: 157 steps, 3k to 260k tokens, no compaction).
//
// This turns the `unknown` arm into a `warning` event, which every consumer
// already shows: the TUI history, the plain logger's stderr, the JSONL wire and
// the transcript. It changes no behaviour; whether an unknown limit should also
// refuse, or assume a window, is ADR-001's open "behaviour under `Unknown`".

export type ContextLimitSource = {
  arm: string;
  origin: string;
  profile_miss: string;
  catalogue_miss: string;
  model: string;
};

// The ids are `context_limit.ail`'s `profile_miss_id` / `catalogue_miss_id`.
// An id this table does not know is shown as itself, so a miss added in the
// core is still named here before anyone writes its sentence.
const PROFILE_MISS: Record<string, string> = {
  profile_config_absent: "the profile has no config.json",
  profile_config_undecodable: "the profile's config.json does not decode",
  profile_key_absent: "the profile sets no agent.context_limit",
  profile_key_non_positive: "the profile's agent.context_limit is not a positive number",
};

const CATALOGUE_MISS: Record<string, string> = {
  catalogue_absent: ".motoko/model-catalog.json was not found",
  catalogue_undecodable: ".motoko/model-catalog.json does not decode or has no context_limits",
  model_not_in_catalogue: "the model is not in .motoko/model-catalog.json",
};

const REMEDY =
  "Set agent.context_limit in the profile's config.json, or add the model under context_limits in .motoko/model-catalog.json.";

function sourceOf(event: unknown): ContextLimitSource | null {
  if (!event || typeof event !== "object") return null;
  const rec = event as Record<string, unknown>;
  if (rec.type !== "context_limit_resolved") return null;
  const source = rec.context_limit_source;
  if (!source || typeof source !== "object") return null;
  const s = source as Record<string, unknown>;
  const str = (v: unknown): string => (typeof v === "string" ? v : "");
  return {
    arm: str(s.arm),
    origin: str(s.origin),
    profile_miss: str(s.profile_miss),
    catalogue_miss: str(s.catalogue_miss),
    model: str(s.model),
  };
}

// `session_start`'s `loaded_extensions` are registry names with the `#idx`
// already stripped (`ext/runtime.ail`'s `hook_names`). The two shipped
// compactors are `compaction_ai` and `compaction_structural`; the host cannot
// see which other extensions register `on_pre_step`, so the prefix is the test.
export function loadedCompactors(loadedExtensions: readonly string[]): string[] {
  return loadedExtensions.filter((name) => name.startsWith("compaction_"));
}

function joinNames(names: string[]): string {
  if (names.length <= 1) return names.join("");
  return `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]}`;
}

/**
 * The warning for a `context_limit_resolved` whose arm is `unknown`, or null for any other event
 * and any other arm. `disabled` is silent on purpose: it is declared in the profile, never
 * inferred, so whoever runs that profile already chose to have no window.
 *
 * `runModel` is the model the run's `session_start` named. The record names the model itself only
 * for `model_not_in_catalogue` (`context_limit.ail`'s `limit_missing_model`); with a catalogue
 * that is absent or does not decode its `model` is "", and the run's is the only name there is.
 */
export function unknownContextLimitWarning(
  event: unknown,
  loadedExtensions: readonly string[] = [],
  runModel = "",
): string | null {
  const source = sourceOf(event);
  if (source === null || source.arm !== "unknown") return null;

  const model = source.model !== "" ? source.model : runModel;
  const subject = model !== "" ? ` for ${model}` : "";
  const why = [
    CATALOGUE_MISS[source.catalogue_miss] ?? source.catalogue_miss,
    PROFILE_MISS[source.profile_miss] ?? source.profile_miss,
  ].filter((reason) => reason !== "");
  const because = why.length > 0 ? `: ${why.join(" and ")}` : "";

  const compactors = loadedCompactors(loadedExtensions);
  const consequence =
    compactors.length > 0
      ? `${joinNames(compactors)} cannot trigger without a window, so this session's context will grow uncompacted.`
      : "Context usage is unmeasured for this session.";

  return `context limit unknown${subject}${because}. ${consequence} ${REMEDY}`;
}

/**
 * One warning per distinct unknown resolution, not one per run.
 *
 * The core emits `context_limit_resolved` at the shared per-run entry, and a TTY runtime serves
 * every follow-up turn as a new run, so an unfiltered warning would repeat under each prompt. The
 * key is the model and the two misses: a `/model` switch to another model with no window warns
 * again, and a resolution that became `bounded` (the profile or the catalogue was fixed) clears
 * the key, so going back to an unknown one warns again too.
 *
 * The model is the run's, from `session_start`, which every run emits before its record (the
 * startup banner and each turn's own both carry `model`). The record's own `model` cannot be the
 * key: it is "" unless the miss is `model_not_in_catalogue`, so with no catalogue two different
 * models would share one key and the second would never be warned about.
 */
export class UnknownLimitWatch {
  private loadedExtensions: string[] = [];
  private runModel = "";
  private warnedKey: string | null = null;

  observe(event: unknown): string | null {
    if (!event || typeof event !== "object") return null;
    const rec = event as Record<string, unknown>;
    if (rec.type === "session_start") {
      if (typeof rec.model === "string" && rec.model !== "") this.runModel = rec.model;
      if (Array.isArray(rec.loaded_extensions)) {
        this.loadedExtensions = rec.loaded_extensions.filter((n): n is string => typeof n === "string");
      }
      return null;
    }
    const source = sourceOf(event);
    if (source === null) return null;
    if (source.arm !== "unknown") {
      this.warnedKey = null;
      return null;
    }
    const model = source.model !== "" ? source.model : this.runModel;
    const key = `${model}|${source.profile_miss}|${source.catalogue_miss}`;
    if (key === this.warnedKey) return null;
    this.warnedKey = key;
    return unknownContextLimitWarning(event, this.loadedExtensions, this.runModel);
  }
}
