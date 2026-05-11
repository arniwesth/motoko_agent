# Core ideas of Motoko

## 1: Evolvable architecture

The architecture must remain flexible and evolvable

References:
https://evolutionaryarchitecture.com/precis.html
https://github.com/evolutionary-architecture/evolutionary-architecture-by-example


## 2: The Phoenix Architecture

The architecture must largely follow the Phoenix Architecture. This aligns well
with 1. 

Ideally, it should be possible to rebuild the entire Motoko codebase from scratch just by the specs, the design choice traces (plans) and the tests. 

As a consequence of this, no human edits to the codebase should be allowed.

References:
https://aicoding.leaflet.pub/3majnyfydzs2y


## 3: Extensibility

The system must be highly extensible. It draws its inspiration from the Pi Coding Agent (pi.dev), but ideally this is taken even further, by eg requering strict verificantion of extensions.

This means the core must be as lean as possible, and all functionality that *can* be delegated to an extension, *should* be delegated to an extension (core compaction). 

The system should be able to write and use new extensions in the same session without a restart. A broken extension should never cause a core crash.

This enables a high degree of selv-evolvability in the system.

References:
pi.dev
https://en.wikipedia.org/wiki/Extensibility


## 4: Simulation

The system should be fully simulatable. This aligns well with the AILANG vision that already has buld in traceability and determinism. 

This is essentially a weak form of Deterministic Simulation Testing. We are not going to simulate hardware failures, but we could simluate LLM responses deterministically by having a simulated LLM endpoint.

References:
https://antithesis.com/docs/resources/deterministic_simulation_testing/


## 5 Benchmark

Benchmarking should be a first-class citizen in the system. It should be possible to benchmark any combination of extensions against common benchmarks. An obvious benchmark is the AILANG benchmark, but it should also be possible to easily benchmarks against eg Aiders Polygot, SWE Bench and Terminal bench.

References:
https://ailang.sunholo.com/docs/benchmarks/performance
https://aider.chat/docs/leaderboards/
https://github.com/swe-bench/SWE-bench
https://github.com/harbor-framework/terminal-bench


## 6 Testing

The system should draw from already well-established test practices. 
Concepts like fuzzing and mutation testing should be considered as part of the roadmap.


## 7 Awareness

This is a very important concept. Most current-day coding agent harnesses have limited insight into their own state. It should be possible for the system to 
know its own state to the fullest possible extent. e.g., the system should know which model is used, be able to quere its own context window, it budget, how many steps left for the session etc.