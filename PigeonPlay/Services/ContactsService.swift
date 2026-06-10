import Contacts
import Foundation

/// The slice of a CNContact the app displays. Sendable, so fetches can
/// run off the main actor; views never see CNContact.
struct ContactInfo: Equatable, Sendable {
    let identifier: String
    let givenName: String
    let familyName: String
    let phone: String?
    let email: String?

    var displayName: String {
        [givenName, familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    init(contact: CNContact) {
        identifier = contact.identifier
        givenName = contact.givenName
        familyName = contact.familyName
        phone = contact.phoneNumbers.first?.value.stringValue
        email = contact.emailAddresses.first?.value as String?
    }

    init(identifier: String, givenName: String, familyName: String, phone: String? = nil, email: String? = nil) {
        self.identifier = identifier
        self.givenName = givenName
        self.familyName = familyName
        self.phone = phone
        self.email = email
    }
}

enum ContactsService {
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

    static func requestAccess() async -> Bool {
        let store = CNContactStore()
        return (try? await store.requestAccess(for: .contacts)) ?? false
    }

    /// Fetches contact details keyed by identifier. Identifiers that no
    /// longer resolve to a contact are absent from the result.
    /// Nonisolated so the synchronous CNContactStore lookups run off the
    /// caller's actor.
    static func fetchContacts(identifiers: [String]) async -> [String: ContactInfo] {
        guard !identifiers.isEmpty else { return [:] }
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
        ]
        let store = CNContactStore()
        var results: [String: ContactInfo] = [:]
        for id in identifiers {
            if let contact = try? store.unifiedContact(withIdentifier: id, keysToFetch: keysToFetch) {
                results[id] = ContactInfo(contact: contact)
            }
        }
        return results
    }

    static func callURL(phone: String) -> URL? {
        let digits = phone.phoneDigits
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:\(digits)")
    }

    static func smsURL(phone: String) -> URL? {
        let digits = phone.phoneDigits
        guard !digits.isEmpty else { return nil }
        return URL(string: "sms:\(digits)")
    }

    static func emailURL(address: String) -> URL? {
        guard !address.isEmpty else { return nil }
        return URL(string: "mailto:\(address)")
    }
}

extension String {
    /// The dialable form of a phone number: digits plus a leading "+" if
    /// present, so international numbers keep their country-code prefix.
    var phoneDigits: String {
        let trimmed = trimmingCharacters(in: .whitespaces)
        let digits = trimmed.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        return trimmed.hasPrefix("+") ? "+" + digits : digits
    }
}
