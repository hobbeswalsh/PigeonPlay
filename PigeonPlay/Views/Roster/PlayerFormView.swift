import SwiftUI
import SwiftData

struct PlayerFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let player: Player?

    @State private var name: String = ""
    @State private var gender: Gender = .b
    @State private var defaultMatching: GenderMatching = .bx
    @State private var phoneNumber: String?
    @State private var contactIdentifiers: [String] = []
    @State private var showContactPicker = false

    private var isEditing: Bool { player != nil }

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
                ForEach(contactIdentifiers, id: \.self) { _ in
                    Text("Linked Contact")
                        .foregroundStyle(.secondary)
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
