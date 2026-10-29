import SwiftUI
import CoreMotion

@Observable
final class TiltMotion {
    var x: CGFloat = 0
    var y: CGFloat = 0
    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.attitude else { return }
            let maxTilt = Double.pi / 5
            let range: Double = 18
            let nx = max(-maxTilt, min(maxTilt, a.roll)) / maxTilt * range
            let ny = max(-maxTilt, min(maxTilt, a.pitch - 0.6)) / maxTilt * range
            withAnimation(.interpolatingSpring(stiffness: 120, damping: 25)) {
                self.x = nx
                self.y = ny
            }
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}

struct HomeView: View {
    @Binding var path: NavigationPath
    @AppStorage(Prefs.hiddenFeaturesKey) private var hiddenRaw = ""
    @AppStorage(Prefs.themeKey) private var theme = "classic"
    @State private var current: Feature?
    @State private var appeared = false
    @State private var tilt = TiltMotion()

    private var features: [Feature] { Prefs.visible(from: hiddenRaw) }
    private var index: Int { features.firstIndex(of: current ?? features.first ?? .manifestation) ?? 0 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background(size: geo.size)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    carousel(size: geo.size)
                    footer
                        .padding(.bottom, 24)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            Haptics.tap()
                            path.append(Route.settings)
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(.black.opacity(theme == "cosmic" ? 0.6 : 0.5), in: .circle)
                                .overlay(Circle().strokeBorder(theme == "cosmic" ? AZ.violetLight.opacity(0.4) : .white.opacity(0.2), lineWidth: theme == "cosmic" ? 2 : 1))
                                .shadow(color: theme == "cosmic" ? AZ.violetLight.opacity(0.5) : .black.opacity(0.3), radius: 12, y: 4)
                        }
                        .buttonStyle(.squish(0.9))
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if current == nil || !features.contains(current!) { current = features.first }
            withAnimation(.easeOut(duration: 0.55)) { appeared = true }
            if theme == "cosmic" { tilt.start() }
        }
        .onDisappear { tilt.stop() }
        .onChange(of: theme) { _, new in new == "cosmic" ? tilt.start() : tilt.stop() }
        .onChange(of: current) { _, _ in Haptics.select() }
    }

    @ViewBuilder
    private func background(size: CGSize) -> some View {
        if theme == "cosmic" {
            ZStack {
                Color.black
                RemoteImage(url: AZImages.cosmicBackground)
                    .scaledToFill()
                    .frame(width: size.width + 50, height: size.height + 50)
                    .offset(x: tilt.x, y: tilt.y)
                Color.black.opacity(0.15)
                StarField(count: 24)
            }
            .ignoresSafeArea()
        } else {
            ZStack {
                Color.black
                RemoteImage(url: AZImages.homeBackground).scaledToFill()
            }
            .ignoresSafeArea()
        }
    }

    private func carousel(size: CGSize) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(features) { feature in
                    Group {
                        if theme == "cosmic" {
                            PlanetCard(feature: feature, index: features.firstIndex(of: feature) ?? 0)
                        } else {
                            FeatureCard(feature: feature, width: min(size.width - 40, 520))
                        }
                    }
                    .frame(width: size.width)
                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : (theme == "cosmic" ? 0.7 : 0.92))
                            .opacity(phase.isIdentity ? 1 : (theme == "cosmic" ? 0.4 : 0.55))
                            .offset(y: phase.isIdentity || theme != "cosmic" ? 0 : 60)
                    }
                    .onTapGesture {
                        Haptics.tap()
                        path.append(Route.feature(feature))
                    }
                    .id(feature)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $current)
        .scrollIndicators(.hidden)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if theme == "cosmic" {
                    arrow("chevron.left", disabled: index == 0) { go(index - 1) }
                }
                HStack(spacing: 8) {
                    ForEach(Array(features.enumerated()), id: \.element) { i, f in
                        Capsule()
                            .fill(i == index ? (theme == "cosmic" ? AZ.violetLight : .white) : .white.opacity(0.3))
                            .frame(width: i == index ? 24 : 6, height: 6)
                            .shadow(color: i == index && theme == "cosmic" ? AZ.violetLight.opacity(0.8) : .clear, radius: 6)
                            .onTapGesture { go(i) }
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: index)
                if theme == "cosmic" {
                    arrow("chevron.right", disabled: index >= features.count - 1) { go(index + 1) }
                }
            }
            Text("\(index + 1) of \(features.count)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .shadow(color: .black.opacity(0.8), radius: 3, y: 1)
                .contentTransition(.numericText())
        }
    }

    private func arrow(_ symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(disabled ? AZ.violetLight.opacity(0.2) : AZ.violetLight)
                .frame(width: 40, height: 40)
                .background(AZ.violetLight.opacity(disabled ? 0.04 : 0.12), in: .circle)
                .overlay(Circle().strokeBorder(AZ.violetLight.opacity(disabled ? 0.1 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.squish(0.9))
        .disabled(disabled)
    }

    private func go(_ i: Int) {
        guard features.indices.contains(i) else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { current = features[i] }
    }
}

private struct FeatureCard: View {
    let feature: Feature
    let width: CGFloat

    var body: some View {
        let height = min(width + 100, 560)
        ZStack(alignment: .bottomLeading) {
            if feature == .affirmations {
                RemoteImage(url: AZImages.homeBackground).scaledToFill()
            }
            RemoteImage(url: feature.image).scaledToFill()
            LinearGradient(
                stops: feature == .affirmations
                    ? [.init(color: .clear, location: 0), .init(color: .clear, location: 0.5), .init(color: .black.opacity(0.75), location: 1)]
                    : [.init(color: .clear, location: 0), .init(color: .black.opacity(0.4), location: 0.5), .init(color: .black.opacity(0.85), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 10) {
                Text(feature.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                Text(feature.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineSpacing(4)
            }
            .shadow(color: .black.opacity(0.8), radius: 4, y: 2)
            .padding(24)
            .padding(.bottom, 4)
        }
        .frame(width: width, height: height)
        .background(.white.opacity(0.1))
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        .contentShape(.rect(cornerRadius: 24))
    }
}

private struct PlanetCard: View {
    let feature: Feature
    let index: Int
    @State private var float = false

    var body: some View {
        VStack(spacing: 24) {
            RemoteImage(url: feature.image)
                .scaledToFill()
                .frame(width: 190, height: 190)
                .clipShape(.circle)
                .overlay(Circle().strokeBorder(AZ.violetLight.opacity(0.35), lineWidth: 1.5))
                .shadow(color: AZ.violet.opacity(0.55), radius: 26)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            VStack(spacing: 8) {
                Text(feature.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text(feature.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .shadow(color: .black.opacity(0.7), radius: 4, y: 2)
            .padding(.horizontal, 40)
        }
        .offset(y: float ? -15 : 0)
        .padding(.bottom, 60)
        .contentShape(.rect)
        .onAppear {
            withAnimation(.easeInOut(duration: 3 + Double(index) * 0.4).repeatForever(autoreverses: true)) {
                float = true
            }
        }
    }
}
