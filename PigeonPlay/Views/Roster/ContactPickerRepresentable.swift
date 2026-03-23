import ContactsUI
import SwiftUI

struct ContactPickerRepresentable: UIViewControllerRepresentable {
    var onSelect: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // UINavigationController wrapper required — bare picker shows empty sheet
        return UINavigationController(rootViewController: picker)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var onSelect: (String) -> Void
        init(onSelect: @escaping (String) -> Void) { self.onSelect = onSelect }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact.identifier)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {}
    }
}
