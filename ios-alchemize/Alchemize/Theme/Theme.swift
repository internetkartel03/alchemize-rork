import SwiftUI
import UIKit

// MARK: - Palette (mirrors the Expo app)

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum AZ {
    // Base
    static let night = Color(hex: 0x0C0520)
    static let deep = Color(hex: 0x080214)
    static let ink = Color(hex: 0x040108)
    static let card = Color(hex: 0x0F0A1E, opacity: 0.75)

    // Accents
    static let violet = Color(hex: 0x7C3AED)
    static let violetDeep = Color(hex: 0x6D28D9)
    static let violetLight = Color(hex: 0xA78BFA)
    static let lavender = Color(hex: 0xC4B5FD)
    static let lilac = Color(hex: 0xC9A7FF)
    static let indigo = Color(hex: 0x6366F1)
    static let indigoDeep = Color(hex: 0x4F46E5)
    static let blue = Color(hex: 0x3B82F6)
    static let gold = Color(hex: 0xFFD700)
    static let amber = Color(hex: 0xFBBF24)
    static let honey = Color(hex: 0xF4C95D)
    static let emerald = Color(hex: 0x10B981)
    static let green = Color(hex: 0x22C55E)
    static let red = Color(hex: 0xEF4444)
    static let orange = Color(hex: 0xF97316)
    static let pink = Color(hex: 0xEC4899)
    static let sky = Color(hex: 0x38BDF8)
    static let purple = Color(hex: 0x8B5CF6)

    static let textSecondary = Color(hex: 0xC8BEDC, opacity: 0.8)
    static let textTertiary = Color.white.opacity(0.5)
    static let glassFill = Color.white.opacity(0.08)
    static let glassStroke = Color.white.opacity(0.12)

    static let primaryGradient = LinearGradient(
        colors: [Color(hex: 0x7C3AED), Color(hex: 0x4F46E5), Color(hex: 0x3B82F6)],
        startPoint: .leading, endPoint: .trailing
    )
    static let buttonGradient = LinearGradient(
        colors: [Color(hex: 0x9E38FF), Color(hex: 0x6E49FF), Color(hex: 0x4B73FF)],
        startPoint: .leading, endPoint: .trailing
    )
    static let fabGradient = LinearGradient(
        colors: [Color(hex: 0x7C3AED), Color(hex: 0x6D28D9)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Remote imagery (same artwork as the Expo app)

enum AZImages {
    static let homeBackground = "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/naydnxf8x17oig8jrq47w"
    static let cosmicBackground = "https://fv5-3.files.fm/thumb_show.php?i=7th7rn53er&view&v=1&PHPSESSID=562f76ae684b8b5e8507e14030e7af116d9c6724"
    static let portalBackground = "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/hmtn1lxo3phq29a4dqeyk"
    static let featureBackground = "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/kflyhi3p0jh7nuw0u9n1u"
    static let appointmentsBackground = "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/8vtok42y20eo2gnggtrih"
    static let cosmicStars = "https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=1200"
    static let crystalBall = "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/89z8qu274hk8f1cht7vcg.png"

    static let manifestationCard = "https://fv5-5.files.fm/thumb_show.php?i=j5nnqw66mt&view&v=1&PHPSESSID=562f76ae684b8b5e8507e14030e7af116d9c6724"
    static let affirmationsCard = "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/5xvh01k2ftwt4gog83jwy"
    static let goalsCard = "https://fv5-4.files.fm/thumb_show.php?i=vekk3swk9c&view&v=1&PHPSESSID=562f76ae684b8b5e8507e14030e7af116d9c6724"
    static let habitsCard = "https://fv5-5.files.fm/thumb_show.php?i=67bxj4nwpd&view&v=1&PHPSESSID=562f76ae684b8b5e8507e14030e7af116d9c6724"
    static let financialCard = "https://fv5-4.files.fm/thumb_show.php?i=r42xd2aab8&view&v=1&PHPSESSID=562f76ae684b8b5e8507e14030e7af116d9c6724"
    static let calorieCard = "https://fv5-3.files.fm/thumb_show.php?i=hshtzcda9e&view&v=1&PHPSESSID=562f76ae684b8b5e8507e14030e7af116d9c6724"
    static let todosCard = "https://fv5-4.files.fm/thumb_show.php?i=qnpyxuvuy5&view&v=1&PHPSESSID=562f76ae684b8b5e8507e14030e7af116d9c6724"
    static let gratitudeCard = "https://fv5-4.files.fm/thumb_show.php?i=zqm55g6gzg&view&v=1&PHPSESSID=562f76ae684b8b5e8507e14030e7af116d9c6724"
    static let fitnessCard = "https://fv5-4.files.fm/thumb_show.php?i=yeepyn9ydx&view&v=1&PHPSESSID=562f76ae684b8b5e8507e14030e7af116d9c6724"
    static let appointmentsCard = "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/q6xkbpb7jmofbuzgauyqz"

    static var all: [String] {
        [homeBackground, cosmicBackground, portalBackground, featureBackground, manifestationCard,
         affirmationsCard, goalsCard, habitsCard, financialCard, calorieCard, todosCard,
         gratitudeCard, fitnessCard, appointmentsCard, crystalBall]
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

// MARK: - Press feedback

struct SquishButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SquishButtonStyle {
    static var squish: SquishButtonStyle { SquishButtonStyle() }
    static func squish(_ scale: CGFloat) -> SquishButtonStyle { SquishButtonStyle(scale: scale) }
}

// MARK: - Glass card

struct GlassCard: ViewModifier {
    var radius: CGFloat = 20
    var tint: Color = .white
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Color(hex: 0x120A26, opacity: 0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(tint.opacity(0.14), lineWidth: 1)
                    )
            }
    }
}

extension View {
    func glassCard(radius: CGFloat = 20, tint: Color = .white, padding: CGFloat = 16) -> some View {
        modifier(GlassCard(radius: radius, tint: tint, padding: padding))
    }

    /// Hides the default navigation bar background so imagery shows through.
    func cosmicNavigation(_ title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Backgrounds

struct ImageBackdrop: View {
    let url: String
    var overlay: Color = Color(hex: 0x080316, opacity: 0.55)
    var base: Color = AZ.night

    var body: some View {
        ZStack {
            base
            RemoteImage(url: url)
                .scaledToFill()
            overlay
        }
        .ignoresSafeArea()
    }
}

struct StarField: View {
    var count: Int = 30
    @State private var stars: [Star] = []

    struct Star: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let period: Double
        let phase: Double
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for star in stars {
                    let o = 0.2 + 0.8 * (0.5 + 0.5 * sin((t + star.phase) * 2 * .pi / star.period))
                    let rect = CGRect(x: star.x * size.width, y: star.y * size.height, width: star.size, height: star.size)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(o)))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            guard stars.isEmpty else { return }
            stars = (0..<count).map { _ in
                Star(x: .random(in: 0...1), y: .random(in: 0...1), size: .random(in: 1...3),
                     period: .random(in: 2...5), phase: .random(in: 0...2))
            }
        }
    }
}

// MARK: - Common controls

struct GradientButton: View {
    let title: String
    var icon: String? = nil
    var gradient: LinearGradient = AZ.primaryGradient
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let icon {
                    Image(systemName: icon).font(.headline)
                }
                Text(title).font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(gradient, in: .rect(cornerRadius: 27))
            .shadow(color: AZ.violet.opacity(0.45), radius: 14, y: 6)
        }
        .buttonStyle(.squish)
        .disabled(isLoading)
    }
}

