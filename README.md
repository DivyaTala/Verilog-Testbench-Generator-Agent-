# Verilog Testbench Generation & Mutant Detection Agent

## Introduction

Modern hardware verification requires testing multiple candidate designs (mutants) against a specification to identify the correct implementation. Manual testbench creation is time-consuming and error-prone, especially for complex designs involving sequential logic and clock domain crossing (CDC).

This project implements an **AI-driven agent-based pipeline** that:

* Automatically generates a SystemVerilog testbench from a specification using Codex
* Compiles and simulates multiple RTL mutants using Icarus Verilog
* Iteratively refines the testbench based on feedback
* Identifies the correct design among candidates

---

## Pipeline Overview

The system follows these stages:

1. **Specification Input** → Read design requirements from Markdown spec
2. **Testbench Generation** → Codex generates a SystemVerilog testbench
3. **Compilation & Simulation** → Icarus Verilog evaluates all mutants
4. **Feedback Generation** → Results stored in `feedback.md`
5. **Refinement Loop** → Codex improves the testbench
6. **Final Output** → Best testbench and results are saved

---

## How to Run Locally

### Step 1: Clone the repository

```bash
git clone <your-repo-link>
cd codex_verilog_tb_full
```

---

### Step 2: Update inputs

* Replace the specification file:

```text
specs/my_spec.md
```

* Replace mutant design files:

```text
mutants/*.v
```

---

### Step 3: Install requirements

```bash
pip install -r requirements.txt
```

Install additional tools:

* Node.js + Codex CLI
* Icarus Verilog (`iverilog`, `vvp`)

---

### Step 4: Run the full pipeline

```bash
python run.py
```

---

## Understanding the Output

After execution, check:

```text
output/final_testbench.sv        → Final refined testbench
logs/final_feedback.md           → Evaluation and refinement feedback
logs/metrics.txt                 → Runtime and iteration details
```

👉 These files help you understand:

* how the system evaluated mutants
* how the testbench evolved
* whether a correct design was identified

---

## Manual Execution (Optional)

### Step 1: Generate the testbench with Codex

```bash
python .\generate_testbench.py --spec .\specs\my_spec.md --outdir .\generated --tb-name tb_my_design --top-module my_dut
```

This creates:

```text
generated\tb_my_design.sv
generated\README_TESTBENCH.md
```

---

### Step 2: Run mutants through Icarus

```bash
python .\tools\mutant_harness.py --repo-root . --tb .\generated\tb_my_design.sv --tb-top tb_my_design --spec .\specs\my_spec.md --candidate .\mutants\mutant1.v --candidate .\mutants\mutant2.v --candidate .\mutants\mutant3.v
```

If mutants are directories:

```bash
python .\tools\mutant_harness.py --repo-root . --tb .\generated\tb_my_design.sv --tb-top tb_my_design --spec .\specs\my_spec.md --candidate .\mutants\mutant1 --candidate .\mutants\mutant2 --candidate .\mutants\mutant3
```

---

### The harness will:

* Compile each candidate using `iverilog`
* Run simulation using `vvp`
* Detect correctness via `TB_PASS`
* Generate `feedback.md`
* Refine the testbench using Codex if needed

---

## Testbench Requirements

The generated testbench should:

* Print exactly one `TB_PASS` line when correct
* Use `$error` or `$fatal` on mismatches
* Avoid waveform-based verification
* Be deterministic for reliable evaluation

---

## Workflow Summary

```text
Spec → Codex → Testbench → Icarus → Feedback → Refinement → Final Output
```

---

## Hidden Testcases

To test new problems:

1. Replace:

```text
specs/my_spec.md
mutants/*
```

2. Run:

```bash
python run.py
```

---

## Reproducibility

The system is fully automated:

```text
clone → install → run
```

No manual intervention is required.

---

## Project Structure

```text
repo/
├── run.py
├── generate_testbench.py
├── tools/
│   └── mutant_harness.py
├── specs/
├── mutants/
├── generated/
├── logs/
├── output/
├── README.md
├── requirements.txt
```

---
