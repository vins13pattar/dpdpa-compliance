"""Command-line interface wrapping the DPDPA compliance scanner.

The canonical scanner lives at skills/dpdpa-compliance/scripts/audit-scan.sh
in the repository; the copy bundled in this package (data/audit-scan.sh) is
kept byte-identical by the repo test suite.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

from . import __version__

SEVERITY_ORDER = ["critical", "high", "medium", "low"]


def scanner_path() -> Path:
    bundled = Path(__file__).parent / "data" / "audit-scan.sh"
    if bundled.is_file():
        return bundled
    # Running from a repo checkout (python/src/dpdpa_audit/cli.py)
    repo = Path(__file__).resolve().parents[3] / "skills" / "dpdpa-compliance" / "scripts" / "audit-scan.sh"
    if repo.is_file():
        return repo
    raise FileNotFoundError("audit-scan.sh not found; the package may be corrupted — try reinstalling.")


def parse_counts(report_text: str) -> dict:
    """Read the summary table; use the last match of each row so content
    quoted in findings can't shadow it."""
    counts = {}
    for sev in ("Critical", "High", "Medium", "Low", "Info", "Pass"):
        matches = re.findall(r"\|\s*%s\s*\|\s*(\d+)\s*\|" % sev, report_text)
        counts[sev.lower()] = int(matches[-1]) if matches else 0
    return counts


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="dpdpa-audit",
        description=(
            "Scan a codebase for India DPDPA (DPDP Act 2023 + DPDP Rules 2025) "
            "compliance gaps. Writes a Markdown report with findings mapped to "
            "DPDPA sections, severity, and remediation. Technical guidance, "
            "not legal advice."
        ),
    )
    parser.add_argument("project_dir", nargs="?", default=".",
                        help="directory to scan (default: current directory)")
    parser.add_argument("-o", "--output", default="dpdpa-audit-report.md",
                        help="report file to write (default: dpdpa-audit-report.md)")
    parser.add_argument("--verbose", action="store_true",
                        help="include passing checks in the report")
    parser.add_argument("--fail-on", choices=["none"] + SEVERITY_ORDER, default="none",
                        help="exit non-zero if findings at or above this severity exist (CI gate)")
    parser.add_argument("-v", "--version", action="version", version=__version__)
    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)

    if not Path(args.project_dir).is_dir():
        print(f"dpdpa-audit: directory '{args.project_dir}' does not exist.", file=sys.stderr)
        return 2

    if shutil.which("bash") is None:
        print(
            "dpdpa-audit: bash is required but was not found on PATH."
            " On Windows, install Git for Windows (Git Bash) or WSL.",
            file=sys.stderr,
        )
        return 2

    cmd = ["bash", str(scanner_path()), args.project_dir, args.output]
    if args.verbose:
        cmd.append("--verbose")
    result = subprocess.run(cmd)
    if result.returncode != 0:
        return result.returncode

    if args.fail_on != "none":
        counts = parse_counts(Path(args.output).read_text(encoding="utf-8"))
        gated = SEVERITY_ORDER[: SEVERITY_ORDER.index(args.fail_on) + 1]
        total = sum(counts[sev] for sev in gated)
        if total > 0:
            print(
                f"\ndpdpa-audit: {total} finding(s) at or above severity "
                f'"{args.fail_on}" — failing (--fail-on {args.fail_on}).',
                file=sys.stderr,
            )
            return 1
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
