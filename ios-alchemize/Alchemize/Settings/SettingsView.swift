import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @AppStorage(Prefs.hiddenFeaturesKey) private var hiddenRaw = ""
    @AppStorage(Prefs.themeKey) private var theme = "classic"
    @AppStorage("prefs.notifications") private var notificationsOn = true

    @State private var editingName = false
    @State private var nameDraft = ""
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var confirmReset = false
    @State private var legal: LegalPage?

    enum LegalPage: String, Identifiable {
        case about, terms, privacy
        var id: String { rawValue }
    }

    private var hidden: Set<String> { Set(hiddenRaw.split(separator: ",").map(String.init)) }

    var body: some View {
        ZStack {
            ImageBackdrop(url: AZImages.featureBackground, overlay: Color(hex: 0x050211, opacity: 0.7))
            StarField(count: 18)
            ScrollView {
                VStack(spacing: 22) {
                    profileHeader
                    group("ACCOUNT") {
                        row(icon: "person.fill", tint: AZ.violetLight, title: "Name", value: auth.user?.name ?? "") {
                            nameDraft = auth.user?.name ?? ""
                            editingName = true
                        }
                        divider
                        row(icon: "envelope.fill", tint: AZ.sky, title: "Email", value: auth.user?.email ?? "", chevron: false) {}
                    }
                    group("APPEARANCE") {
                        HStack(spacing: 12) {
                            themeOption("classic", title: "Classic", icon: "rectangle.stack.fill")
                            themeOption("cosmic", title: "Cosmic", icon: "globe.americas.fill")
                        }
                        .padding(14)
                    }
                    group("HOME SCREEN FEATURES") {
                        ForEach(Array(Feature.allCases.enumerated()), id: \.element) { i, f in
                            Toggle(isOn: Binding(
                                get: { !hidden.contains(f.rawValue) },
                                set: { setVisible(f, $0) }
                            )) {
                                Label {
                                    Text(f.title).foregroundStyle(.white)
                                } icon: {
                                    Image(systemName: f.symbol).foregroundStyle(AZ.violetLight)
                                }
                            }
                            .tint(AZ.purple)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            if i < Feature.allCases.count - 1 { divider }
                        }
                    }
                    group("APP") {
                        Toggle(isOn: $notificationsOn) {
                            Label { Text("Reminders").foregroundStyle(.white) } icon: {
                                Image(systemName: "bell.fill").foregroundStyle(AZ.amber)
                            }
                        }
                        .tint(AZ.purple)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .onChange(of: notificationsOn) { _, on in
                            if on { Task { _ = await Notifications.requestAuthorization() } }
                            else { UNUserNotificationCenter.current().removeAllPendingNotificationRequests() }
                        }
                        divider
                        row(icon: "info.circle.fill", tint: AZ.lavender, title: "About Alchemize") { legal = .about }
                        divider
                        row(icon: "doc.text.fill", tint: AZ.indigo, title: "Terms of Service") { legal = .terms }
                        divider
                        row(icon: "lock.shield.fill", tint: AZ.emerald, title: "Privacy Policy") { legal = .privacy }
                        divider
                        row(icon: "questionmark.circle.fill", tint: AZ.sky, title: "Support") {
                            if let url = URL(string: "mailto:Admin@crfenterprise.com") { openURL(url) }
                        }
                    }
                    group("DATA") {
                        row(icon: "arrow.counterclockwise", tint: AZ.orange, title: "Reset All Data") { confirmReset = true }
                        divider
                        row(icon: "rectangle.portrait.and.arrow.right", tint: AZ.lavender, title: "Sign Out") { confirmSignOut = true }
                        divider
                        row(icon: "trash.fill", tint: AZ.red, title: "Delete Account", destructive: true) { confirmDelete = true }
                    }
                    VStack(spacing: 6) {
                        Text("Alchemize \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(LegalText.credit)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .cosmicNavigation("Settings")
        .alert("Edit Name", isPresented: $editingName) {
            TextField("Your name", text: $nameDraft)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { auth.updateName(trimmed); Haptics.success() }
            }
        }
        .confirmationDialog("Sign out of Alchemize?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { auth.signOut() }
        }
        .confirmationDialog("Reset all data?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset Everything", role: .destructive) { resetData() }
        } message: {
            Text("This permanently removes all your boards, goals, habits, logs and entries on this device.")
        }
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                resetData()
                auth.deleteAccount()
            }
        } message: {
            Text("Your account and all data on this device will be permanently deleted. This cannot be undone.")
        }
        .sheet(item: $legal) { page in
            LegalSheet(page: page)
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 10) {
            Text(String((auth.user?.name ?? "A").prefix(1)).uppercased())
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .background(AZ.primaryGradient, in: .circle)
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 2))
                .shadow(color: AZ.violet.opacity(0.6), radius: 18)
            Text(auth.user?.name ?? "")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(auth.user?.email ?? "")
                .font(.subheadline)
                .foregroundStyle(AZ.textSecondary)
        }
        .padding(.top, 8)
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.08)).frame(height: 1).padding(.leading, 52)
    }

    private func group<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(AZ.lavender.opacity(0.8))
                .padding(.leading, 6)
            VStack(spacing: 0) { content() }
                .glassCard(radius: 20, padding: 0)
        }
    }

    private func row(icon: String, tint: Color, title: String, value: String = "", chevron: Bool = true, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.15), in: .rect(cornerRadius: 8))
                Text(title).foregroundStyle(destructive ? AZ.red : .white)
                Spacer()
                if !value.isEmpty {
                    Text(value).foregroundStyle(AZ.textSecondary).lineLimit(1)
                }
                if chevron {
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.squish(0.98))
    }

    private func themeOption(_ id: String, title: String, icon: String) -> some View {
        let selected = theme == id
        return Button {
            Haptics.select()
            withAnimation(.snappy) { theme = id }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(selected ? .white : AZ.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selected ? AZ.purple.opacity(0.35) : .white.opacity(0.05), in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? AZ.purple : .white.opacity(0.1), lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.squish)
    }

    private func setVisible(_ f: Feature, _ visible: Bool) {
        var set = hidden
        if visible { set.remove(f.rawValue) } else {
            // Keep at least one feature on the home screen.
            guard Feature.allCases.count - set.count > 1 else { Haptics.warning(); return }
            set.insert(f.rawValue)
        }
        Haptics.select()
        hiddenRaw = Feature.allCases.map(\.rawValue).filter { set.contains($0) }.joined(separator: ",")
    }

    private func resetData() {
        try? context.delete(model: Manifestation.self)
        try? context.delete(model: Affirmation.self)
        try? context.delete(model: GoalChecklistItem.self)
        try? context.delete(model: GoalCompletion.self)
        try? context.delete(model: Goal.self)
        try? context.delete(model: HabitLog.self)
        try? context.delete(model: Habit.self)
        try? context.delete(model: TodoTask.self)
        try? context.delete(model: GratitudeEntry.self)
        try? context.delete(model: Appointment.self)
        try? context.delete(model: FinanceEntry.self)
        try? context.delete(model: FinanceNotes.self)
        try? context.delete(model: FoodLog.self)
        try? context.delete(model: WaterLog.self)
        try? context.delete(model: NutritionProfile.self)
        try? context.delete(model: MealPlanItem.self)
        try? context.delete(model: WorkoutSession.self)
        try? context.save()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        Haptics.success()
    }
}

private struct LegalSheet: View {
    let page: SettingsView.LegalPage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SheetCanvas {
                switch page {
                case .about:
                    Text("Alchemize is your personal transformation toolkit — a place to align intention with action.")
                        .foregroundStyle(.white)
                    ForEach(LegalText.about, id: \.self) { line in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkle").foregroundStyle(AZ.violetLight)
                            Text(line).foregroundStyle(AZ.textSecondary)
                        }
                    }
                case .terms:
                    sections(LegalText.terms)
                case .privacy:
                    sections(LegalText.privacy)
                }
                Text(LegalText.credit)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
            .navigationTitle(page == .about ? "About" : page == .terms ? "Terms of Service" : "Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationBackground(AZ.night)
    }

    private func sections(_ items: [(String, String)]) -> some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            VStack(alignment: .leading, spacing: 6) {
                Text(item.0).font(.headline).foregroundStyle(.white)
                Text(item.1).font(.subheadline).foregroundStyle(AZ.textSecondary).lineSpacing(3)
            }
        }
    }
}
