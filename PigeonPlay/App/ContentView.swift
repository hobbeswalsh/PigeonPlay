import SwiftUI

struct ContentView: View {
    @State private var saveFailures = SaveFailureReporter()

    var body: some View {
        TabView {
            Tab("Roster", systemImage: "person.3") {
                RosterView()
            }
            Tab("Game", systemImage: "sportscourt") {
                GameView()
            }
            Tab("Playbook", systemImage: "pencil.and.outline") {
                PlaybookView()
            }
            Tab("History", systemImage: "clock") {
                HistoryView()
            }
            Tab("Data", systemImage: "externaldrive") {
                DataView()
            }
        }
        .environment(saveFailures)
        .alert("Could not save", isPresented: showingSaveFailure) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveFailures.failure?.localizedDescription ?? "")
        }
    }

    private var showingSaveFailure: Binding<Bool> {
        Binding(
            get: { saveFailures.failure != nil },
            set: { presented in
                if !presented { saveFailures.failure = nil }
            }
        )
    }
}
