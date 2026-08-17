import SwiftUI

/// Shown instead of the app when the store will not open. The previous
/// behaviour was fatalError, which protected the data but left the coach
/// with an app that would not launch and no way to get the season off the
/// phone. This at least gets the file out.
///
/// There is deliberately no reset button. Erasing a season should take
/// more deliberation than a tap on a screen the user did not expect.
struct StoreRecoveryView: View {
    let error: Error
    let storeURL: URL

    private var existingFiles: [URL] {
        StoreLocation.sidecarURLs(for: storeURL)
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("PigeonPlay could not open its data")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("Your season is still on this device, but the app cannot read it. Save a copy somewhere safe before reinstalling or deleting the app — without it, the data is gone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if existingFiles.isEmpty {
                Text("No data file was found at \(storeURL.lastPathComponent).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ShareLink(items: existingFiles) {
                    Label("Save a copy of the data", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }

            DisclosureGroup("Technical details") {
                Text(error.localizedDescription)
                    .font(.footnote.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .font(.footnote)
        }
        .padding(28)
    }
}
