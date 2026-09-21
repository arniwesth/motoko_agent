import { execFile } from "child_process";
import { promises as fsp } from "fs";

/**
 * The AILANG runtime's memory, for the footer. The container's OOM killer has taken Motoko twice
 * (`.agent/issues/a-killed-motoko-process-exits-silently.md`) with nothing recording how large the
 * runtime had grown; a number on screen is the cheapest way to watch it happen.
 */
export interface ProcessMemory {
  rssBytes: number;
  /** High-water mark (Linux `VmHWM`); null where the platform does not report one. */
  peakBytes: number | null;
}

/** `VmRSS` and `VmHWM` out of `/proc/<pid>/status`, or null when there is no `VmRSS` (a zombie). */
export function parseProcStatusMemory(text: string): ProcessMemory | null {
  const bytes = (key: string): number | null => {
    const m = new RegExp(`^${key}:\\s+(\\d+)\\s+kB`, "m").exec(text);
    return m ? Number(m[1]) * 1024 : null;
  };
  const rssBytes = bytes("VmRSS");
  return rssBytes === null ? null : { rssBytes, peakBytes: bytes("VmHWM") };
}

/** One reading of `pid`'s memory: procfs where it exists, else `ps` (RSS only); null when gone. */
export async function readProcessMemory(pid: number): Promise<ProcessMemory | null> {
  try {
    return parseProcStatusMemory(await fsp.readFile(`/proc/${pid}/status`, "utf8"));
  } catch {
    // No procfs (macOS), or the process is gone — `ps` answers the first and returns nothing for the second.
  }
  return new Promise((resolve) => {
    execFile("ps", ["-o", "rss=", "-p", String(pid)], (err, stdout) => {
      const kib = Number(String(stdout).trim());
      resolve(err || String(stdout).trim() === "" || !Number.isFinite(kib) ? null : { rssBytes: kib * 1024, peakBytes: null });
    });
  });
}

/** `812M`, `1.2G` — binary units, as `docker stats` and the compose `mem_limit` read them. */
export function formatMemoryBytes(bytes: number): string {
  const mib = bytes / (1024 * 1024);
  return mib < 1024 ? `${Math.round(mib)}M` : `${(mib / 1024).toFixed(1)}G`;
}

/** The footer segment: `ailang mem: 812M (peak 3.4G)`, the peak omitted when unknown or no larger. */
export function formatProcessMemory(m: ProcessMemory): string {
  const now = formatMemoryBytes(m.rssBytes);
  const peak = m.peakBytes === null ? null : formatMemoryBytes(m.peakBytes);
  return peak !== null && peak !== now ? `ailang mem: ${now} (peak ${peak})` : `ailang mem: ${now}`;
}

/**
 * Throttled, non-blocking sampling for a render loop that ticks far faster than memory moves (the
 * footer redraws every 150 ms). `poll` returns the latest reading at once and starts a new one in
 * the background at most every `intervalMs`; a different pid discards the old process's reading.
 */
export class MemorySampler {
  private pid: number | undefined;
  private latest: ProcessMemory | null = null;
  private lastStartMs = -Infinity;
  private inFlight = false;

  constructor(
    private readonly intervalMs = 2000,
    private readonly read: (pid: number) => Promise<ProcessMemory | null> = readProcessMemory,
    private readonly now: () => number = Date.now,
  ) {}

  poll(pid: number | undefined): ProcessMemory | null {
    if (pid !== this.pid) {
      this.pid = pid;
      this.latest = null;
      this.lastStartMs = -Infinity;
    }
    if (pid === undefined) return null;
    const t = this.now();
    if (!this.inFlight && t - this.lastStartMs >= this.intervalMs) {
      this.inFlight = true;
      this.lastStartMs = t;
      void this.read(pid)
        .catch(() => null)
        .then((m) => {
          if (this.pid === pid) this.latest = m;
        })
        .finally(() => {
          this.inFlight = false;
        });
    }
    return this.latest;
  }
}
