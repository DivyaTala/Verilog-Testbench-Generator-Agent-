from pathlib import Path
import shutil
import subprocess
import sys

REPO_ROOT = Path(__file__).resolve().parent
LOGS_DIR = REPO_ROOT / "logs"
OUTPUT_DIR = REPO_ROOT / "output"


def archive_outputs() -> None:
    LOGS_DIR.mkdir(exist_ok=True)
    OUTPUT_DIR.mkdir(exist_ok=True)

    feedback_src = REPO_ROOT / "feedback.md"
    if feedback_src.exists():
        shutil.copy2(feedback_src, LOGS_DIR / "final_feedback.md")

    tb_src = REPO_ROOT / "generated" / "tb_counter.sv"
    if tb_src.exists():
        shutil.copy2(tb_src, OUTPUT_DIR / "final_testbench.sv")

    tb_readme = REPO_ROOT / "generated" / "README_TESTBENCH.md"
    if tb_readme.exists():
        shutil.copy2(tb_readme, OUTPUT_DIR / "README_TESTBENCH.md")


def main() -> int:
    cmd = [
        "python", "tools/mutant_harness.py",
        "--repo-root", ".",
        "--tb", "generated/tb_counter.sv",
        "--tb-top", "tb_counter",
        "--spec", "specs/my_spec.md",
        "--candidate", "mutants/mutant_0.v",
        "--candidate", "mutants/mutant_1.v",
        "--candidate", "mutants/mutant_3.v",
    ]

    result = subprocess.run(cmd)
    if result.returncode != 0:
        return result.returncode

    archive_outputs()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())