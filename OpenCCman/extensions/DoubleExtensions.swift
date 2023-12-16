import Foundation

extension Double {
  var int: Int {
    Int(self)
  }
}

extension String {
  var int: Int? {
    Int(self)
  }

  var intValue: Int {
    self.int ?? 0
  }

  var double: Double? {
    Double(self)
  }

  var doubleValue: Double {
    self.double ?? 0
  }
}

extension Int {
  var double: Double {
    Double(self)
  }
}
