import Foundation
import Darwin
let pid = pid_t(CommandLine.arguments[1])!
let stop = CommandLine.arguments[2]
print("elapsed_seconds,physical_footprint_bytes,resident_size_bytes,disk_write_bytes")
let start = Date()
while !FileManager.default.fileExists(atPath: stop) && Date().timeIntervalSince(start) < 300 {
  var info = rusage_info_v2()
  let result = withUnsafeMutablePointer(to: &info) {
    $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) }
  }
  guard result == 0 else { fputs("sampling failed\n", stderr); exit(1) }
  print("\(Date().timeIntervalSince(start)),\(info.ri_phys_footprint),\(info.ri_resident_size),\(info.ri_diskio_byteswritten)")
  fflush(stdout)
  Thread.sleep(forTimeInterval: 0.1)
}
