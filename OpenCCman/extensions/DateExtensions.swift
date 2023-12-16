import Foundation

extension Date {
  /// SwifterSwift: User’s current calendar.
  var calendar: Calendar { Calendar.current }

  /// SwifterSwift: Date string from date.
  ///
  ///     Date().string(withFormat: "dd/MM/yyyy") -> "1/12/17"
  ///     Date().string(withFormat: "HH:mm") -> "23:50"
  ///     Date().string(withFormat: "dd/MM/yyyy HH:mm") -> "1/12/17 23:50"
  ///
  /// - Parameter format: Date format (default is "yyyy-MM-dd HH:mm:ss").
  /// - Returns: date string.
  func string(withFormat format: String = "yyyy-MM-dd HH:mm:ss") -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = format
    return dateFormatter.string(from: self)
  }

  /// SwifterSwift: Yesterday date.
  ///
  ///     let date = Date() // "Oct 3, 2018, 10:57:11"
  ///     let yesterday = date.yesterday // "Oct 2, 2018, 10:57:11"
  ///
  var yesterday: Date {
    return calendar.date(byAdding: .day, value: -1, to: self) ?? Date()
  }

  /// SwifterSwift: UNIX timestamp from date.
  ///
  ///    Date().unixTimestamp -> 1484233862.826291
  ///
  var unixTimestamp: Double {
    return timeIntervalSince1970
  }
}
