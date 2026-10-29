import SwiftUI
import AuthenticationServices

private struct AuthStrings {
    let title, subtitle, login, signup, email, password, fullName, forgot, or, mustAgree, agree, terms: String
    let resetTitle, resetMessage, sendReset, cancel, resetSent, termsTitle, termsIntro, termsBody, iAgree, decline: String

    static let en = AuthStrings(
        title: "Alchemize", subtitle: "Transform Your Life", login: "Sign In", signup: "Sign Up",
        email: "Email", password: "Password", fullName: "Full Name", forgot: "Forgot Password?",
        or: "or continue with", mustAgree: "You must agree to the Terms to continue",
        agree: "I agree to the", terms: "Terms & Privacy",
        resetTitle: "Reset Password", resetMessage: "Enter your email to receive reset instructions",
        sendReset: "Send Reset Link", cancel: "Cancel", resetSent: "Reset link sent! Check your email.",
        termsTitle: "Terms & Privacy Agreement", termsIntro: "Please read carefully before using Alchemize.",
        termsBody: LegalText.authTermsEN, iAgree: "I Agree & Continue", decline: "Decline"
    )
    static let es = AuthStrings(
        title: "Alchemize", subtitle: "Transforma Tu Vida", login: "Iniciar Sesión", signup: "Registrarse",
        email: "Correo", password: "Contraseña", fullName: "Nombre Completo", forgot: "¿Olvidaste tu contraseña?",
        or: "o continúa con", mustAgree: "Debes aceptar los Términos para continuar",
        agree: "Acepto los", terms: "Términos y Privacidad",
        resetTitle: "Restablecer Contraseña", resetMessage: "Ingresa tu correo para recibir instrucciones",
        sendReset: "Enviar Enlace", cancel: "Cancelar", resetSent: "¡Enlace enviado! Revisa tu correo.",
        termsTitle: "Acuerdo de Términos y Privacidad", termsIntro: "Por favor lee con atención antes de usar Alchemize.",
        termsBody: LegalText.authTermsES, iAgree: "Acepto y Continuar", decline: "Rechazar"
    )
}

struct AuthView: View {
    @Environment(AuthStore.self) private var auth
    @AppStorage("auth.language") private var language = "en"
    @AppStorage("auth.agreedTerms") private var agreed = false

    @State private var isSignup = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var error = ""
    @State private var showTerms = false
    @State private var showReset = false
    @State private var resetEmail = ""
    @State private var appear = false
    @FocusState private var focus: Field?

    private enum Field { case name, email, password }
    private var t: AuthStrings { language == "es" ? .es : .en }

