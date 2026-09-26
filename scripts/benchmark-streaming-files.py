#!/usr/bin/env python3
"""Build the actual file service and measure complete, hash-verified outputs.

Uses an isolated SwiftPM executable and fresh processes. Never loads large text
into an editor and never changes application preferences.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import shutil
import stat
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [
    "OpenCCman/Services/ChineseConversionService.swift",
    "OpenCCman/Services/TextFileService.swift",
    "OpenCCman/Services/StreamingTextFileService.swift",
    "Tests/Benchmarks/StreamingFileBenchmark.swift",
]


def cleanup_staging(registry):
    """Remove only the generated directory identities recorded by this child."""
    if not registry.exists():
        return
    for item in json.loads(registry.read_text()):
        directory = Path(item["path"])
        try:
            current = directory.lstat()
        except FileNotFoundError:
            continue
        if (not directory.is_absolute() or not stat.S_ISDIR(current.st_mode)
                or current.st_dev != item["device"] or current.st_ino != item["inode"]):
            raise RuntimeError(f"Generated staging identity changed; preserving {directory}")
        shutil.rmtree(directory)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--opencc-path", required=True, type=Path)
    parser.add_argument("--sizes-mib", nargs="+", type=int, default=[10, 20, 50, 100, 1024])
    parser.add_argument("--corpora", nargs="+", choices=["single", "multiline", "unmatched"], default=["single", "multiline"])
    parser.add_argument("--samples", type=int, default=3)
    parser.add_argument("--timeout", type=int, default=300)
    args = parser.parse_args()
    if args.samples < 1 or any(size <= 0 or size > 1024 for size in args.sizes_mib):
        parser.error("Require positive samples and file sizes up to 1024 MiB")
    args.output.mkdir(parents=True, exist_ok=False)
    package = args.output / "package"
    sources = package / "Sources/StreamingFileBenchmark"
    sources.mkdir(parents=True)
    hashes = {}
    for relative in SOURCES:
        path = ROOT / relative
        shutil.copy2(path, sources / path.name)
        hashes[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    revision = subprocess.check_output(["git", "-C", str(args.opencc_path), "rev-parse", "HEAD"], text=True).strip()
    lock = json.loads((ROOT / "OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved").read_text())
    pin = next(p["state"]["revision"] for p in lock["pins"] if p["identity"] == "swiftyopencc")
    if revision != pin:
        raise SystemExit("Local wrapper revision must match Package.resolved")
    wrapper_files = [p for folder in ["Sources", "Tests"] for p in (args.opencc_path / folder).rglob("*") if p.is_file()]
    metadata = {
        "protocol": 2, "app_sha": subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip(),
        "wrapper_sha": revision, "source_sha256": hashes,
        "opencc_sha": subprocess.check_output(["git", "-C", str(args.opencc_path), "rev-parse", "HEAD:OpenCC"], text=True).strip(),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "wrapper_source_sha256": {str(p.relative_to(args.opencc_path)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(wrapper_files)},
        "platform": platform.platform(), "samples": args.samples, "sizes_mib": args.sizes_mib, "corpora": args.corpora,
        "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
        "app_worktree_status": subprocess.check_output(["git", "-C", str(ROOT), "status", "--short"], text=True),
        "wrapper_worktree_status": subprocess.check_output(["git", "-C", str(args.opencc_path), "status", "--short"], text=True),
    }
    (args.output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    (package / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "StreamingFileBenchmark", platforms: [.macOS(.v12)],
  dependencies: [.package(name: "swiftyopencc", path: ''' + json.dumps(str(args.opencc_path.resolve())) + ''')],
  targets: [.executableTarget(name: "StreamingFileBenchmark", dependencies: [.product(name: "OpenCC", package: "swiftyopencc")])])
''')
    with (args.output / "build.log").open("w") as log:
        subprocess.run(["swift", "build", "-c", "release", "--package-path", str(package)], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
    binary = package / ".build/release/StreamingFileBenchmark"
    metadata["binary_sha256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
    (args.output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    fixtures = args.output / "fixtures"
    fixtures.mkdir()
    for size in args.sizes_mib:
        for corpus in args.corpora:
            for sample in range(1, args.samples + 1):
                name = f"{size:04d}mib-{corpus}-{sample:02d}"
                # Python owns precisely this generated fixture directory. Its
                # context cleans input/output on timeout or a crashed child too.
                with tempfile.TemporaryDirectory(prefix=name + "-", dir=fixtures) as directory:
                    try:
                        subprocess.run([str(binary), str(size * 1024 * 1024), corpus, directory, str(args.output / f"{name}.json")], check=True, timeout=args.timeout)
                    finally:
                        # itemReplacementDirectory may live outside fixtures on
                        # the same volume; clean only this child's recorded IDs.
                        cleanup_staging(Path(directory) / "staging.json")
    metadata["completed_at"] = datetime.now(timezone.utc).isoformat()
    (args.output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"PASS: fresh-process streaming file evidence: {args.output}")


if __name__ == "__main__":
    main()
