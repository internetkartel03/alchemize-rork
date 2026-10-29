import SwiftUI
import Combine
import SwiftData

enum AffirmationCategory: String, CaseIterable, Identifiable {
    case selfLove = "self-love", abundance, health, success, relationships, gratitude
    var id: String { rawValue }
    var label: String {
        switch self {
        case .selfLove: "Self-Love"
        default: rawValue.capitalized
        }
    }
    var emoji: String {
        switch self {
        case .selfLove: "💖"
        case .abundance: "💰"
        case .health: "❤️‍🔥"
        case .success: "🏆"
        case .relationships: "🤝"
        case .gratitude: "🙏"
        }
    }
    static func emoji(_ key: String) -> String { AffirmationCategory(rawValue: key)?.emoji ?? "✨" }
}

struct AffirmationsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Affirmation.createdAt, order: .reverse) private var all: [Affirmation]
    @State private var filter = "all"
    @State private var editing: Affirmation?
    @State private var showAdd = false
    @State private var showPlay = false

    private var list: [Affirmation] {
        switch filter {
        case "all": all
        case "favorites": all.filter(\.isFavorite)
        default: all.filter { $0.category == filter }
        }
    }

    private var today: Affirmation? {
        guard !all.isEmpty else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE MMM dd yyyy"
        let seed = f.string(from: Date()).unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return all[seed % all.count]
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ImageBackdrop(url: AZImages.featureBackground, overlay: .black.opacity(0.5))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let today {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("✨ Today's Affirmation")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AZ.lavender)
                            Text("“\(today.text)”")
                                .font(.system(size: 22, weight: .semibold, design: .serif))
                                .foregroundStyle(.white)
                                .lineSpacing(4)
                            Text("\(AffirmationCategory.emoji(today.category)) \(today.category)")
                                .font(.footnote)
                                .foregroundStyle(AZ.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(Color(hex: 0x8B5CF6, opacity: 0.2), in: .rect(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(hex: 0xA855F7, opacity: 0.4), lineWidth: 1))
                        .shadow(color: AZ.purple.opacity(0.3), radius: 16)
                    }

                    if !all.isEmpty {
                        Button {
                            Haptics.medium()
                            showPlay = true
                        } label: {
                            Label("Start Affirmation Session", systemImage: "play.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(AZ.emerald.gradient, in: .rect(cornerRadius: 16))
                                .shadow(color: AZ.emerald.opacity(0.45), radius: 12, y: 4)
                        }
                        .buttonStyle(.squish)
                    }

                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            Chip(title: "✨ All", isSelected: filter == "all", tint: AZ.indigo) { withAnimation(.snappy) { filter = "all" } }
                            Chip(title: "⭐ Favorites", isSelected: filter == "favorites", tint: AZ.indigo) { withAnimation(.snappy) { filter = "favorites" } }
                            ForEach(AffirmationCategory.allCases) { c in
                                Chip(title: "\(c.emoji) \(c.label)", isSelected: filter == c.rawValue, tint: AZ.indigo) {
                                    withAnimation(.snappy) { filter = c.rawValue }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)

                    if list.isEmpty {
                        EmptyStateView(
                            icon: "quote.bubble",
                            title: filter == "all" ? "No affirmations yet" : "No \(filter) affirmations",
                            message: filter == "all" ? "Tap + to add an affirmation" : "Try a different category"
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(list) { a in
                                row(a)
                                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .scale(scale: 0.9).combined(with: .opacity)))
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 90)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            FloatingAddButton { showAdd = true }.padding(24)
        }
        .cosmicNavigation("Affirmations")
        .sheet(isPresented: $showAdd) { AffirmationEditor(item: nil) }
        .sheet(item: $editing) { AffirmationEditor(item: $0) }
        .fullScreenCover(isPresented: $showPlay) { AffirmationSession(items: list.isEmpty ? all : list) }
    }

    private func row(_ a: Affirmation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(AffirmationCategory.emoji(a.category)).font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(a.text).font(.body.weight(.medium)).foregroundStyle(.white)
                Text(a.category).font(.caption).foregroundStyle(AZ.textSecondary)
            }
            Spacer(minLength: 4)
            HStack(spacing: 14) {
                Button {
                    Haptics.tap()
                    withAnimation(.spring) { a.isFavorite.toggle() }
                } label: {
                    Image(systemName: a.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(AZ.amber)
                        .symbolEffect(.bounce, value: a.isFavorite)
                }
                Button { editing = a } label: { Image(systemName: "square.and.pencil").foregroundStyle(AZ.indigo) }
                Button {
                    Haptics.warning()
                    withAnimation { context.delete(a) }
                } label: { Image(systemName: "trash").foregroundStyle(AZ.red) }
            }
            .font(.system(size: 18))
            .buttonStyle(.squish(0.8))
        }
        .glassCard(radius: 16)
    }
}

