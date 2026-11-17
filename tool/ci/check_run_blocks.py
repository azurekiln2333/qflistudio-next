#!/usr/bin/env python3
"""Syntax-check every bash run block in a workflow or composite action.

Usage: python tool/ci/check_run_blocks.py <file.yml> [<file.yml>...]

The workflow is parsed as YAML, each bash `run:` script is written to a
temporary file, and `bash -n` parses it. Heredoc terminators need one more
check: YAML strips their indentation, so an indented terminator reaches bash as
"          PY" and the body of the block is read as commands instead. A `cmd` or
PowerShell script is skipped and reported, so a new shell never slips past the
check in silence.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml


def walk(node):
    """Yield every mapping that holds a run key."""
    if isinstance(node, dict):
        if isinstance(node.get("run"), str):
            yield node
        for value in node.values():
            yield from walk(value)
    elif isinstance(node, list):
        for item in node:
            yield from walk(item)


def heredoc_terminators(script):
    """Report a here-document whose terminator line carries indentation.

    The workflow file indents the terminator with the rest of the script, and
    YAML block scalars strip the common indent, so the terminator arrives at
    column zero. Any earlier whitespace means the terminator is broken.
    """
    problems = []
    for match in re.finditer(r"<<-?\s*'?([A-Za-z_][A-Za-z0-9_]*)'?", script):
        terminator = match.group(1)
        for line in script.split("\n"):
            if line.strip() == terminator and line != terminator:
                problem = f"    here-document terminator '{terminator}' is indented; it must start at column 0"
                if problem not in problems:
                    problems.append(problem)
    return problems


def main(paths):
    # On Windows the bare "bash" is often the WSL stub, so BASH may be set.
    bash = os.environ.get("BASH") or shutil.which("bash")
    if bash is None:
        raise SystemExit("bash is not on PATH")

    failed = 0
    checked = 0
    skipped = 0
    for path in paths:
        text = Path(path).read_text(encoding="utf-8")
        # The `on:` key parses as the boolean True under YAML 1.1 rules. The
        # value is not inspected, so the mapping is only read for run keys.
        document = yaml.safe_load(text)
        for step in walk(document):
            script = step["run"]
            shell = step.get("shell", "bash")
            name = step.get("name", "(unnamed step)")
            if isinstance(shell, str) and not shell.startswith("bash"):
                print(f"skip {path}: {name} uses shell {shell}")
                skipped += 1
                continue
            problems = heredoc_terminators(script)
            with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False, encoding="utf-8") as handle:
                handle.write(script)
                temporary = handle.name
            result = subprocess.run(
                [bash, "-n", temporary], capture_output=True, text=True, encoding="utf-8", errors="replace"
            )
            Path(temporary).unlink()
            if result.returncode != 0:
                failed += 1
                print(f"FAIL {path}: {name}")
                print(result.stderr.rstrip())
            elif problems:
                failed += 1
                print(f"FAIL {path}: {name}")
                for problem in problems:
                    print(problem)
            else:
                checked += 1
                print(f"ok   {path}: {name}")

    print(f"\n{checked} bash run blocks parsed, {skipped} skipped, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    raise SystemExit(main(sys.argv[1:]))
