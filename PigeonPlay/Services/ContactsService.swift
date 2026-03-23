import Contacts
import Foundation

enum ContactResult {
    case found(CNContact)
    case notFound(String)
}

enum ContactsService {
    nonisolated(unsafe) static let keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
    ]

    static func authorizationStatus() -> CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    static func canFetch(status: CNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .limited:
            return true
        case .denied, .restricted, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    @MainActor static func requestAccess() async -> Bool {
        let store = CNContactStore()
        return (try? await store.requestAccess(for: .contacts)) ?? false
    }

    @MainActor static func fetchContacts(identifiers: [String]) async -> [ContactResult] {
        guard !identifiers.isEmpty else { return [] }
        let store = CNContactStore()
        return identifiers.map { id in
            do {
                let contact = try store.unifiedContact(withIdentifier: id, keysToFetch: keysToFetch)
                return .found(contact)
            } catch {
                return .notFound(id)
            }
        }
    }

    static func callURL(phone: String) -> URL? {
        let digits = phone.digitsOnly
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }

    static func smsURL(phone: String) -> URL? {
        let digits = phone.digitsOnly
        guard !digits.isEmpty else { return nil }
        return URL(string: "sms://\(digits)")
    }

    static func emailURL(address: String) -> URL? {
        guard !address.isEmpty else { return nil }
        return URL(string: "mailto:\(address)")
    }
}

extension String {
    var digitsOnly: String {
        filter(\.isNumber)
    }
}
