# #217: forced termination of Mac file conversion

The [source and existing-target probe](report.json) uses application service
sources from `93bb152f53893b2032f585e9ee534214ee3dbe0b` and locked
SwiftyOpenCC `564b094b2b69f2c1e907fa3d89fe6845469a4e4e`. It ran on
macOS 27.0 with Xcode 27.0. The generated UTF-8 source is 20 MiB and contains
repeated `头发干杯` plus ASCII. The pre-existing target contains a fixed sentinel.
No user document or application preference is used.

The probe copies the actual `StreamingTextFileService`, `TextFileService`, and
`ChineseConversionService` into an isolated Release SwiftPM executable. Its
existing hooks stop the child either after the first successfully written
approximately 1 MiB block or after synchronizing and closing the output,
immediately before atomic commit. The parent confirms the child reached that
boundary, sends `SIGKILL`, compares full source and target hashes, then starts
a new process that converts the same source normally. Finally, it checks
whether the old staging directory survived and removes only its generated
directory after verifying its path, inode, device, and sole expected TXT file.

| Stop point | Source and existing target after kill | Staging after kill | Old staging after a new successful process |
| --- | --- | ---: | --- |
| During conversion | Both hashes unchanged | 1,048,534 bytes | Still present |
| Immediately before commit | Both hashes unchanged | 20,971,520 bytes | Still present |

The next process generated the expected full output hash in both cases. The
report retains the exact source, target, output, and binary hashes and the
staging observations. The source revision identifies the service under test;
the probe source SHA-256 additionally identifies the new test harness.

Reproduce from a checkout at the recorded source and a **clean** local
SwiftyOpenCC checkout at the lockfile SHA:

```bash
python3 scripts/probe-streaming-force-kill.py \
  --output /private/tmp/openccman-217-reproduction \
  --opencc-path /path/to/SwiftyOpenCC
```

Omit `--opencc-path` to fetch exactly the lockfile revision. The output
directory must not exist. The script preserves small logs and JSON but deletes
its generated large fixtures and verified staging directories. It fails if the
source or existing target changes on `SIGKILL`, if the normal retry returns
incorrect output, or if staging cleanup cannot verify ownership. An orphan is
reported rather than treated as a passing recovery mechanism.

This is an **unsandboxed service-level** observation. It does not prove the
signed application's behavior, startup UI, external-volume access, provider
interruption, or power-loss recovery. Those remain in [#217](https://github.com/gewill/OpenCCman/issues/217).
Apple states that replacement staging should be on the destination volume
([FileManager](https://developer.apple.com/documentation/foundation/filemanager/replaceitemat%28_%3Awithitemat%3Abackupitemname%3Aoptions%3A%29)),
and that the system gives no guarantee of when or whether it purges temporary
files ([file-system guidance](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively)).
Persistent access to user-selected files after restart requires a
[security-scoped bookmark](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox).
The app currently has no bookmark entitlement or staging journal. Scanning
arbitrary `TemporaryItems` directories on launch would not safely identify
this app's files or provide persistent access across volumes; that is not
implemented by this probe.
