import Testing
@testable import PigeonPlay
import Contacts

// MARK: - canFetch

@Test func canFetchReturnsTrueForAuthorized() {
    #expect(ContactsService.canFetch(status: .authorized) == true)
}

@Test func canFetchReturnsTrueForLimited() {
    #expect(ContactsService.canFetch(status: .limited) == true)
}

@Test func canFetchReturnsFalseForDenied() {
    #expect(ContactsService.canFetch(status: .denied) == false)
}

@Test func canFetchReturnsFalseForRestricted() {
    #expect(ContactsService.canFetch(status: .restricted) == false)
}

@Test func canFetchReturnsFalseForNotDetermined() {
    #expect(ContactsService.canFetch(status: .notDetermined) == false)
}

// MARK: - keysToFetch

@Test func keysToFetchContainsExpectedKeys() {
    let keyStrings = ContactsService.keysToFetch.map { $0 as! String }
    #expect(keyStrings.contains(CNContactGivenNameKey))
    #expect(keyStrings.contains(CNContactFamilyNameKey))
    #expect(keyStrings.contains(CNContactPhoneNumbersKey))
    #expect(keyStrings.contains(CNContactEmailAddressesKey))
    #expect(keyStrings.count == 4)
}

// MARK: - digitsOnly

@Test func digitsOnlyStripsNonDigits() {
    #expect("(555) 867-5309".digitsOnly == "5558675309")
}

@Test func digitsOnlyHandlesInternationalFormat() {
    #expect("+1 555-867-5309".digitsOnly == "15558675309")
}

@Test func digitsOnlyReturnsEmptyForEmptyString() {
    #expect("".digitsOnly == "")
}

// MARK: - URL construction

@Test func callURLProducesCorrectTelURL() {
    let url = ContactsService.callURL(phone: "5558675309")
    #expect(url?.absoluteString == "tel://5558675309")
}

@Test func smsURLProducesCorrectSmsURL() {
    let url = ContactsService.smsURL(phone: "5558675309")
    #expect(url?.absoluteString == "sms://5558675309")
}

@Test func emailURLProducesCorrectMailtoURL() {
    let url = ContactsService.emailURL(address: "coach@example.com")
    #expect(url?.absoluteString == "mailto:coach@example.com")
}

@Test func callURLReturnsNilForEmptyString() {
    #expect(ContactsService.callURL(phone: "") == nil)
}

@Test func smsURLReturnsNilForEmptyString() {
    #expect(ContactsService.smsURL(phone: "") == nil)
}

@Test func emailURLReturnsNilForEmptyString() {
    #expect(ContactsService.emailURL(address: "") == nil)
}
