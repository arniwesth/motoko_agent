import { describe, expect, it } from "@jest/globals";
import {
  formatMemoryBytes,
  formatProcessMemory,
  MemorySampler,
  parseProcStatusMemory,
  readProcessMemory,
  type ProcessMemory,
} from "./process-memory.js";

const MiB = 1024 * 1024;
const GiB = 1024 * MiB;
const settle = () => new Promise((resolve) => setImmediate(resolve));

describe("parseProcStatusMemory", () => {
  it("reads VmRSS and VmHWM in kB", () => {
    const status = "Name:\tailang\nVmPeak:\t 9000000 kB\nVmHWM:\t  754328 kB\nVmRSS:\t  250372 kB\nThreads:\t12\n";
    expect(parseProcStatusMemory(status)).toEqual({ rssBytes: 250372 * 1024, peakBytes: 754328 * 1024 });
  });

  it("is null for a status without VmRSS (a zombie)", () => {
    expect(parseProcStatusMemory("Name:\tailang\nState:\tZ (zombie)\n")).toBeNull();
  });
});

describe("formatting", () => {
  it("uses M below a GiB and one decimal of G above", () => {
    expect(formatMemoryBytes(812 * MiB)).toBe("812M");
    expect(formatMemoryBytes(1.24 * GiB)).toBe("1.2G");
    expect(formatMemoryBytes(24 * GiB)).toBe("24.0G");
  });

  it("shows the peak only when it is known and larger", () => {
    expect(formatProcessMemory({ rssBytes: 245 * MiB, peakBytes: 3.4 * GiB })).toBe("ailang mem: 245M (peak 3.4G)");
    expect(formatProcessMemory({ rssBytes: 245 * MiB, peakBytes: 245 * MiB })).toBe("ailang mem: 245M");
    expect(formatProcessMemory({ rssBytes: 245 * MiB, peakBytes: null })).toBe("ailang mem: 245M");
  });
});

describe("readProcessMemory", () => {
  it("reads this process", async () => {
    const m = await readProcessMemory(process.pid);
    expect(m?.rssBytes).toBeGreaterThan(0);
  });
});

describe("MemorySampler", () => {
  function sampler() {
    let clock = 0;
    const reads: number[] = [];
    const s = new MemorySampler(2000, async (pid): Promise<ProcessMemory> => {
      reads.push(pid);
      return { rssBytes: pid * MiB, peakBytes: null };
    }, () => clock);
    return { s, reads, advance: (ms: number) => { clock += ms; } };
  }

  it("returns the latest reading and reads at most once per interval", async () => {
    const { s, reads, advance } = sampler();
    expect(s.poll(7)).toBeNull();
    await settle();
    expect(s.poll(7)).toEqual({ rssBytes: 7 * MiB, peakBytes: null });
    advance(1999);
    s.poll(7);
    expect(reads).toEqual([7]);
    advance(1);
    s.poll(7);
    expect(reads).toEqual([7, 7]);
  });

  it("drops the old process's reading when the pid changes, and shows nothing without one", async () => {
    const { s } = sampler();
    s.poll(7);
    await settle();
    expect(s.poll(undefined)).toBeNull();
    expect(s.poll(9)).toBeNull();
    await settle();
    expect(s.poll(9)?.rssBytes).toBe(9 * MiB);
  });
});