struct FloatingAddButton: View {
    var icon: String = "plus"
    var gradient: LinearGradient = AZ.fabGradient
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(gradient, in: .circle)
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                .shadow(color: AZ.violet.opacity(0.6), radius: 14, y: 6)
        }
        .buttonStyle(.squish(0.9))
    }
}

struct Chip: View {
    let title: String
    var isSelected: Bool
    var tint: Color = AZ.violet
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : AZ.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(isSelected ? tint.opacity(0.55) : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule().strokeBorder(isSelected ? tint.opacity(0.85) : .white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: isSelected ? tint.opacity(0.5) : .clear, radius: 8)
        }
        .buttonStyle(.squish(0.94))
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @State private var float = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AZ.violetLight)
                .shadow(color: AZ.violet.opacity(0.7), radius: 16)
                .offset(y: float ? -6 : 4)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: float)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AZ.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                GradientButton(title: actionTitle, action: action)
                    .frame(maxWidth: 260)
                    .padding(.top, 6)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .onAppear { float = true }
    }
}

struct SectionLabel: View {
    let text: String
    var icon: String? = nil
    var tint: Color = AZ.lavender
    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon).foregroundStyle(tint)
            }
            Text(text)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
        }
    }
}

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AZ.lavender)
            .textCase(.uppercase)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CosmicTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .foregroundStyle(.white)
            .tint(AZ.violetLight)
            .background(Color.white.opacity(0.07), in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }
}

extension View {
    func cosmicField() -> some View { modifier(CosmicTextFieldStyle()) }
}

struct ProgressBar: View {
    var value: Double
    var tint: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
                    .shadow(color: tint.opacity(0.6), radius: 6)
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: value)
    }
}

// MARK: - Formatting

enum Fmt {
    static func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")))
    }
}

extension Calendar {
    func isDateInSameDay(_ a: Date, _ b: Date) -> Bool { isDate(a, inSameDayAs: b) }
}
