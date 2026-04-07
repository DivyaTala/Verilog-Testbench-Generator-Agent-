import subprocess
import sys

def main():
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
    sys.exit(result.returncode)

if __name__ == "__main__":
    main()