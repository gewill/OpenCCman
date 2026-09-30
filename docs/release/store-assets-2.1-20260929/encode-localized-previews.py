#!/usr/bin/env python3
"""Encode the six localized previews from archived real recordings."""

import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parent
edits = json.loads((root / "localized-preview-edits.json").read_text())

for output in edits["outputs"]:
    destination = root / output["output"]
    destination.parent.mkdir(parents=True, exist_ok=True)
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]
    filters = []
    width, height = output["size"]
    for index, segment in enumerate(output["segments"]):
        command += ["-ss", str(segment["start"]), "-t", str(segment["duration"]),
                    "-i", str(root / segment["input"])]
        crop = ""
        if "crop" in output:
            crop = "crop=" + ":".join(map(str, output["crop"])) + ","
        filters.append(
            f"[{index}:v]setpts=PTS-STARTPTS,fps=30,{crop}"
            f"scale={width}:{height}:force_original_aspect_ratio=decrease:force_divisible_by=2,"
            f"pad={width}:{height}:(ow-iw)/2:(oh-ih)/2:color=0xeaf0f4,"
            f"setsar=1,format=yuv420p[v{index}]"
        )
    count = len(output["segments"])
    filters.append("".join(f"[v{i}]" for i in range(count)) +
                   f"concat=n={count}:v=1:a=0[video]")
    duration = sum(segment["duration"] for segment in output["segments"])
    command += ["-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
                "-filter_complex_threads", "2", "-filter_complex", ";".join(filters),
                "-map", "[video]", "-map", f"{count}:a", "-t", str(duration),
                "-c:v", "libx264", "-threads", "4", "-preset", "medium", "-crf", "20",
                "-profile:v", "high", "-level:v", "4.0", "-pix_fmt", "yuv420p",
                "-c:a", "aac", "-b:a", "128k", "-ar", "48000", "-ac", "2",
                "-movflags", "+faststart", str(destination)]
    subprocess.run(command, check=True)
    print(f"Encoded {output['output']} ({duration:g}s)", flush=True)