struct AffirmationEditor: View {
    let item: Affirmation?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var category = AffirmationCategory.selfLove.rawValue
    @State private var loaded = false

    private var canSave: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            SheetCanvas {
                FieldLabel(text: "Affirmation")
                TextField("I am confident and capable...", text: $text, axis: .vertical)
                    .lineLimit(3...8)
                    .font(.title3)
                    .cosmicField()
                FieldLabel(text: "Category")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                    ForEach(AffirmationCategory.allCases) { c in
                        Chip(title: "\(c.emoji) \(c.label)", isSelected: category == c.rawValue, tint: AZ.indigo) { category = c.rawValue }
                    }
                }
                GradientButton(title: item == nil ? "Save Affirmation" : "Update Affirmation", icon: "checkmark") { save() }
                    .disabled(!canSave).opacity(canSave ? 1 : 0.5)
                    .padding(.top, 8)
            }
            .navigationTitle(item == nil ? "New Affirmation" : "Edit Affirmation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { SheetToolbar(canSave: canSave, onCancel: { dismiss() }, onSave: save) }
        }
        .presentationDetents([.large])
        .presentationBackground(AZ.night)
        .onAppear {
            guard !loaded, let item else { return }
            loaded = true
            text = item.text
            category = item.category
        }
    }

    private func save() {
        guard canSave else { return }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let item { item.text = t; item.category = category }
        else { context.insert(Affirmation(text: t, category: category)) }
        Haptics.success()
        dismiss()
    }
}

struct AffirmationSession: View {
    let items: [Affirmation]
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var seconds = 5
    @State private var paused = false
    @State private var breathe = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            ImageBackdrop(url: AZImages.featureBackground, overlay: .black.opacity(0.6))
            StarField(count: 26)
            Circle()
                .fill(RadialGradient(colors: [AZ.purple.opacity(0.55), .clear], center: .center, startRadius: 10, endRadius: 220))
                .frame(width: 440, height: 440)
                .scaleEffect(breathe ? 1.1 : 0.85)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: breathe)

            if items.isEmpty {
                VStack(spacing: 16) {
                    Text("No affirmations to play").foregroundStyle(.white)
                    Button("Go Back") { dismiss() }.buttonStyle(.borderedProminent).tint(AZ.indigo)
                }
            } else {
                let a = items[index]
                VStack(spacing: 18) {
                    Text(a.category.uppercased())
                        .font(.caption.weight(.bold)).tracking(2)
                        .foregroundStyle(AZ.lavender)
                    Text(a.text)
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .id(a.id)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.92)), removal: .opacity.combined(with: .offset(y: -20))))

                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.headline).foregroundStyle(.white)
                                .frame(width: 44, height: 44).background(.white.opacity(0.1), in: .circle)
                        }
                        Spacer()
                    }
                    .padding()
                    Spacer()
                    VStack(spacing: 6) {
                        Text("\(seconds)s")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText(countsDown: true))
                        Text("\(index + 1) of \(items.count)").font(.footnote).foregroundStyle(AZ.textSecondary)
                    }
                    HStack(spacing: 28) {
                        control("backward.fill") { go(-1) }
                        control(paused ? "play.fill" : "pause.fill", big: true) { paused.toggle() }
                        control("forward.fill") { go(1) }
                    }
                    .padding(.vertical, 30)
                }
                .buttonStyle(.squish(0.88))
            }
        }
        .onAppear { breathe = true }
        .onReceive(timer) { _ in
            guard !paused, !items.isEmpty else { return }
            if seconds <= 1 { go(1) } else { withAnimation { seconds -= 1 } }
        }
    }

    private func control(_ icon: String, big: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap(); action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: big ? 26 : 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: big ? 72 : 52, height: big ? 72 : 52)
                .background(big ? AnyShapeStyle(AZ.fabGradient) : AnyShapeStyle(.white.opacity(0.12)), in: .circle)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    private func go(_ d: Int) {
        Haptics.soft()
        withAnimation(.easeInOut(duration: 0.6)) {
            index = (index + d + items.count) % items.count
            seconds = 5
        }
    }
}
