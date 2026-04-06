# Agent instructions for Codex

You are writing Verilog or SystemVerilog testbenches from a Markdown design spec.

## Goal
Generate a clean, minimal, runnable testbench that matches the spec.

## Rules
- Read `SPEC.md` first.
- Do not modify `SPEC.md`.
- Write the testbench to the requested output file in `generated/`.
- If the spec is incomplete, state assumptions in `generated/README_TESTBENCH.md`.
- Prefer explicit clocks, resets, and self-checking checks where the spec allows it.
- Use deterministic stimuli and keep the testbench focused on the described behavior.
- Do not add unrelated refactors or extra files unless requested.
