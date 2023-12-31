import SwiftUI

protocol Pickable: Identifiable {
  var title: LocalizedStringKey { get }
}

struct PickableView<T: Pickable>: View {
  var title: LocalizedStringKey?
  var options: [T] = []
  var initialContent: T?
  var allowCancelSelect: Bool = false
  var didSelect: (T) -> Void

  @State var selectionIndex: Int = -1
  var currentContent: T? {
    if selectionIndex == -1 {
      return nil
    } else {
      return options[selectionIndex]
    }
  }

  init(
    title: LocalizedStringKey? = nil,
    options: [T],
    initialContent: T? = nil,
    allowCancelSelect: Bool = false,
    didSelect: @escaping (T) -> Void
  ) {
    self.title = title
    self.options = options
    self.initialContent = initialContent
    self.allowCancelSelect = allowCancelSelect
    self.didSelect = didSelect
    if let initialContent {
      let initialIndex = options.firstIndex(where: { $0.id == initialContent.id }) ?? -1
      _selectionIndex = .init(initialValue: initialIndex)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Padding.verLarge) {
      if let title {
        Text(title).font(.headline)
      }
      ScrollView {
        VStack(spacing: Padding.normal) {
          ForEach(0 ..< options.count, id: \.self) { index in
            PickableSingleChoiceView(
              title: options[index].title,
              allowCancelSelect: allowCancelSelect,
              selected: binding(for: index)
            )
            if index < options.count - 1 {
              Divider()
            }
          }
        }
      }
      .softRectangleStyle()
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  func binding(for index: Int) -> Binding<Bool> {
    return Binding<Bool> {
      selectionIndex == index
    } set: { newValue in
      selectionIndex = newValue ? index : -1
      if let currentContent = currentContent {
        didSelect(currentContent)
      }
    }
  }
}

struct PickableSingleChoiceView: View {
  var title: LocalizedStringKey
  var allowCancelSelect: Bool = false
  @Binding var selected: Bool

  var color: Color {
    selected ? Color.accentColor : Color.primary
  }

  var body: some View {
    VStack {
      HStack {
        Text(title)
          .frame(maxWidth: .infinity, alignment: .leading)
        if selected {
          Image(systemName: "checkmark")
            .foregroundColor(color)
        } else {
//          Image(systemName: "circle")
//            .foregroundColor(color)
        }
      }
      .contentShape(Rectangle())
      .onTapGesture {
        if allowCancelSelect {
          selected.toggle()
        } else {
          if selected == false {
            selected = true
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
  }
}

struct DemoItem: Pickable {
  var id = UUID()
  var title: LocalizedStringKey = ""
}

struct PickableDemoView: View {
  @State var selection: Int = 0
  @State var showPicker: Bool = false
  @State var selectionContent: String = ""

  let options: [DemoItem] = ["one", "two", "three"].map { DemoItem(title: $0) }

  var body: some View {
    VStack {
      Text("selectionContent: " + selectionContent)
      Toggle("show picker", isOn: $showPicker)
      PickableView(
        title: "Title",
        options: options,
        initialContent: options.last
      ) { item in
        print(item)
      }
    }
    .padding()
  }
}

#Preview {
  PickableDemoView()
}
