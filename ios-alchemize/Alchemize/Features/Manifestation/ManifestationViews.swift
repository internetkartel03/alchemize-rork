import SwiftUI
import Combine
import SwiftData

enum MoodTag: String, CaseIterable, Identifiable {
    case wealth, love, health, focus, creativity, healing
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var emoji: String {
        switch self {
        case .wealth: "💰"
        case .love: "💞"
        case .health: "🌿"
        case .focus: "🎯"
        case .creativity: "🎨"
        case .healing: "💫"
        }
    }
    static func emoji(for key: String) -> String {
        MoodTag(rawValue: key)?.emoji ?? (key == "career" ? "🎯" : key == "relationships" ? "💞" : "✨")
    }
}

private let maxManifestations = 25

// MARK: - Board

struct ManifestationBoardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Manifestation.createdAt, order: .reverse) private var items: [Manifestation]
    @State private var filter = "all"
    @State private var ritual = false
    @State private var showAdd = false
    @State private var showSlideshow = false
    @State private var limitAlert = false
    @State private var pendingDelete: Manifestation?

    private var filtered: [Manifestation] { filter == "all" ? items : items.filter { $0.category == filter } }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ImageBackdrop(url: AZImages.portalBackground, overlay: Color(hex: 0x080316, opacity: 0.55))
            StarField(count: 30)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Portal Board")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button { add() } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 46)
                                .background(AZ.fabGradient, in: .circle)
                                .shadow(color: AZ.violet.opacity(0.6), radius: 10)
                        }
                        .buttonStyle(.squish(0.9))
                    }

                    ritualCard

                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            Chip(title: "✨ All", isSelected: filter == "all") { withAnimation(.snappy) { filter = "all" } }
                            ForEach(MoodTag.allCases) { tag in
                                Chip(title: "\(tag.emoji) \(tag.label)", isSelected: filter == tag.rawValue) {
                                    withAnimation(.snappy) { filter = tag.rawValue }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)

                    if filtered.isEmpty {
                        EmptyStateView(
                            icon: "sparkles",
                            title: filter == "all" ? "Your Portal Awaits" : "No \(filter.capitalized) manifestations yet",
                            message: "Tap the + button to add your first vision",
                            actionTitle: "Create Portal",
                            action: add
                        )
                        .padding(.top, 30)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            ForEach(filtered) { item in
                                NavigationLink {
                                    ManifestationDetailView(item: item)
                                } label: {
                                    ManifestationCard(item: item)
                                }
                                .buttonStyle(.squish)
                                .contextMenu {
                                    Button(item.isFavorite ? "Unfavorite" : "Favorite", systemImage: item.isFavorite ? "star.slash" : "star") {
                                        item.isFavorite.toggle()
                                    }
                                    Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = item }
                                }
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 80)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }

            if !items.isEmpty {
                FloatingAddButton(icon: "play.fill") { showSlideshow = true }
                    .padding(24)
            }
        }
        .cosmicNavigation("Portal Board")
        .sheet(isPresented: $showAdd) { ManifestationEditor(item: nil) }
        .fullScreenCover(isPresented: $showSlideshow) { ManifestationSlideshow(items: items) }
        .onChange(of: showSlideshow) { _, on in if !on { ritual = false } }
        .alert("Limit Reached", isPresented: $limitAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text("You can add up to \(maxManifestations) manifestations.") }
        .alert("Delete Manifestation", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let p = pendingDelete { withAnimation { context.delete(p) }; Haptics.warning() }
            }
        } message: { Text("Are you sure you want to delete \"\(pendingDelete?.title ?? "")\"?") }
    }

    private var ritualCard: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("☀️  Morning Portal Ritual")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Pause during each photo and envision and truly feel what it would be like to already have this")
                    .font(.subheadline)
                    .foregroundStyle(AZ.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $ritual)
                .labelsHidden()
                .tint(AZ.violet)
                .onChange(of: ritual) { _, on in
                    if on && !items.isEmpty { showSlideshow = true }
                }
        }
        .glassCard(radius: 18, tint: AZ.violetLight)
    }

    private func add() {
        if items.count >= maxManifestations { limitAlert = true; Haptics.warning(); return }
        showAdd = true
    }
}

