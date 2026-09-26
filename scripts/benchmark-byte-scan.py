#!/usr/bin/env python3
"""Build a locked Release processing comparison in a new output directory.

The baseline body is preserved in ByteScanBenchmark.swift. This does not launch
the app, invoke Services, change the general clipboard, or measure UI latency.
"""
import argparse
from collections import defaultdict
import hashlib
import json
import math
from pathlib import Path
import shutil
import statistics
import subprocess


def summarize(samples_file):
    records = [json.loads(line) for line in samples_file.read_text().splitlines()]
    if not records or records[-1] != {"event": "run_completed", "samples": 280}:
        raise ValueError("Incomplete byte-scan run")
    case_records = [r for r in records if r["event"] == "case"]
    samples = [r for r in records if r["event"] == "sample"]
    key = lambda r: (r["mode"], r["representation"], r["inputBytes"])
    cases = {key(r): r for r in case_records}
    expected_keys = {(mode, representation, size)
                     for mode in ("s2t", "t2s", "s2tw", "s2twp", "s2hk", "legacy-s2t-tw-idiom", "legacy-s2hk-tw-idiom")
                     for representation in ("native", "pasteboard")
                     for size in (1_048_576, 10_485_760)}
    if set(cases) != expected_keys or len(case_records) != 28 or len(samples) != 280:
        raise ValueError("Missing or duplicate benchmark cases/samples")
    groups = defaultdict(list)
    for sample in samples:
        case = cases[key(sample)]
        elapsed = sample["elapsedMS"]
        if (sample["outputMatchesExpected"] is not True
                or sample["outputSHA256"] != case["expectedSHA256"]
                or case["expectedSHA256"] == case["inputSHA256"]
                or type(elapsed) not in (int, float) or not math.isfinite(elapsed) or elapsed <= 0):
            raise ValueError("Invalid timing or output mismatch")
        groups[key(sample) + (sample["algorithm"],)].append(sample)
    if len(groups) != 56:
        raise ValueError("Unexpected algorithm groups")
    result = []
    for case_key in cases:
        row = dict(zip(("mode", "representation", "inputBytes"), case_key))
        for algorithm in ("baseline", "current"):
            values = groups[case_key + (algorithm,)]
            if sorted(s["pair"] for s in values) != [1, 2, 3, 4, 5]:
                raise ValueError("Missing or repeated pair")
            for sample in values:
                first = "current" if sample["pair"] % 2 == 0 else "baseline"
                if sample["position"] != (0 if algorithm == first else 1):
                    raise ValueError("Unexpected pair ordering")
            times = [s["elapsedMS"] for s in values]
            row[algorithm] = {"medianMS": statistics.median(times), "minMS": min(times), "maxMS": max(times)}
        row["reductionPercent"] = (1 - row["current"]["medianMS"] / row["baseline"]["medianMS"]) * 100
        result.append(row)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--opencc-path", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    pins_file = root / "OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    pin = next(p for p in json.loads(pins_file.read_text())["pins"] if p["identity"] == "swiftyopencc")
    if args.output.exists():
        parser.error("Output already exists; choose a new directory to preserve prior samples")
    if args.opencc_path:
        dependency = args.opencc_path.resolve()
        sha = subprocess.check_output(["git", "-C", str(dependency), "rev-parse", "HEAD"], text=True).strip()
        if sha != pin["state"]["revision"]:
            parser.error("Local OpenCC revision does not match Package.resolved")
        subprocess.run(["git", "-C", str(dependency), "diff", "--quiet", "HEAD"], check=True)
        package_dependency = '.package(name: "swiftyopencc", path: ' + json.dumps(str(dependency), ensure_ascii=False) + ')'
    else:
        package_dependency = '.package(url: ' + json.dumps(pin["location"]) + ', revision: ' + json.dumps(pin["state"]["revision"]) + ')'
    output = args.output.resolve()
    output.mkdir(parents=True)
    package = output / "package"
    sources = package / "Sources/ByteScanBenchmark"
    sources.mkdir(parents=True)
    hashes = {}
    for relative in ("OpenCCman/Services/ChineseConversionService.swift", "Tests/Benchmarks/ByteScanBenchmark.swift"):
        source = root / relative
        hashes[relative] = hashlib.sha256(source.read_bytes()).hexdigest()
        shutil.copy2(source, sources / source.name)
    (package / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ByteScanBenchmark", platforms: [.macOS(.v11)],
    dependencies: [''' + package_dependency + '''],
    targets: [.executableTarget(name: "ByteScanBenchmark", dependencies: [
        .product(name: "OpenCC", package: "swiftyopencc")])])
''')
    metadata = {
        "sourceSHA": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "sourceHashes": hashes,
        "trackedChanges": subprocess.check_output(["git", "diff", "--name-only", "HEAD"], cwd=root, text=True).splitlines(),
        "dependency": pin,
        "packageResolvedSHA256": hashlib.sha256(pins_file.read_bytes()).hexdigest(),
        "swiftVersion": subprocess.check_output(["swift", "--version"], text=True).strip(),
        "baselineSourceSHA": "f8f40f2b6f85d1c5fd1c3224a745aa9e7abe1df8",
        "baselineServiceSHA256": hashlib.sha256(subprocess.check_output([
            "git", "show", "f8f40f2b6f85d1c5fd1c3224a745aa9e7abe1df8:OpenCCman/Services/ChineseConversionService.swift"
        ], cwd=root)).hexdigest(),
    }
    (output / "source.json").write_text(json.dumps(metadata, indent=2) + "\n")
    with (output / "build.log").open("x") as log:
        subprocess.run(["swift", "build", "-c", "release", "--package-path", str(package)], stdout=log, stderr=subprocess.STDOUT, check=True)
    binary_path = subprocess.check_output(["swift", "build", "-c", "release", "--show-bin-path", "--package-path", str(package)], text=True).strip()
    metadata["binarySHA256"] = hashlib.sha256((Path(binary_path) / "ByteScanBenchmark").read_bytes()).hexdigest()
    (output / "source.json").write_text(json.dumps(metadata, indent=2) + "\n")
    with (output / "samples.jsonl").open("x") as log, (output / "stderr.log").open("x") as err:
        subprocess.run([str(Path(binary_path) / "ByteScanBenchmark")], stdout=log, stderr=err, check=True)
    (output / "summary.json").write_text(json.dumps(summarize(output / "samples.jsonl"), indent=2) + "\n")
    print(f"Completed comparison: {output / 'samples.jsonl'}")


if __name__ == "__main__":
    main()
