import Testing
import ContactsUI
@testable import PigeonPlay

@Test @MainActor func coordinatorInvokesOnSelectWithIdentifier() {
    var receivedIdentifier: String?
    let coordinator = ContactPickerRepresentable.Coordinator(onSelect: { receivedIdentifier = $0 })
    let picker = CNContactPickerViewController()
    let contact = CNContact()
    coordinator.contactPicker(picker, didSelect: contact)
    #expect(receivedIdentifier == contact.identifier)
}

@Test @MainActor func coordinatorCancelDoesNotInvokeOnSelect() {
    var callCount = 0
    let coordinator = ContactPickerRepresentable.Coordinator(onSelect: { _ in callCount += 1 })
    let picker = CNContactPickerViewController()
    coordinator.contactPickerDidCancel(picker)
    #expect(callCount == 0)
}
