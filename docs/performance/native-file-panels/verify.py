"""Independently verify archived synthetic files; does not drive system panels."""
import hashlib
import json
from pathlib import Path
import zipfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    root = Path(__file__).resolve().parent
    data = root / "2026-09-16"
    manifest = json.loads((root.parent / "native-window-lifecycle" /
                           "2026-09-15-documents/preparation.json").read_text())
    for name, digest in json.loads((data / "checksums.json").read_text()).items():
        require(hashlib.sha256((data / name).read_bytes()).hexdigest() == digest,
                f"Evidence checksum differs: {name}")
    checked = []
    with zipfile.ZipFile(data / "files.zip") as archive:
        for fixture in manifest["fixtures"]:
            for kind in ("input", "expected"):
                content = archive.read("fixtures/" + fixture[kind])
                require(len(content) == fixture[kind + "_bytes"], "Fixture length")
                require(hashlib.sha256(content).hexdigest() == fixture[kind + "_sha256"],
                        "Fixture differs from historical oracle")
            expected = archive.read("fixtures/" + fixture["expected"])
            names = [f"input-{fixture['mib']}mib-converted.txt"]
            if fixture["mib"] == 10:
                names.append("input-10mib-preserved.txt")
            for name in names:
                content = archive.read("exports/" + name)
                require(content == expected, f"Saved output differs: {name}")
                require(not content.startswith(b"\xef\xbb\xbf"), "Output BOM")
                require(content.count(b"\0") == fixture["unit_repeats"], "NUL count")
                require(content.count(b"\r\n") == 3 * fixture["unit_repeats"], "CRLF count")
                checked.append(name)
        invalid = archive.read("fixtures/invalid-encoding.txt")
        require(invalid == b"\xff\xfeBAD", "Invalid fixture differs")
        try:
            invalid.decode("utf-8")
        except UnicodeDecodeError:
            pass
        else:
            raise ValueError("Invalid encoding fixture is valid")
        require(archive.read("fixtures/over-limit.txt") == b"x" * (10 * 1024 * 1024 + 1),
                "Over-limit fixture differs")
    checks = [json.loads(line) for line in (data / "file-checks.jsonl").read_text().splitlines()]
    require(checks[-1]["case"] == "cancel-system-replace-and-save", "Final case missing")
    require(checks[-1]["quota"] == {"2026-09-16": 2}, "Final recorded quota differs")
    print(json.dumps({"status": "passed", "saved_exports": checked,
                      "scope": "archived bytes and records, not a new UI run"}, indent=2))


if __name__ == "__main__":
    main()