    var body: some View {
        ZStack(alignment: .top) {
            AZ.deep.ignoresSafeArea()
            GeometryReader { geo in
                RemoteImage(url: AZImages.crystalBall)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height * 0.62)
                    .scaleEffect(appear ? 1 : 1.08)
            }
            .ignoresSafeArea()
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color(hex: 0x080214, opacity: 0.6), location: 0.35),
                    .init(color: Color(hex: 0x080214, opacity: 0.95), location: 0.55),
                    .init(color: AZ.deep, location: 0.7),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 220)
                    VStack(spacing: 6) {
                        Text(t.title)
                            .font(.system(size: 46, weight: .bold, design: .serif))
                            .foregroundStyle(
                                LinearGradient(colors: [.white, AZ.lavender], startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: AZ.violet.opacity(0.8), radius: 18)
                        Text(t.subtitle)
                            .font(.headline)
                            .foregroundStyle(AZ.lavender)
                            .tracking(1.2)
                    }
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 16)

                    card
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 30)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)

            HStack {
                Spacer()
                Button {
                    Haptics.select()
                    language = language == "en" ? "es" : "en"
                } label: {
                    Label(language == "en" ? "ES" : "EN", systemImage: "globe")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AZ.lavender)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: .capsule)
                }
                .buttonStyle(.squish)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) { appear = true }
        }
        .sheet(isPresented: $showTerms) { termsSheet }
        .alert(t.resetTitle, isPresented: $showReset) {
            TextField(t.email, text: $resetEmail)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            Button(t.cancel, role: .cancel) {}
            Button(t.sendReset) {
                error = resetEmail.contains("@") ? "" : "Please enter your email address"
                if error.isEmpty { Haptics.success() }
            }
        } message: {
            Text(t.resetMessage)
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            // Tabs
            HStack(spacing: 4) {
                tab(t.login, active: !isSignup) { isSignup = false }
                tab(t.signup, active: isSignup) { isSignup = true }
            }
            .padding(4)
            .background(Color.white.opacity(0.06), in: .capsule)

            if isSignup {
                field(t.fullName, text: $name, icon: "person", field: .name)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            field(t.email, text: $email, icon: "envelope", field: .email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            HStack {
                Image(systemName: "lock").foregroundStyle(AZ.violetLight).frame(width: 20)
                Group {
                    if showPassword {
                        TextField("", text: $password, prompt: Text(t.password).foregroundStyle(.white.opacity(0.4)))
                    } else {
                        SecureField("", text: $password, prompt: Text(t.password).foregroundStyle(.white.opacity(0.4)))
                    }
                }
                .focused($focus, equals: .password)
                .textInputAutocapitalization(.never)
                .submitLabel(.go)
                .onSubmit(submit)
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye").foregroundStyle(.white.opacity(0.5))
                }
            }
            .cosmicField()

            if !isSignup {
                HStack {
                    Spacer()
                    Button(t.forgot) { resetEmail = email; showReset = true }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AZ.violetLight)
                }
            }

            Button {
                Haptics.select()
                agreed.toggle()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: agreed ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(agreed ? AZ.violetLight : .white.opacity(0.4))
                    Text(t.agree).foregroundStyle(.white.opacity(0.7))
                    + Text(" " + t.terms).foregroundStyle(AZ.violetLight).bold()
                    Spacer()
                }
                .font(.footnote)
            }
            .buttonStyle(.plain)
            Button { showTerms = true } label: {
                Text(t.termsTitle).font(.caption).underline().foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !error.isEmpty {
                Text(error)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color(hex: 0xFCA5A5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            GradientButton(
                title: isSignup ? t.signup : t.login,
                gradient: LinearGradient(colors: [AZ.purple, AZ.violet, AZ.violetDeep], startPoint: .leading, endPoint: .trailing),
                action: submit
            )

            HStack {
                Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
                Text(t.or).font(.caption).foregroundStyle(.white.opacity(0.5)).fixedSize()
                Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
            }

            SignInWithAppleButton(isSignup ? .signUp : .signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleApple(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .clipShape(.capsule)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isSignup)
        .animation(.easeOut(duration: 0.2), value: error)
        .glassCard(radius: 28, tint: AZ.violetLight, padding: 20)
    }

    private func tab(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.select()
            error = ""
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(active ? .white : .white.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background {
                    if active {
                        Capsule().fill(LinearGradient(colors: [AZ.purple, AZ.violetDeep], startPoint: .leading, endPoint: .trailing))
                            .shadow(color: AZ.violet.opacity(0.6), radius: 8)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func field(_ placeholder: String, text: Binding<String>, icon: String, field: Field) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(AZ.violetLight).frame(width: 20)
            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.4)))
                .focused($focus, equals: field)
                .autocorrectionDisabled()
        }
        .cosmicField()
    }

    private func submit() {
        guard agreed else { error = t.mustAgree; Haptics.warning(); return }
        do {
            if isSignup {
                try auth.signup(email: email, password: password, name: name)
            } else {
                try auth.login(email: email, password: password)
            }
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
            Haptics.warning()
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        guard agreed else { error = t.mustAgree; return }
        switch result {
        case .success(let authorization):
            guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            let name = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
            auth.loginWithApple(userId: cred.user, email: cred.email, fullName: name)
            Haptics.success()
        case .failure(let err):
            if (err as? ASAuthorizationError)?.code != .canceled {
                error = "Apple sign in failed. Please try again."
            }
        }
    }

    private var termsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(t.termsIntro).font(.headline).foregroundStyle(AZ.lavender)
                    Text(t.termsBody).font(.callout).foregroundStyle(.white.opacity(0.85)).lineSpacing(4)
                }
                .padding(20)
            }
            .background(AZ.night.ignoresSafeArea())
            .navigationTitle(t.termsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button(t.decline) { agreed = false; showTerms = false }
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.white.opacity(0.08), in: .capsule)
                    GradientButton(title: t.iAgree) { agreed = true; error = ""; showTerms = false }
                }
                .padding(20)
                .background(.ultraThinMaterial)
            }
        }
        .preferredColorScheme(.dark)
    }
}
