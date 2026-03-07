import SwiftUI

struct ContentView: View {
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
                Text("History")
            }
        }
    }
}
