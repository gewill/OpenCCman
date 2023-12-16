import Foundation

/// https://stackoverflow.com/a/46057314
extension Bool {
  var intValue: Int {
    return self ? 1 : 0
  }
}

extension Int {
  var boolValue: Bool {
    return self != 0
  }
}