private struct ManifestationCard: View {
    let item: Manifestation

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let data = item.imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Color(hex: 0x4C1D95), Color(hex: 0x6D28D9), AZ.violet], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .overlay(Text(String(item.title.prefix(1)).uppercased()).font(.system(size: 44, weight: .bold)).foregroundStyle(.white.opacity(0.85)))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.78, contentMode: .fill)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            Text(item.intention.isEmpty ? item.title : item.intention)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                if item.isFavorite { Image(systemName: "star.fill").font(.caption2).foregroundStyle(AZ.amber) }
                Text(MoodTag.emoji(for: item.category)).font(.footnote)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(.black.opacity(0.45), in: .capsule)
            .padding(8)
        }
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AZ.violetLight.opacity(0.25)))
        .shadow(color: AZ.violet.opacity(0.3), radius: 10, y: 4)
    }
}

// MARK: - Editor

struct ManifestationEditor: View {
    let item: Manifestation?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var intention = ""
    @State private var category = "other"
    @State private var imageData: Data?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            SheetCanvas {
                HStack(spacing: 8) {
                    Text("✨").font(.title)
                    Text(item == nil ? "Add Manifestation" : "Edit Manifestation").font(.title2.bold()).foregroundStyle(.white)
                }
                FieldLabel(text: "Vision Image")
                ZStack {
                    if let imageData, let ui = UIImage(data: imageData) {
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 220).clipped()
                            .transition(.opacity)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus").font(.largeTitle).foregroundStyle(AZ.violetLight)
                            Text("Add an image that represents your vision").font(.footnote).foregroundStyle(AZ.textSecondary)
                        }
                        .frame(maxWidth: .infinity).frame(height: 220)
                        .background(.white.opacity(0.05))
                    }
                }
                .clipShape(.rect(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: imageData == nil ? [6] : [])).foregroundStyle(AZ.violetLight.opacity(0.4)))
                PhotoSourceButtons { img in
                    withAnimation { imageData = AIService.compress(img) }
                }

                FieldLabel(text: "Title")
                TextField("My manifestation...", text: $title).cosmicField()
                FieldLabel(text: "Your Intention")
                TextField("I am attracting abundance and joy...", text: $intention, axis: .vertical)
                    .lineLimit(3...6)
                    .cosmicField()

                FieldLabel(text: "Mood Tag (optional)")
                FlowChips(selection: $category)

                GradientButton(title: item == nil ? "Create Manifestation" : "Save Changes", icon: "sparkles") { save() }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                    .padding(.top, 8)
            }
            .toolbar {
                SheetToolbar(canSave: canSave, onCancel: { dismiss() }, onSave: save)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationBackground(AZ.night)
        .onAppear {
            guard !loaded, let item else { return }
            loaded = true
            title = item.title
            intention = item.intention
            category = item.category
            imageData = item.imageData
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty || !intention.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        guard canSave else { return }
        let t = title.trimmingCharacters(in: .whitespaces)
        let finalTitle = t.isEmpty ? String(intention.prefix(40)) : t
        if let item {
            item.title = finalTitle
            item.intention = intention
            item.category = category
            item.imageData = imageData
            item.updatedAt = Date()
        } else {
            context.insert(Manifestation(title: finalTitle, intention: intention, category: category, imageData: imageData))
        }
        Haptics.success()
        dismiss()
    }
}

private struct FlowChips: View {
    @Binding var selection: String
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
            ForEach(MoodTag.allCases) { tag in
                Chip(title: "\(tag.emoji) \(tag.label)", isSelected: selection == tag.rawValue) {
                    selection = selection == tag.rawValue ? "other" : tag.rawValue
                }
            }
        }
    }
}

// MARK: - Detail

