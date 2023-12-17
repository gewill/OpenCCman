import SwiftUI

struct AlertView<Actions: View>: View {
  var title: LocalizedStringKey
  var subtitle: LocalizedStringKey
  let actions: Actions

  init(title: LocalizedStringKey, subtitle: LocalizedStringKey, @ViewBuilder actions: @escaping () -> Actions) {
    self.title = title
    self.subtitle = subtitle
    self.actions = actions()
  }

  var body: some View {
    ZStack(alignment: .center) {
//      Color.black.opacity(0.3)
      VStack(spacing: 10) {
        Text(title)
          .font(.title)
        Text(subtitle)
          .font(.body)
        Spacer()
        actions
      }
      .frame(width: 271, height: 181)
      .padding(Constant.padding)
      .softRectangleStyle()
    }
  }
}

struct AlertViewModifier<Actions: View>: ViewModifier {
  var title: LocalizedStringKey
  var subtitle: LocalizedStringKey
  @Binding var isPresented: Bool
  let actions: Actions

  init(title: LocalizedStringKey, subtitle: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> Actions) {
    self.title = title
    _isPresented = isPresented
    self.subtitle = subtitle
    self.actions = actions()
  }

  func body(content: Content) -> some View {
    ZStack {
      content
      if isPresented {
        AlertView(title: title, subtitle: subtitle) {
          actions
        }
      }
    }
  }
}

extension View {
  func alertView<A>(title: LocalizedStringKey, subtitle: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: @escaping () -> A) -> some View where A: View {
    modifier(AlertViewModifier(title: title, subtitle: subtitle, isPresented: isPresented, actions: actions))
  }
}

struct AlertViewBox: View {
  @State private var showingAlert = false
  @State private var showGradient = true
  var body: some View {
    ZStack {
      if showGradient {
        AngularGradient(gradient: Gradient(colors: [.red, .yellow, .green, .blue, .purple, .red]), center: .center)
      }
      Button(action: {
        showingAlert.toggle()
      }, label: {
        Text("Show Alert")
      })
    }
    .alertView(title: "Delete", subtitle: "Are you sure to delete this record?", isPresented: $showingAlert) {
      HStack(spacing: 10) {
        Button {
          showingAlert.toggle()
          showGradient.toggle()
        } label: {
          Text("Delete")
            .frame(width: 120, height: 44)
        }
        .softButtonStyle(RoundedRectangle(cornerRadius: 20), padding: 0, textColor: Color.pink)
        Button {
          showingAlert.toggle()
        } label: {
          Text("Cancel")
            .frame(width: 120, height: 44)
        }
        .softButtonStyle(RoundedRectangle(cornerRadius: 20), padding: 0)
      }
    }
  }
}

struct AlertView_Previews: PreviewProvider {
  static var previews: some View {
    AlertViewBox()
      .environment(\.locale, Locale(identifier: LocaleConstants.zh_Hans.rawValue))
  }
}
