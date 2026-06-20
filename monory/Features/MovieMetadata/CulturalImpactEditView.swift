import SwiftUI

struct CulturalImpactEditView: View {
    let vm: MovieMetadataViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var note: String = ""
    @State private var sourceStrings: [String] = []
    @State private var newURL: String = ""
    @FocusState private var newURLFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("メモ") {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }

                Section {
                    ForEach(sourceStrings.indices, id: \.self) { i in
                        Text(sourceStrings[i])
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .onDelete { offsets in sourceStrings.remove(atOffsets: offsets) }

                    HStack {
                        TextField("URL を追加", text: $newURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($newURLFocused)
                        Button("追加") { addURL() }
                            .disabled(newURL.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("参考 URL")
                } footer: {
                    Text("Wikipedia や批評サイトなどへのリンクを記録できます")
                }
            }
            .navigationTitle("文化的インパクト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .bold()
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("閉じる") { newURLFocused = false }
                }
            }
        }
        .onAppear {
            note = vm.culturalImpactNote
            sourceStrings = vm.culturalImpactSources.map(\.absoluteString)
        }
    }

    private func addURL() {
        let trimmed = newURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, URL(string: trimmed)?.scheme != nil else { return }
        sourceStrings.append(trimmed)
        newURL = ""
    }

    private func save() {
        let urls = sourceStrings
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { URL(string: $0) }
            .filter { $0.scheme != nil }
        vm.saveCulturalImpact(note: note, sources: urls)
        dismiss()
    }
}
