import SwiftUI
import SwiftData

private let gratitudeQuote = "Even on hard days, there's always something to be grateful for. Focus on the good."

struct GratitudeView: View {
    @Query(sort: \GratitudeEntry.entryDate, order: .reverse) private var entries: [GratitudeEntry]
    @State private var month = Date()
    @State private var selected = Date().startOfDay
    @State private var editorDate: EditorTarget?
    @State private var glow = false

    struct EditorTarget: Identifiable {
        let date: Date
        var id: Date { date }
    }

    private var selectedEntry: GratitudeEntry? {
        entries.first { Calendar.current.isDate($0.entryDate, inSameDayAs: selected) }
    }

    var body: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: Color(hex: 0x040108), location: 0),
                .init(color: Color(hex: 0x0F0416), location: 0.25),
                .init(color: Color(hex: 0x180827), location: 0.55),
                .init(color: Color(hex: 0x14061F), location: 0.8),
                .init(color: Color(hex: 0x060109), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            Circle().fill(Color(hex: 0x8E39FF).opacity(0.25)).frame(width: 320).blur(radius: 90).offset(x: -120, y: -260)
            Circle().fill(Color(hex: 0x6D47FF).opacity(0.2)).frame(width: 280).blur(radius: 90).offset(x: 140, y: 200)
            StarField(count: 16)

            ScrollView {
                VStack(spacing: 18) {
                    Text(gratitudeQuote)
                        .font(.system(.callout, design: .serif).italic())
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity)
                        .glassCard(radius: 20)

                    MonthCalendarView(month: $month, selected: selected, accent: Color(hex: 0x8E39FF),
                                      marked: { d in entries.contains { Calendar.current.isDate($0.entryDate, inSameDayAs: d) } }) { day in
                        withAnimation(.snappy) { selected = day.startOfDay }
                    }
                    .padding(16)
                    .background(
                        LinearGradient(colors: [Color(red: 63/255, green: 25/255, blue: 102/255).opacity(0.96), Color(red: 33/255, green: 15/255, blue: 67/255).opacity(0.98)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: .rect(cornerRadius: 24, style: .continuous)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.1)))

                    Group {
                        if let entry = selectedEntry {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(selected.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                        .font(.headline).foregroundStyle(.white)
                                    Spacer()
                                    Button { editorDate = .init(date: selected) } label: {
                                        Image(systemName: "pencil").foregroundStyle(AZ.honey)
                                    }
                                }
                                ForEach(Array(entry.items.enumerated()), id: \.offset) { i, t in
                                    Text("\(i + 1). \(t)").foregroundStyle(.white.opacity(0.9))
                                }
                                if !entry.reflection.isEmpty {
                                    Divider().overlay(.white.opacity(0.15))
                                    Text("Reflection").font(.caption.weight(.bold)).foregroundStyle(AZ.honey)
                                    Text(entry.reflection).foregroundStyle(AZ.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(radius: 20, tint: AZ.honey)
                            ctaButton("Edit Entry") { editorDate = .init(date: selected) }
                        } else {
                            VStack(spacing: 14) {
                                Image(systemName: "heart")
                                    .font(.system(size: 64, weight: .light))
                                    .foregroundStyle(Color(hex: 0x8F49FF))
                                    .shadow(color: Color(hex: 0x8F49FF).opacity(0.8), radius: glow ? 24 : 8)
                                Text(entries.isEmpty ? "Start your gratitude journey" : "No entry for this day")
                                    .font(.title3.bold()).foregroundStyle(.white)
                            }
                            .padding(.vertical, 16)
                            ctaButton(entries.isEmpty ? "Add Your First Entry" : "Add Entry") { editorDate = .init(date: selected) }
                                .shadow(color: Color(hex: 0x8E39FF).opacity(glow ? 0.7 : 0.3), radius: glow ? 22 : 10)
                        }
                    }
                    .transition(.opacity.combined(with: .offset(y: 12)))
                }
                .padding(20)
                .padding(.bottom, 40)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .cosmicNavigation("Gratitude Journal")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editorDate = .init(date: Date().startOfDay) } label: {
                    Image(systemName: "plus").fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $editorDate) { GratitudeEditor(date: $0.date) }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    private func ctaButton(_ title: String, action: @escaping () -> Void) -> some View {
        GradientButton(title: title, gradient: AZ.buttonGradient, action: action)
    }
}

struct GratitudeEditor: View {
    let date: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [GratitudeEntry]
    @State private var g1 = ""
    @State private var g2 = ""
    @State private var g3 = ""
    @State private var reflection = ""

    private var existing: GratitudeEntry? { entries.first { Calendar.current.isDate($0.entryDate, inSameDayAs: date) } }
    private var canSave: Bool { ![g1, g2, g3].allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }

    var body: some View {
        NavigationStack {
            SheetCanvas {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gratitude Journal").font(.caption).foregroundStyle(AZ.textSecondary)
                        Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.title3.bold()).foregroundStyle(.white)
                    }
                    Spacer()
                    Text("💛").font(.largeTitle)
                }
                Text("What are you grateful for?").font(.headline).foregroundStyle(.white)
                Text("List three things you're thankful for today").font(.subheadline).foregroundStyle(AZ.textSecondary)
                entry("Entry 1", $g1, "I am grateful for...")
                entry("Entry 2", $g2, "I am grateful for...")
                entry("Entry 3", $g3, "I am grateful for...")
                entry("Reflection", $reflection, "What could I have done better today?")
                GradientButton(title: "Save Entry", gradient: AZ.buttonGradient) { save() }
                    .disabled(!canSave).opacity(canSave ? 1 : 0.5)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SheetToolbar(canSave: canSave, onCancel: { dismiss() }, onSave: save) }
        }
        .presentationBackground(Color(hex: 0x0F0416))
        .onAppear {
            if let e = existing { g1 = e.gratitude1; g2 = e.gratitude2; g3 = e.gratitude3; reflection = e.reflection }
        }
    }

    private func entry(_ label: String, _ text: Binding<String>, _ placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.weight(.bold)).foregroundStyle(AZ.honey)
            TextField(placeholder, text: text, axis: .vertical).lineLimit(2...5).cosmicField()
        }
    }

    private func save() {
        guard canSave else { return }
        if let e = existing {
            e.gratitude1 = g1; e.gratitude2 = g2; e.gratitude3 = g3; e.reflection = reflection
        } else {
            context.insert(GratitudeEntry(entryDate: date.startOfDay, gratitude1: g1, gratitude2: g2, gratitude3: g3, reflection: reflection))
        }
        Haptics.success()
        dismiss()
    }
}
