#!/usr/bin/env python3
"""Record the capacity UI case in an already-installed, isolated Simulator QA app.

Does not install/uninstall apps, change device settings, or touch the store app.
Use a dedicated simulator with no pending QA file job. See README.md.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import signal
import subprocess
import time
import uuid

BUNDLE = "org.gewill.OpenCCman.WhatsNewUITests"


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True, help="Dedicated, booted Simulator UDID")
    parser.add_argument("--mode", choices=["baseline", "candidate", "disabled"], required=True)
    parser.add_argument("--language", choices=["en", "zh-Hans", "zh-Hant"], required=True)
    parser.add_argument("--bytes", type=int, required=True)
    parser.add_argument("--xctestrun", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not 100 * 1024 * 1024 < args.bytes <= 1024 * 1024 * 1024:
        parser.error("This UI case requires an input above 100 MiB and at most 1 GiB")
    original = args.xctestrun.resolve()
    configuration = plistlib.loads(original.read_bytes())
    target = configuration["WhatsNewPresentationTests"]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    container = Path(subprocess.check_output([
        "xcrun", "simctl", "get_app_container", args.device, BUNDLE, "data"], text=True).strip())
    fixtures = container / "Documents" / ("capacity-ui-" + str(uuid.uuid4()))
    fixtures.mkdir()
    fixture = fixtures / f"OpenCCman-{args.bytes}-bytes.txt"
    unit = "鼠标里面的硅二极管坏了……头发干杯显存\0👨‍👩‍👧‍👦e\u0301\r\n\n".encode()
    block = unit * (262144 // len(unit))
    with fixture.open("xb") as stream:
        remaining = args.bytes
        while remaining >= len(block):
            stream.write(block)
            remaining -= len(block)
        stream.write(b"a" * remaining)
    before = digest(fixture)
    target.setdefault("EnvironmentVariables", {}).update({
        "OPENCCMAN_MOBILE_FIXTURE": str(fixture),
        "OPENCCMAN_MOBILE_CAPACITY_UI": args.mode,
        "OPENCCMAN_MOBILE_LANGUAGE": args.language,
    })
    # Keep __TESTROOT__ relative to the built test products.
    runfile = original.with_name("capacity-" + str(uuid.uuid4()) + ".xctestrun")
    runfile.write_bytes(plistlib.dumps(configuration))
    result = None
    started = time.monotonic()
    with (output / "record.log").open("w") as recording_log:
        recording = subprocess.Popen([
            "xcrun", "simctl", "io", args.device, "recordVideo", "--codec=h264",
            str(output / "interaction.mp4")], stdout=recording_log, stderr=subprocess.STDOUT)
        try:
            with (output / "test.log").open("w") as log:
                result = subprocess.run([
                    "xcodebuild", "test-without-building", "-xctestrun", str(runfile),
                    "-destination", f"platform=iOS Simulator,id={args.device}",
                    "-parallel-testing-enabled", "NO",
                    "-only-testing:WhatsNewPresentationTests/WhatsNewPresentationTests/testMobileExperimentalCapacityFlow",
                    "-resultBundlePath", str(output / "Result.xcresult")],
                    stdout=log, stderr=subprocess.STDOUT, timeout=300)
        finally:
            if recording.poll() is None:
                recording.send_signal(signal.SIGINT)
            recording.wait(timeout=30)
            runfile.unlink()
            after = digest(fixture)
            (output / "run.json").write_text(json.dumps({
                "mode": args.mode, "language": args.language, "input_bytes": args.bytes,
                "fixture": str(fixture), "container": str(container),
                "input_sha256_before": before, "input_sha256_after": after,
                "source_unchanged": before == after,
                "exit_code": None if result is None else result.returncode,
                "test_wall_seconds": time.monotonic() - started,
                "scope": "Simulator UI, local fixture injection and QA Pro; not signed device/provider/purchase acceptance",
            }, indent=2) + "\n")
    if before != after:
        raise RuntimeError("Source changed during UI case")
    if result is None or result.returncode:
        raise SystemExit(1 if result is None else result.returncode)
    print(f"PASS: {args.mode} {args.language}; source unchanged; {output}")


if __name__ == "__main__":
    main()
