import SwiftUI
import SwiftData

struct PlaybookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlay.dateCreated, order: .reverse) private var savedPlays: [SavedPlay]

    @State private var elements: [DrawingElement] = []
    @State private var currentTool: DrawingTool = .pen
    @State private var currentColor: String = "white"
    @State private var isHorizontal: Bool = true
    @State private var showingSaveDialog = false
    @State private var showingPlaybook = false
    @State private var playName = ""

    private let colors = ["white", "red", "blue", "yellow", "black"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FieldCanvasView(
                    elements: $elements,
                    currentTool: $currentTool,
                    currentColor: $currentColor,
                    isHorizontal: isHorizontal
                )

                HStack {
                    ForEach([
                        (DrawingTool.pen, "pencil.tip"),
                        (.arrow, "arrow.right"),
                        (.circle, "circle.fill"),
                        (.eraser, "eraser"),
                    ], id: \.1) { tool, icon in
                        Button {
                            currentTool = tool
                        } label: {
                            Image(systemName: icon)
                                .padding(8)
                                .background(currentTool == tool ? Color.accentColor.opacity(0.3) : Color.clear)
                                .cornerRadius(8)
                        }
                    }

                    Divider().frame(height: 24)

                    ForEach(colors, id: \.self) { color in
                        Button {
                            currentColor = color
                        } label: {
                            Circle()
                                .fill(Color(namedColor: color))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle().stroke(currentColor == color ? Color.accentColor : Color.gray, lineWidth: currentColor == color ? 3 : 1)
                                )
                        }
                    }

                    Spacer()

                    Button {
                        elements = []
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Playbook")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Save Play", systemImage: "square.and.arrow.down") {
                            showingSaveDialog = true
                        }
                        Button("Load Play", systemImage: "folder") {
                            showingPlaybook = true
                        }
                        Divider()
                        Button {
                            isHorizontal.toggle()
                        } label: {
                            Label(
                                isHorizontal ? "Vertical Field" : "Horizontal Field",
                                systemImage: isHorizontal ? "rectangle.portrait" : "rectangle.landscape.rotate"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Save Play", isPresented: $showingSaveDialog) {
                TextField("Play name", text: $playName)
                Button("Save") {
                    let play = SavedPlay(name: playName, elements: elements)
                    modelContext.insert(play)
                    playName = ""
                }
                Button("Cancel", role: .cancel) { playName = "" }
            }
            .sheet(isPresented: $showingPlaybook) {
                NavigationStack {
                    List {
                        ForEach(savedPlays) { play in
                            Button(play.name) {
                                elements = play.elements
                                showingPlaybook = false
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(savedPlays[index])
                            }
                        }
                    }
                    .navigationTitle("Saved Plays")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingPlaybook = false }
                        }
                    }
                }
            }
        }
    }
}
