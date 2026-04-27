from pathlib import Path
import shutil
import subprocess
import sys

REPO_ROOT = Path(__file__).resolve().parent
LOGS_DIR = REPO_ROOT / "logs"
OUTPUT_DIR = REPO_ROOT / "output"
SPECS_DIR = REPO_ROOT / "specs"


def find_spec_file() -> Path:
    """Find the single spec Markdown file in specs/.
    
    - If exactly one .md file exists, use it.
    - If multiple exist, prefer the most recently modified one and warn.
    - Raises SystemExit if none found.
    """
    md_files = sorted(SPECS_DIR.glob("*.md"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not md_files:
        print(f"No .md spec files found in {SPECS_DIR}/", file=sys.stderr)
        raise SystemExit(1)
    if len(md_files) > 1:
        print(f"[warn] Multiple spec files found — using most recently modified: {md_files[0].name}")
        print(f"       Others ignored: {[p.name for p in md_files[1:]]}")
    return md_files[0]


def derive_tb_name(spec_path: Path) -> str:
    """Return testbench base name from spec filename stem.

    Examples:
        counter.md   -> tb_counter
        shiftleft.md -> tb_shiftleft
        my_spec.md   -> tb_my_spec
    """
    return f"tb_{spec_path.stem}"


def archive_outputs(tb_name: str) -> None:
    LOGS_DIR.mkdir(exist_ok=True)
    OUTPUT_DIR.mkdir(exist_ok=True)

    feedback_src = REPO_ROOT / "feedback.md"
    if feedback_src.exists():
        shutil.copy2(feedback_src, LOGS_DIR / "final_feedback.md")
        print(f"Archived feedback to {LOGS_DIR / 'final_feedback.md'}")
    else:
        print("No feedback.md found to archive")

    tb_src = REPO_ROOT / "generated" / f"{tb_name}.sv"
    if tb_src.exists():
        shutil.copy2(tb_src, OUTPUT_DIR / "final_testbench.sv")
        print(f"Archived testbench to {OUTPUT_DIR / 'final_testbench.sv'}")
    else:
        print(f"No generated/{tb_name}.sv found to archive")


def main() -> int:
    spec_path = find_spec_file()
    tb_name = derive_tb_name(spec_path)
    tb_top = spec_path.stem          # DUT module name = spec stem (e.g. "counter")

    print(f"[info] spec       : {spec_path.name}")
    print(f"[info] tb_name    : {tb_name}")
    print(f"[info] tb_top     : {tb_top}")

    mutants_dir = REPO_ROOT / "mutants"

    # Collect all .v files automatically
    mutant_files = sorted(mutants_dir.glob("*.v"))

    if not mutant_files:
        print("No mutant .v files found in mutants/ folder")
        return 1

    # Base command — tb name and tb-top are now derived from the spec
    cmd = [
        "python", "tools/mutant_harness.py",
        "--repo-root", ".",
        "--tb", f"generated/{tb_name}.sv",
        "--tb-top", tb_name,
        "--spec", str(spec_path),
    ]

    # Add each mutant as --candidate
    for m in mutant_files:
        cmd.extend(["--candidate", str(m)])

    print("\nRunning with mutants:")
    for m in mutant_files:
        print(f" - {m.name}")

    result = subprocess.run(cmd)
    if result.returncode != 0:
        return result.returncode

    archive_outputs(tb_name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())