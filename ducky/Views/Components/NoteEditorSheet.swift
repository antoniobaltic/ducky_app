import SwiftUI
import SwiftData

struct NoteEditorSheet: View {
    let lakeID: String
    let lakeName: String
    let existingNote: LakeNote?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(lakeName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)

                TextEditor(text: $text)
                    .font(AppTheme.bodyText)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(AppTheme.searchBarBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.badgeRadius, style: .continuous))
                    .frame(minHeight: 150)

                Spacer()
            }
            .padding(16)
            .navigationTitle("Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { saveNote() }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && existingNote == nil)
                }
            }
        }
        .onAppear {
            text = existingNote?.noteText ?? ""
        }
        .presentationDetents([.medium, .large])
    }

    private func saveNote() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            // Delete note if text is empty
            if let existing = existingNote {
                modelContext.delete(existing)
            }
        } else if let existing = existingNote {
            // Update existing note
            existing.noteText = trimmed
            existing.updatedAt = Date()
        } else {
            // Create new note
            let note = LakeNote(lakeID: lakeID, lakeName: lakeName, noteText: trimmed)
            modelContext.insert(note)
        }

        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
