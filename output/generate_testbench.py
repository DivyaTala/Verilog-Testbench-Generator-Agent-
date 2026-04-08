#!/usr/bin/env python3
"""Run OpenAI Codex from Python to generate a Verilog/SystemVerilog testbench."""
from __future__ import annotations

import argparse
import datetime as dt
import os
import shutil
import subprocess
import sys
from pathlib import Path


def run(cmd: list[str], cwd: Path | None = None) -> None:
    print(f"[run] {' '.join(cmd)}")
    if os.name == "nt":
        completed = subprocess.run(["cmd", "/c", *cmd], cwd=str(cwd) if cwd else None)
    else:
        completed = subprocess.run(cmd, cwd=str(cwd) if cwd else None)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="replace")


def ensure_git_repo(repo_dir: Path) -> None:
    if (repo_dir / ".git").exists():
        return
    run(["git", "init"], cwd=repo_dir)
    run(["git", "branch", "-M", "main"], cwd=repo_dir)


def build_prompt(spec_text: str, tb_name: str, top_module: str, language: str) -> str:
    ext = "sv" if language.lower().startswith("system") else "v"
    return f"""You are generating a {language} testbench from a Markdown spec.

Target DUT name: {top_module}
Requested testbench file name: {tb_name}

Read SPEC.md and generate:
1. generated/{tb_name}.{ext}
2. generated/README_TESTBENCH.md

Requirements:
- Use explicit named port connections.
- Add a clock if needed.
- Add reset if needed.
- Make the testbench self-checking when possible.
- Keep the DUT behavior faithful to the spec.
- Document all assumptions in README_TESTBENCH.md.
- Do not modify SPEC.md.
- Do not edit files outside generated/ unless required for a minimal test harness.
- Print exactly one line containing TB_PASS when all checks pass.
- Use $error or $fatal on mismatches.

SPEC.md:
---
{spec_text}
---
"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a Verilog/SystemVerilog testbench with Codex.")
    parser.add_argument("--spec", required=True, type=Path, help="Path to the Markdown spec file")
    parser.add_argument("--outdir", required=True, type=Path, help="Directory to copy generated files into")
    parser.add_argument("--tb-name", default="testbench", help="Base name for the generated testbench file")
    parser.add_argument("--top-module", required=True, help="Name of the DUT top module")
    parser.add_argument("--language", default="systemverilog", choices=["verilog", "systemverilog"], help="Output HDL language")
    parser.add_argument("--codex-extra-args", nargs=argparse.REMAINDER, default=[], help="Extra args passed to codex exec after --")
    args = parser.parse_args()

    spec_path: Path = args.spec.expanduser().resolve()
    if not spec_path.is_file():
        print(f"Spec file not found: {spec_path}", file=sys.stderr)
        return 2

    outdir: Path = args.outdir.expanduser().resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    timestamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    workdir = outdir / f".codex_work_{spec_path.stem}_{timestamp}"
    if workdir.exists():
        shutil.rmtree(workdir)
    workdir.mkdir(parents=True)
    (workdir / "generated").mkdir(parents=True, exist_ok=True)

    copied_spec = workdir / "SPEC.md"
    shutil.copy2(spec_path, copied_spec)

    local_agents = Path(__file__).with_name("AGENTS.md")
    if local_agents.exists():
        shutil.copy2(local_agents, workdir / "AGENTS.md")

    ensure_git_repo(workdir)

    prompt = build_prompt(read_text(copied_spec), args.tb_name, args.top_module, args.language)
    prompt_file = workdir / "PROMPT.txt"
    prompt_file.write_text(prompt, encoding="utf-8")

    tb_ext = "sv" if args.language == "systemverilog" else "v"
    output_tb = workdir / "generated" / f"{args.tb_name}.{tb_ext}"
    output_readme = workdir / "generated" / "README_TESTBENCH.md"

    cmd = ["codex", "exec", "--full-auto", "--sandbox", "workspace-write"]
    if args.codex_extra_args:
        cmd.extend(args.codex_extra_args)
    cmd.append(prompt)

    print(f"Workspace: {workdir}")
    print(f"Spec copied to: {copied_spec}")
    print("Launching Codex...\n")
    run(cmd, cwd=workdir)

    for produced in [output_tb, output_readme]:
        if produced.exists():
            shutil.copy2(produced, outdir / produced.name)

    generated_dir = workdir / "generated"
    for item in generated_dir.iterdir():
        if item.is_file() and item.name not in {output_tb.name, output_readme.name}:
            shutil.copy2(item, outdir / item.name)

    print("\nDone.")
    print(f"Main testbench: {outdir / output_tb.name}")
    print(f"README: {outdir / output_readme.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
