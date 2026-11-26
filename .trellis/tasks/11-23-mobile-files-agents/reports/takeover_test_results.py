"""Summarize Flutter JSON events from a downloaded Actions job log."""

import argparse
import json
from pathlib import Path
import sys

sys.stdout.reconfigure(encoding="utf-8")
parser = argparse.ArgumentParser()
parser.add_argument("log", type=Path)
parser.add_argument("--output", type=Path)
args = parser.parse_args()
suites, tests, results, errors, prints = {}, {}, {}, {}, {}
last_time = 0
done = None
for line in args.log.read_text(encoding="utf-8", errors="replace").splitlines():
    start = line.find('{"')
    if start < 0:
        continue
    try:
        event = json.loads(line[start:])
    except ValueError:
        continue
    kind = event.get("type")
    last_time = max(last_time, event.get("time", 0))
    if kind == "suite":
        suites[event["suite"]["id"]] = event["suite"].get("path", "")
    elif kind == "testStart":
        tests[event["test"]["id"]] = event["test"]
    elif kind == "testDone":
        results[event["testID"]] = event
    elif kind == "error":
        errors.setdefault(event["testID"], []).append(event.get("error", ""))
    elif kind == "print" and "EXCEPTION CAUGHT" in event.get("message", ""):
        prints.setdefault(event.get("testID"), []).append(event["message"])
    elif kind == "done":
        done = event

failures = [tid for tid, result in results.items()
            if not result.get("hidden") and result.get("result") != "success"]
unfinished = [tid for tid in tests if tid not in results]
lines = [f"# {args.log.stem}", "",
         f"Started: {len(tests)}. Completed: {len(results)}. "
         f"Failed: {len(failures)}. Unfinished: {len(unfinished)}.",
         f"Last event: {last_time / 1000:.1f}s. Final event: {done}.", ""]
for tid in failures + unfinished:
    test = tests.get(tid, {})
    state = results.get(tid, {}).get("result", "unfinished")
    lines += [f"## {state}: {suites.get(test.get('suiteID'), '')}", "",
              test.get("name", f"test {tid}"), ""]
    lines += errors.get(tid, []) + prints.get(tid, []) + [""]
text = "\n".join(lines)
if args.output:
    args.output.write_text(text + "\n", encoding="utf-8")
print(text)
