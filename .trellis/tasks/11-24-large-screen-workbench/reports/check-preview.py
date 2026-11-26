"""Static checks for the planning mockup; never execute product code."""
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import subprocess

task = Path(__file__).resolve().parents[1]
fragment = (task / "workbench-preview.html").read_text(encoding="utf-8")
assert not re.search(r"<!doctype|<html\b|<head\b|<body\b", fragment, re.I)
assert len(fragment.encode("utf-8")) < 1024 * 1024
assert '\\"' not in fragment
assert not re.search(r"\bfetch\s*\(|XMLHttpRequest|WebSocket", fragment)

class Structure(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.attrs = []
        self.scripts = []
        self.in_script = False

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if "id" in attributes:
            assert attributes["id"] not in self.ids
            self.ids.add(attributes["id"])
        self.attrs.append(attributes)
        if tag == "script":
            assert "src" not in attributes
            self.in_script = True
            self.scripts.append("")

    def handle_endtag(self, tag):
        if tag == "script":
            self.in_script = False

    def handle_data(self, data):
        if self.in_script:
            self.scripts[-1] += data

structure = Structure()
structure.feed(fragment)
assert structure.ids == {"qfli-workbench-preview", "qfli-phone-preview"}
assert {a["data-section"] for a in structure.attrs if "data-section" in a} == {
    "projects", "files", "agents"
}
assert {a["data-pane"] for a in structure.attrs if "data-pane" in a} == {
    "projects", "files", "agents"
}
assert len(structure.scripts) == 1
result = subprocess.run(
    ["node", "--check"],
    input=structure.scripts[0],
    text=True,
    capture_output=True,
    encoding="utf-8",
    timeout=20,
)
if result.returncode:
    raise SystemExit(result.stderr)
for name in ("implement.jsonl", "check.jsonl"):
    for line in (task / name).read_text(encoding="utf-8").splitlines():
        entry = json.loads(line)
        assert entry["file"] and entry["reason"]
        assert (task.parents[2] / entry["file"]).is_file(), entry["file"]
report = {
    "fragment_structure": "pass",
    "script_syntax": "pass",
    "manifest_paths": "pass",
    "browser_rendered": False,
    "product_tests_run_locally": False,
    "native_folder_drop_tested": False,
}
(task / "reports" / "preview-static-check.json").write_text(
    json.dumps(report, indent=2) + "\n", encoding="utf-8"
)
print(json.dumps(report))
