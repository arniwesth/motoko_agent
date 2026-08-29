import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { buildChildEnv } from "./runtime-process.js";

// The egress proxy environment has to reach the AILANG runtime, and the failure
// when it does not is total but reads like a model problem.
//
// The confined dev container sits on an `internal: true` docker network: no
// gateway, no NAT, no external DNS. A squid sidecar is the single exit, and
// every process reaches it through HTTP_PROXY / HTTPS_PROXY / NO_PROXY. The
// provider call is made by the AILANG runtime — a CHILD of the TUI — and
// `buildChildEnv` is an explicit allowlist, so an unnamed variable is dropped.
//
// Without these, the runtime dials the provider host directly and every step
// dies on `lookup openrouter.ai on 127.0.0.11:53: server misbehaving`. Measured
// 2026-08-23 in session_2026-08-23T17-06-45-426Z: 134 consecutive
// stream_error_retry, zero bytes on the wire, and the log looked to the
// operator like the newly configured model was broken.

let workdir: string;
const KEYS = [
  "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY",
  "http_proxy", "https_proxy", "no_proxy",
] as const;
const saved: Record<string, string | undefined> = {};

beforeEach(() => {
  workdir = fs.mkdtempSync(path.join(os.tmpdir(), "proxy-child-env-"));
  for (const k of KEYS) saved[k] = process.env[k];
});

afterEach(() => {
  for (const k of KEYS) {
    if (saved[k] === undefined) delete process.env[k];
    else process.env[k] = saved[k];
  }
  fs.rmSync(workdir, { recursive: true, force: true });
});

describe("buildChildEnv forwards the egress proxy environment", () => {
  it("carries the proxy variables when the container has an egress boundary", () => {
    process.env.HTTPS_PROXY = "http://egress-proxy:3128";
    process.env.HTTP_PROXY = "http://egress-proxy:3128";
    process.env.NO_PROXY = "localhost,127.0.0.1,::1,egress-proxy";

    const childEnv = buildChildEnv(workdir, "someprofile", "", "");

    expect(childEnv.HTTPS_PROXY).toBe("http://egress-proxy:3128");
    expect(childEnv.HTTP_PROXY).toBe("http://egress-proxy:3128");
    expect(childEnv.NO_PROXY).toBe("localhost,127.0.0.1,::1,egress-proxy");
  });

  // Both cases, not just the uppercase one. Go's ProxyFromEnvironment reads
  // either spelling, but NO_PROXY is the exemption list — a lowercase-only
  // `no_proxy` that is dropped while `https_proxy` survives would route the
  // loopback env-server through squid, which cannot reach it.
  it("carries the lowercase spellings too", () => {
    process.env.https_proxy = "http://egress-proxy:3128";
    process.env.no_proxy = "localhost,127.0.0.1";

    const childEnv = buildChildEnv(workdir, "someprofile", "", "");

    expect(childEnv.https_proxy).toBe("http://egress-proxy:3128");
    expect(childEnv.no_proxy).toBe("localhost,127.0.0.1");
  });

  // Absent, not empty. An empty HTTPS_PROXY is not inert everywhere it lands,
  // and forwarding one would make the child env claim a boundary that the host
  // environment does not actually have.
  it("omits them entirely when there is no proxy rather than forwarding empties", () => {
    for (const k of KEYS) delete process.env[k];

    const childEnv = buildChildEnv(workdir, "someprofile", "", "");

    for (const k of KEYS) expect(k in childEnv).toBe(false);
  });
});
