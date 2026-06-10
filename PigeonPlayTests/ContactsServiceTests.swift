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

// MARK: - ContactInfo

@Test func contactInfoExtractsFieldsFromCNContact() {
    let contact = CNMutableContact()
    contact.givenName = "Pat"
    contact.familyName = "Walsh"
    contact.phoneNumbers = [CNLabeledValue(
        label: CNLabelPhoneNumberMobile,
        value: CNPhoneNumber(stringValue: "555-867-5309")
    )]
    contact.emailAddresses = [CNLabeledValue(
        label: CNLabelHome,
        value: "pat@example.com" as NSString
    )]

    let info = ContactInfo(contact: contact)
    #expect(info.identifier == contact.identifier)
    #expect(info.givenName == "Pat")
    #expect(info.familyName == "Walsh")
    #expect(info.phone == "555-867-5309")
    #expect(info.email == "pat@example.com")
}

@Test func contactInfoHandlesMissingPhoneAndEmail() {
    let info = ContactInfo(contact: CNMutableContact())
    #expect(info.phone == nil)
    #expect(info.email == nil)
}

@Test func displayNameJoinsNonEmptyParts() {
    #expect(ContactInfo(identifier: "x", givenName: "Pat", familyName: "Walsh").displayName == "Pat Walsh")
    #expect(ContactInfo(identifier: "x", givenName: "Pat", familyName: "").displayName == "Pat")
    #expect(ContactInfo(identifier: "x", givenName: "", familyName: "Walsh").displayName == "Walsh")
    #expect(ContactInfo(identifier: "x", givenName: "", familyName: "").displayName == "")
}

// MARK: - phoneDigits

@Test func phoneDigitsStripsFormatting() {
    #expect("(555) 867-5309".phoneDigits == "5558675309")
}

@Test func phoneDigitsKeepsLeadingPlusForInternationalNumbers() {
    #expect("+1 555-867-5309".phoneDigits == "+15558675309")
    #expect("+44 20 7946 0958".phoneDigits == "+442079460958")
}

@Test func phoneDigitsIgnoresInteriorPlus() {
    #expect("555+867".phoneDigits == "555867")
}

@Test func phoneDigitsReturnsEmptyForEmptyString() {
    #expect("".phoneDigits == "")
    #expect("+".phoneDigits == "")
}

// MARK: - URL construction

@Test func callURLProducesCorrectTelURL() {
    #expect(ContactsService.callURL(phone: "5558675309")?.absoluteString == "tel:5558675309")
}

@Test func callURLKeepsCountryCodePrefix() {
    #expect(ContactsService.callURL(phone: "+1 555-867-5309")?.absoluteString == "tel:+15558675309")
}

@Test func smsURLProducesCorrectSmsURL() {
    #expect(ContactsService.smsURL(phone: "5558675309")?.absoluteString == "sms:5558675309")
}

@Test func emailURLProducesCorrectMailtoURL() {
    #expect(ContactsService.emailURL(address: "coach@example.com")?.absoluteString == "mailto:coach@example.com")
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
