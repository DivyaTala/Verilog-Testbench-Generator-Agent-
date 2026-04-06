# Codex Verilog Testbench + Icarus Mutant Finder

This repo does two things:
1. Uses **Codex** to generate a Verilog/SystemVerilog testbench from a Markdown spec.
2. Uses **Icarus Verilog** to compile and simulate several DUT mutants against that testbench until exactly one candidate passes.

## What you need
- Windows 10/11
- Python 3.10+
- Git
- Node.js + npm
- Codex CLI (`codex --version`)
- Icarus Verilog (`iverilog` and `vvp` on PATH)

## One-time setup on Windows
Install Codex:
```powershell
npm install -g @openai/codex
```

Install Icarus Verilog however you prefer, then verify:
```powershell
iverilog -V
vvp -V
```

If PowerShell blocks npm scripts, run:
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

## Folder layout
Put your spec in:
```text
specs\my_spec.md
```

Put mutants here, either as single files or folders:
```text
mutants\mutant1.v
mutants\mutant2.v
mutants\mutant3.v
```

Generated files go here:
```text
generated\
```

## Step 1: generate the testbench with Codex
Run:
```powershell
python .\generate_testbench.py --spec .\specs\my_spec.md --outdir .\generated --tb-name tb_my_design --top-module my_dut
```

This creates:
- `generated\tb_my_design.sv` or `.v`
- `generated\README_TESTBENCH.md`

## Step 2: run mutants through Icarus
Run:
```powershell
python .\tools\mutant_harness.py --repo-root . --tb .\generated\tb_my_design.sv --tb-top tb_my_design --spec .\specs\my_spec.md --candidate .\mutants\mutant1.v --candidate .\mutants\mutant2.v --candidate .\mutants\mutant3.v
```

If each mutant is a directory of source files, pass the directory instead:
```powershell
python .\tools\mutant_harness.py --repo-root . --tb .\generated\tb_my_design.sv --tb-top tb_my_design --spec .\specs\my_spec.md --candidate .\mutants\mutant1 --candidate .\mutants\mutant2 --candidate .\mutants\mutant3
```

The harness will:
- compile each candidate with `iverilog`
- run the simulation with `vvp`
- look for the `TB_PASS` marker in the output
- write a `feedback.md` file
- ask Codex to refine the testbench if the result is ambiguous or no winner is found

## How the testbench should behave
Your generated testbench should:
- print exactly one `TB_PASS` line when everything is correct
- call `$error` or `$fatal` on mismatches
- avoid depending on waveform inspection
- be deterministic

## GitHub workflow
1. Create a GitHub repository.
2. Push this repo to GitHub.
3. Anyone with the repo link can clone it.
4. They still need their own Codex access and Icarus Verilog installed locally.
5. They place their spec and mutants into `specs/` and `mutants/`.
6. They run the two commands above.

## Notes
- The Windows Codex sandbox is set in `.codex/config.toml`.
- This repo keeps outputs isolated so you can commit the source scripts but ignore generated runs.
