# Chess Engine Development Plan (AILANG)
# Authored by: google/gemma-4-26B-A4B-it

## Overview
A purely functional chess engine designed for AILANG, leveraging bitboards, recursion, and Z3-based formal verification to ensure absolute correctness of chess rules.

## 1. Core Architecture
- **Pure Logic Layer**: Implements bitboard manipulation, move generation, and evaluation using pure functions (`! {}`). This layer is designed for full Z3 verification.
- **Search Engine**: Recursive implementation of Alpha-Beta pruning.
- **Effectful Shell**: Handles UCI protocol, user I/O, and file system access for opening books.

## 2. Module Decomposition
| Module | Responsibility |
| :--- | :--- |
| `chess/types` | Definitions of `Piece`, `Color`, `Board`, `Move` |
| `chess/bitboard` | Bitwise primitives (popcount, bit manipulation) |
| `chess/rules` | Move generation and legality verification |
| `chess/eval` | Material and positional evaluation heuristics |
| `chess/search` | Alpha-Beta pruning and move ordering |
| `chess/uci` | UCI protocol parsing and response formatting |
| `main` | Entry point with `IO` effects |

## 3. Verification Strategy
Use `requires` and `ensures` contracts to prove:
- **Move Legality**: `generate_moves` only produces moves permitted by piece mechanics.
- **Piece Conservation**: No pieces are created or destroyed unintentionally.
- **King Safety**: No move results in a state where the king remains in check.

## 4. Implementation Roadmap
- **Phase 1: Types & Bitboards**: Define the bitboard schema and bitwise operations.
- **Phase 2: Move Generation**: Implement sliding, leaping, and pawn mechanics via recursion.
- **Phase 3: Formal Verification**: Apply contracts to `chess/rules` and run `ailang verify`.
- **Phase 4: Search & Eval**: Implement Alpha-Beta pruning and piece-square tables.
- **Phase 5: UCI Interface**: Implement the command loop in `main`.
- **Phase 6: Benchmarking**: Evaluate engine performance against standard benchmarks.