struct ManifestationDetailView: View {
    @Bindable var item: Manifestation
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            AZ.night.ignoresSafeArea()
            StarField(count: 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Group {
                        if let data = item.imageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().scaledToFill()
                        } else {
                            LinearGradient(colors: [Color(hex: 0x4C1D95), AZ.violet], startPoint: .topLeading, endPoint: .bottomTrailing)
                                .overlay(Text(String(item.title.prefix(1)).uppercased()).font(.system(size: 80, weight: .bold)).foregroundStyle(.white.opacity(0.85)))
                        }
                    }
                    .frame(maxWidth: .infinity).frame(height: 380).clipped()
                    .clipShape(.rect(cornerRadius: 24, style: .continuous))
                    .shadow(color: AZ.violet.opacity(0.4), radius: 20, y: 8)

                    HStack {
                        Text("\(MoodTag.emoji(for: item.category)) \(item.category.capitalized)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AZ.lavender)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(AZ.violet.opacity(0.25), in: .capsule)
                        Spacer()
                        Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.footnote).foregroundStyle(AZ.textTertiary)
                    }
                    Text(item.title).font(.title.bold()).foregroundStyle(.white)
                    if !item.intention.isEmpty {
                        Text(item.intention)
                            .font(.title3)
                            .foregroundStyle(AZ.textSecondary)
                            .lineSpacing(4)
                            .glassCard(radius: 18, tint: AZ.violetLight)
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .cosmicNavigation("Manifestation")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Haptics.tap()
                    withAnimation(.spring) { item.isFavorite.toggle() }
                } label: {
                    Image(systemName: item.isFavorite ? "star.fill" : "star").foregroundStyle(AZ.amber)
                        .symbolEffect(.bounce, value: item.isFavorite)
                }
                Menu {
                    Button("Edit", systemImage: "pencil") { editing = true }
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $editing) { ManifestationEditor(item: item) }
        .alert("Delete Manifestation", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                context.delete(item)
                Haptics.warning()
                dismiss()
            }
        } message: { Text("Are you sure you want to delete \"\(item.title)\"?") }
    }
}

// MARK: - Slideshow

struct ManifestationSlideshow: View {
    let items: [Manifestation]
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var playing = true
    @State private var progress: Double = 0
    private let duration: Double = 8
    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if items.indices.contains(index) {
                let item = items[index]
                ZStack(alignment: .bottom) {
                    Group {
                        if let data = item.imageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().scaledToFill()
                        } else {
                            LinearGradient(colors: [Color(hex: 0x4C1D95), AZ.violet, AZ.indigoDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }
                    .scaleEffect(1 + progress * 0.08)
                    .ignoresSafeArea()
                    LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom).ignoresSafeArea()
                    VStack(spacing: 10) {
                        Text(item.title).font(.title.bold()).foregroundStyle(.white)
                        if !item.intention.isEmpty {
                            Text(item.intention).font(.title3).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                        }
                        Text("Breathe. See it. Feel it as already yours.")
                            .font(.footnote).foregroundStyle(AZ.lavender).padding(.top, 6)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 70)
                }
                .id(item.id)
                .transition(.opacity)
            }

            VStack {
                HStack(spacing: 4) {
                    ForEach(items.indices, id: \.self) { i in
                        ProgressBar(value: i < index ? 1 : (i == index ? progress : 0), tint: .white, height: 3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(.black.opacity(0.4), in: .circle)
                    }
                    Spacer()
                    Button {
                        Haptics.tap(); playing.toggle()
                    } label: {
                        Image(systemName: playing ? "pause.fill" : "play.fill").font(.headline).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(.black.opacity(0.4), in: .circle)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .buttonStyle(.squish(0.9))
                .padding(.horizontal, 16)
                Spacer()
            }

            HStack(spacing: 0) {
                Color.clear.contentShape(.rect).onTapGesture { step(-1) }
                Color.clear.contentShape(.rect).onTapGesture { step(1) }
            }
            .padding(.top, 110)
        }
        .statusBarHidden()
        .onReceive(tick) { _ in
            guard playing, !items.isEmpty else { return }
            progress += 0.05 / duration
            if progress >= 1 { step(1) }
        }
    }

    private func step(_ d: Int) {
        let next = index + d
        if next >= items.count { Haptics.success(); dismiss(); return }
        Haptics.soft()
        withAnimation(.easeInOut(duration: 0.8)) {
            index = max(0, next)
            progress = 0
        }
    }
}
