import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var players: [Player]
    @Query private var games: [Game]
    @Query private var plays: [SavedPlay]

    @Query(sort: \Season.startedAt, order: .reverse) private var seasons: [Season]

    @State private var exported: ExportedArchive?
    @State private var exportFailure: String?
    @State private var importing = false
    @State private var pendingImport: URL?
    @State private var importResult: String?
    @State private var archivingSeason = false
    @State private var seasonName = ""
    @State private var seasonResult: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Current season", value: currentSeasonName)
                    Button {
                        seasonName = currentSeasonName
                        archivingSeason = true
                    } label: {
                        Label("Archive and start a new season", systemImage: "archivebox")
                    }
                } header: {
                    Text("Season")
                } footer: {
                    Text("Names the season you just finished and opens an empty one. Its games stay in History under that name; the roster carries over.")
                }

                Section {
                    Button {
                        export()
                    } label: {
                        Label("Export season", systemImage: "square.and.arrow.up")
                    }
                    if let exported {
                        ShareLink(item: exported.url) {
                            Label("Share \(exported.url.lastPathComponent)", systemImage: "paperplane")
                        }
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Writes \(players.count) players, \(games.count) games and \(plays.count) plays to a JSON file you can keep off this phone.")
                }

                Section {
                    Button(role: .destructive) {
                        importing = true
                    } label: {
                        Label("Restore from a file", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Restore")
                } footer: {
                    Text("Replaces everything currently in the app with the contents of the file. This cannot be undone.")
                }
            }
            .navigationTitle("Data")
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): pendingImport = url
            case .failure(let error): importResult = error.localizedDescription
            }
        }
        .alert("Replace everything?", isPresented: confirmingImport, presenting: pendingImport) { url in
            Button("Replace", role: .destructive) { restore(from: url) }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: { url in
            Text("Every player, game and play in PigeonPlay will be deleted and replaced with the contents of \(url.lastPathComponent).")
        }
        .alert("Export failed", isPresented: showing($exportFailure)) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportFailure ?? "")
        }
        .alert("Restore", isPresented: showing($importResult)) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importResult ?? "")
        }
        .alert("Name this season", isPresented: $archivingSeason) {
            TextField("Season name", text: $seasonName)
            Button("Archive") { archiveSeason() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The season you just played is filed under this name. A new one starts empty.")
        }
        .alert("Season", isPresented: showing($seasonResult)) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(seasonResult ?? "")
        }
    }

    private var currentSeasonName: String {
        seasons.first { $0.isCurrent }?.name ?? Seasons.defaultName()
    }

    private var confirmingImport: Binding<Bool> {
        Binding(
            get: { pendingImport != nil },
            set: { presented in if !presented { pendingImport = nil } }
        )
    }

    private func showing(_ message: Binding<String?>) -> Binding<Bool> {
        Binding(
            get: { message.wrappedValue != nil },
            set: { presented in if !presented { message.wrappedValue = nil } }
        )
    }

    private func export() {
        do {
            exported = try ExportedArchive(writing: SeasonArchive(exporting: modelContext))
        } catch {
            exportFailure = error.localizedDescription
        }
    }

    private func archiveSeason() {
        do {
            let change = try Seasons.archiveCurrent(named: seasonName, in: modelContext)
            seasonResult = "\(change.archived.name) is archived. You are now in \(change.started.name)."
        } catch {
            seasonResult = error.localizedDescription
        }
    }

    private func restore(from url: URL) {
        pendingImport = nil
        // Files handed over by the document picker live outside our
        // sandbox until we ask for access, and the access must be
        // balanced or the grant leaks.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let archive = try SeasonArchive(jsonData: try Data(contentsOf: url))
            try archive.replaceContents(of: modelContext)
            importResult = "Restored \(archive.players.count) players, \(archive.games.count) games and \(archive.plays.count) plays."
        } catch {
            importResult = error.localizedDescription
        }
    }
}

/// A written archive plus the file it went to, kept together so ShareLink
/// has something on disk to hand to the share sheet.
struct ExportedArchive {
    let url: URL

    init(writing archive: SeasonArchive) throws {
        let stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withYear, .withMonth, .withDay, .withDashSeparatorInDate]
        let name = "PigeonPlay-\(stamp.string(from: archive.exportedAt)).json"
        url = URL.temporaryDirectory.appending(path: name)
        try archive.jsonData().write(to: url, options: .atomic)
    }
}
