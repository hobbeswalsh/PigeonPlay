import SwiftUI
import SwiftData

struct PlayerFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let player: Player?

    @State private var name: String = ""
    @State private var gender: Gender = .b
    @State private var defaultMatching: GenderMatching = .bx
    @State private var parentName: String = ""
    @State private var parentPhone: String = ""
    @State private var parentEmail: String = ""

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
            }
            Section("Parent Contact (Optional)") {
                TextField("Parent Name", text: $parentName)
                TextField("Phone", text: $parentPhone)
                    .keyboardType(.phonePad)
                TextField("Email", text: $parentEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
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
                parentName = player.parentName ?? ""
                parentPhone = player.parentPhone ?? ""
                parentEmail = player.parentEmail ?? ""
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let player {
            player.name = trimmedName
            player.gender = gender
            player.defaultMatching = gender == .x ? defaultMatching : nil
            player.parentName = parentName.isEmpty ? nil : parentName
            player.parentPhone = parentPhone.isEmpty ? nil : parentPhone
            player.parentEmail = parentEmail.isEmpty ? nil : parentEmail
        } else {
            let newPlayer = Player(
                name: trimmedName,
                gender: gender,
                defaultMatching: gender == .x ? defaultMatching : nil,
                parentName: parentName.isEmpty ? nil : parentName,
                parentPhone: parentPhone.isEmpty ? nil : parentPhone,
                parentEmail: parentEmail.isEmpty ? nil : parentEmail
            )
            modelContext.insert(newPlayer)
        }
        dismiss()
    }
}
