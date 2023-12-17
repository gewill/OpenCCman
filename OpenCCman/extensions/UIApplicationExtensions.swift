#if os(iOS)
  import UIKit

  extension UIApplication {
    func endEditing() {
      sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
  }
#endif
