import SwiftUI

struct RecordPointView: View {
    let onFieldPlayers: [LineSuggestion.Entry]
    let onRecord: (PointOutcome, Player?, Player?) -> Void

    @State private var scorer: Player?
    @State private var assist: Player?

    var body: some View {
        VStack(spacing: 16) {
            Text("Who scored?")
                .font(.title2.bold())

            Button {
                onRecord(.them, nil, nil)
            } label: {
                Text("Them")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Divider()

            Text("Us — tap scorer:")
                .font(.subheadline)

            ForEach(onFieldPlayers, id: \.player.persistentModelID) { entry in
                Button {
                    if scorer?.persistentModelID == entry.player.persistentModelID {
                        scorer = nil
                    } else {
                        scorer = entry.player
                    }
                } label: {
                    HStack {
                        Text(entry.player.name)
                        Spacer()
                        if scorer?.persistentModelID == entry.player.persistentModelID {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .padding(.vertical, 4)
                }
                .tint(.primary)
            }

            if scorer != nil {
                Divider()
                Text("Assist (optional):")
                    .font(.subheadline)

                ForEach(onFieldPlayers.filter { $0.player.persistentModelID != scorer?.persistentModelID }, id: \.player.persistentModelID) { entry in
                    Button {
                        if assist?.persistentModelID == entry.player.persistentModelID {
                            assist = nil
                        } else {
                            assist = entry.player
                        }
                    } label: {
                        HStack {
                            Text(entry.player.name)
                            Spacer()
                            if assist?.persistentModelID == entry.player.persistentModelID {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .tint(.primary)
                }
            }

            if scorer != nil {
                Button {
                    onRecord(.us, scorer, assist)
                } label: {
                    Text("Confirm")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
