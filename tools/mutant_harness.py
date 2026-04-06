#!/usr/bin/env python3
"""Compile/simulate mutant DUTs against a Codex-generated testbench using Icarus Verilog.

The script can optionally call Codex again to refine the testbench when the result is
ambiguous or no candidate passes.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import Sequence


def run(cmd: Sequence[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    full = list(cmd)
    if os.name == "nt":
        full = ["cmd", "/c", *full]
    return subprocess.run(full, cwd=str(cwd) if cwd else None, capture_output=True, text=True)


def candidate_sources(candidate: Path) -> list[Path]:
    if candidate.is_file():
        return [candidate]
    if candidate.is_dir():
        files = sorted(candidate.glob("*.v")) + sorted(candidate.glob("*.sv"))
        if not files:
            raise FileNotFoundError(f"No .v or .sv files found in {candidate}")
        return files
    raise FileNotFoundError(f"Candidate not found: {candidate}")


def compile_and_run(
    iverilog: str,
    vvp: str,
    tb_file: Path,
    tb_top: str,
    sources: list[Path],
    build_dir: Path,
    extra_iverilog_args: list[str],
) -> dict:
    build_dir.mkdir(parents=True, exist_ok=True)

    out_vvp = build_dir / f"{sources[0].stem}.vvp"
    compile_cmd = [
        iverilog,
        *extra_iverilog_args,
        "-s",
        tb_top,
        "-o",
        str(out_vvp),
        *[str(p) for p in sources],
        str(tb_file),
    ]

    c = run(compile_cmd)
    if c.returncode != 0:
        return {
            "status": "compile_fail",
            "returncode": c.returncode,
            "stdout": c.stdout,
            "stderr": c.stderr,
            "compile_cmd": compile_cmd,
        }

    r = run([vvp, str(out_vvp)])
    combined = (r.stdout or "") + (r.stderr or "")
    passed = r.returncode == 0 and "TB_PASS" in combined and "TB_FAIL" not in combined

    return {
        "status": "pass" if passed else "sim_fail",
        "returncode": r.returncode,
        "stdout": r.stdout,
        "stderr": r.stderr,
        "compile_cmd": compile_cmd,
        "vvp_file": str(out_vvp),
    }


def write_feedback(path: Path, tb_file: Path, spec_file: Path, results: list[dict]) -> None:
    lines: list[str] = []
    lines.append("# Feedback for Codex")
    lines.append("")
    lines.append(f"- Testbench: `{tb_file.as_posix()}`")
    lines.append(f"- Spec: `{spec_file.as_posix()}`")
    lines.append("")
    lines.append("## Results")
    lines.append("")

    for item in results:
        lines.append(f"### {item['name']}")
        lines.append(f"- Status: **{item['status']}**")
        if item.get("returncode") is not None:
            lines.append(f"- Return code: `{item['returncode']}`")
        if item.get("stdout"):
            lines.append("")
            lines.append("STDOUT:")
            lines.append("```")
            lines.append(item["stdout"].rstrip())
            lines.append("```")
        if item.get("stderr"):
            lines.append("")
            lines.append("STDERR:")
            lines.append("```")
            lines.append(item["stderr"].rstrip())
            lines.append("```")
        lines.append("")

    path.write_text("\n".join(lines), encoding="utf-8")


def refine_with_codex(repo_root: Path, spec_rel: str, tb_rel: str, feedback_rel: str) -> None:
    prompt = (
        f"Read {spec_rel} and {feedback_rel}. "
        f"Improve {tb_rel} so it better distinguishes the correct DUT from the mutants. "
        f"Keep the testbench self-checking. "
        f"Do not modify the DUT source files. "
        f"Only edit files in the repository workspace."
    )

    c = run([
        "codex",
        "exec",
        "--full-auto",
        "--sandbox",
        "workspace-write",
        prompt,
    ], cwd=repo_root)

    if c.returncode != 0:
        if c.stdout:
            print(c.stdout)
        if c.stderr:
            print(c.stderr, file=sys.stderr)
        raise SystemExit(c.returncode)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run mutant designs through Icarus using a Codex-generated testbench.")
    parser.add_argument("--repo-root", type=Path, default=Path("."), help="Repository root")
    parser.add_argument("--tb", type=Path, required=True, help="Path to generated testbench file")
    parser.add_argument("--tb-top", required=True, help="Top module name of the testbench")
    parser.add_argument("--spec", type=Path, required=True, help="Path to the spec markdown file")
    parser.add_argument("--candidate", action="append", required=True, help="Candidate mutant file or directory. Repeat for each candidate.")
    parser.add_argument("--max-iterations", type=int, default=3, help="How many refine-and-rerun loops to allow")
    parser.add_argument("--iverilog", default="iverilog", help="iverilog command")
    parser.add_argument("--vvp", default="vvp", help="vvp command")
    parser.add_argument("--iverilog-arg", action="append", default=[], help="Extra argument to pass to iverilog. Repeat if needed.")
    parser.add_argument("--build-dir", type=Path, default=Path("runs"), help="Build/output directory")
    args = parser.parse_args()

    repo_root = args.repo_root.expanduser().resolve()
    tb_file = args.tb.expanduser().resolve()
    spec_file = args.spec.expanduser().resolve()
    build_root = args.build_dir.expanduser().resolve()
    build_root.mkdir(parents=True, exist_ok=True)

    candidates = [Path(c).expanduser().resolve() for c in args.candidate]

    for iteration in range(1, args.max_iterations + 1):
        print(f"\n=== Iteration {iteration}/{args.max_iterations} ===")
        results: list[dict] = []
        winners: list[str] = []

        for candidate in candidates:
            sources = candidate_sources(candidate)
            build_dir = build_root / f"iter_{iteration}" / candidate.stem
            result = compile_and_run(
                args.iverilog,
                args.vvp,
                tb_file,
                args.tb_top,
                sources,
                build_dir,
                args.iverilog_arg,
            )
            result["name"] = candidate.name
            result["sources"] = [str(p) for p in sources]
            results.append(result)

            status = result["status"]
            print(f"{candidate.name}: {status}")

            if status == "pass":
                winners.append(candidate.name)

        feedback_path = repo_root / "feedback.md"
        write_feedback(feedback_path, tb_file, spec_file, results)

        if len(winners) == 1:
            print(f"\nUnique winner: {winners[0]}")
            print(f"Simulation feedback written to: {feedback_path}")
            return 0

        print(f"\nAmbiguous result: {len(winners)} passing candidates.")
        print(f"Refining testbench with Codex using {feedback_path.name}...")
        refine_with_codex(
            repo_root=repo_root,
            spec_rel=str(spec_file.relative_to(repo_root)),
            tb_rel=str(tb_file.relative_to(repo_root)),
            feedback_rel=str(feedback_path.relative_to(repo_root)),
        )

    print("\nNo unique winner found after all iterations.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
