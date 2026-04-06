You are generating a Verilog/SystemVerilog testbench from a Markdown spec.

Inputs:
- `SPEC.md` contains the design specification.
- The target DUT name is provided by the wrapper script.

Task:
1. Read `SPEC.md` carefully.
2. Infer the DUT ports, timing, reset behavior, and expected outputs.
3. Write a self-contained testbench file in `generated/`.
4. Write `generated/README_TESTBENCH.md` describing assumptions, how to run the testbench, and any unresolved spec questions.
5. Keep the spec unchanged.

Important requirements:
- Prefer a `timescale` if appropriate.
- Instantiate the DUT with explicit named port connections.
- Generate a clock if the DUT needs one.
- Drive reset cleanly.
- Include checks that fail loudly when behavior is wrong.
- If the spec is ambiguous, choose reasonable assumptions and document them.
- Do not edit files outside `generated/` unless absolutely necessary.
- Print exactly one line containing `TB_PASS` when all checks pass.
- Use `$error` or `$fatal` on mismatches.
