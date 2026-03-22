import SwiftUI

struct RecordPointView: View {
    let onFieldPlayers: [LineSuggestion.Entry]
    let onRecord: (PointOutcome, Player?, Player?) -> Void

    @State private var scorer: Player?
    @State private var assist: Player?

    var body: some View {
        VStack(spacing: 2) {
            Text("Who scored?")
                .font(.title2.bold())
                .padding(.bottom, 8)

            Button {
                onRecord(.them, nil, nil)
            } label: {
                Text("Them")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .padding(.bottom, 4)

            Divider().padding(.vertical, 4)

            Text("Us — tap scorer:")
                .font(.subheadline)
                .padding(.bottom, 2)

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
                Divider().padding(.vertical, 4)
                Text("Assist (optional):")
                    .font(.subheadline)
                    .padding(.bottom, 2)

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

            Divider().padding(.vertical, 4)

            Button {
                onRecord(.dead, nil, nil)
            } label: {
                Text("Dead Point")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .padding()
    }
}
