import SwiftUI
import SwiftData
import Contacts

struct PlayerFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let player: Player?

    @State private var name: String = ""
    @State private var gender: Gender = .b
    @State private var defaultMatching: GenderMatching = .bx
    @State private var phoneNumber: String?
    @State private var contactIdentifiers: [String] = []
    @State private var showContactPicker = false
    @State private var contactInfoByID: [String: ContactInfo] = [:]
    @State private var contactsAuthStatus: CNAuthorizationStatus = .notDetermined
    @State private var isLoadingContacts = false

    private var isEditing: Bool { player != nil }

    /// Rows derive from contactIdentifiers (the single source of truth)
    /// so deletion offsets always index the identifier being shown, even
    /// when a fetch failed or was skipped.
    private var linkedContacts: [LinkedContact] {
        contactIdentifiers.map { LinkedContact(id: $0, info: contactInfoByID[$0]) }
    }

    private var canFetchContacts: Bool {
        ContactsService.canFetch(status: contactsAuthStatus)
    }

    var body: some View {
        Form {
            Section("Player Info") {
                TextField("Name", text: $name)
                Picker("Gender", selection: $gender) {
                    ForEach(Gender.allCases, id: \.self) { g in
                        Text(g.displayName).tag(g)
                    }
                }
                if gender == .x {
                    Picker("Default Matching", selection: $defaultMatching) {
                        ForEach(GenderMatching.allCases, id: \.self) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                }
                TextField("Phone", text: Binding(
                    get: { phoneNumber ?? "" },
                    set: { phoneNumber = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.phonePad)
            }
            Section("Contacts") {
                if contactsAuthStatus == .denied || contactsAuthStatus == .restricted {
                    Label(
                        "Contacts access is required to display contact details.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .font(.footnote)
                }
                if isLoadingContacts && contactInfoByID.isEmpty {
                    ProgressView()
                }
                ForEach(linkedContacts) { contact in
                    if let info = contact.info {
                        ContactRowView(info: info, openURL: openURL)
                    } else if canFetchContacts && !isLoadingContacts {
                        Text("Contact no longer available")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        Text("Linked contact")
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
                .onDelete { offsets in
                    contactIdentifiers.remove(atOffsets: offsets)
                }
                Button {
                    showContactPicker = true
                } label: {
                    Label("Add Contact", systemImage: "plus")
                }
            }
            .task(id: contactIdentifiers) {
                await loadContacts()
            }
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerRepresentable { identifier in
                if !contactIdentifiers.contains(identifier) {
                    contactIdentifiers.append(identifier)
                }
                showContactPicker = false
            }
        }
        .navigationTitle(isEditing ? "Edit Player" : "Add Player")
        .toolbar {
            if !isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let player {
                name = player.name
                gender = player.gender
                defaultMatching = player.defaultMatching ?? .bx
                phoneNumber = player.phoneNumber
                contactIdentifiers = player.contactIdentifiers
            }
        }
    }

    private func loadContacts() async {
        guard !contactIdentifiers.isEmpty else {
            contactInfoByID = [:]
            return
        }
        let status = ContactsService.authorizationStatus()
        if status == .notDetermined {
            _ = await ContactsService.requestAccess()
            // Re-read rather than assuming .authorized: the user may have
            // granted limited access.
            contactsAuthStatus = ContactsService.authorizationStatus()
        } else {
            contactsAuthStatus = status
        }
        guard canFetchContacts else { return }
        isLoadingContacts = true
        contactInfoByID = await ContactsService.fetchContacts(identifiers: contactIdentifiers)
        isLoadingContacts = false
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let player {
            player.name = trimmedName
            player.gender = gender
            player.defaultMatching = gender == .x ? defaultMatching : nil
            player.phoneNumber = phoneNumber
            player.contactIdentifiers = contactIdentifiers
        } else {
            let newPlayer = Player(
                name: trimmedName,
                gender: gender,
                defaultMatching: gender == .x ? defaultMatching : nil,
                phoneNumber: phoneNumber,
                contactIdentifiers: contactIdentifiers
            )
            modelContext.insert(newPlayer)
        }
        dismiss()
    }
}

private struct LinkedContact: Identifiable {
    let id: String
    let info: ContactInfo?
}

private struct ContactRowView: View {
    let info: ContactInfo
    let openURL: OpenURLAction

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(info.displayName.isEmpty ? "Unknown" : info.displayName)
                .font(.body)
            HStack(spacing: 16) {
                if let phone = info.phone {
                    Text(phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        if let url = ContactsService.callURL(phone: phone) { openURL(url) }
                    } label: {
                        Image(systemName: "phone")
                    }
                    .buttonStyle(.borderless)
                    Button {
                        if let url = ContactsService.smsURL(phone: phone) { openURL(url) }
                    } label: {
                        Image(systemName: "message")
                    }
                    .buttonStyle(.borderless)
                }
                if let email = info.email {
                    if info.phone != nil { Spacer() }
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        if let url = ContactsService.emailURL(address: email) { openURL(url) }
                    } label: {
                        Image(systemName: "envelope")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
