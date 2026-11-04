import Foundation

enum LegalText {
    static let credit = "Development by CRF Enterprise\nPowered & Designed by Metallicv1"

    static let authTermsEN = """
    By using Alchemize you agree to the following:

    1. Use at Your Own Risk. This app is provided "as is" without warranties of any kind. Content (affirmations, fitness, nutrition, financial and wellness data) is for personal informational purposes only and is not professional medical, legal, or financial advice.

    2. Data & Privacy. We store the data you create (goals, habits, photos, journals, health metrics) to operate the app. We use industry-standard practices but no system is 100% secure.

    3. No Liability for Data Leaks. To the maximum extent permitted by law, Alchemize, its developers and affiliates are NOT responsible or liable for any data breaches, leaks, loss, unauthorized access, or damages arising from use of the app or third-party services (including Apple and Supabase).

    4. Your Responsibility. You are responsible for keeping your account credentials secure and for the content you upload. Do not share sensitive medical, legal, or financial details that you would not want stored.

    5. Consent. By tapping "I Agree" you confirm you have read, understood, and accepted these terms and our Privacy Policy.

    —

    \(credit)
    """

    static let authTermsES = """
    Al usar Alchemize aceptas lo siguiente:

    1. Uso Bajo Tu Propio Riesgo. Esta app se proporciona "tal cual" sin garantías de ningún tipo. El contenido (afirmaciones, fitness, nutrición, datos financieros y de bienestar) es solo para fines informativos personales y no constituye asesoramiento médico, legal o financiero profesional.

    2. Datos y Privacidad. Almacenamos los datos que creas (metas, hábitos, fotos, diarios, métricas de salud) para operar la app. Usamos prácticas estándar de la industria, pero ningún sistema es 100% seguro.

    3. Sin Responsabilidad por Filtraciones. En la máxima medida permitida por la ley, Alchemize, sus desarrolladores y afiliados NO son responsables de filtraciones, pérdidas, accesos no autorizados o daños derivados del uso de la app o de servicios de terceros (incluidos Apple y Supabase).

    4. Tu Responsabilidad. Eres responsable de mantener seguras tus credenciales y del contenido que subes.

    5. Consentimiento. Al tocar "Acepto" confirmas que has leído, entendido y aceptado estos términos y nuestra Política de Privacidad.

    —

    \(credit)
    """

    static let terms: [(String, String)] = [
        ("1. Agreement", "By downloading, accessing, or using Alchemize (\"App\"), you agree to these Terms & Conditions (\"Terms\"). If you do not agree, do not use the App."),
        ("2. Eligibility", "You must be at least 13 years old to use Alchemize. If you are under 18, you must have permission from a parent/guardian."),
        ("3. Not Medical or Financial Advice", "Alchemize provides self-improvement tools (e.g., affirmations, habit tracking, fitness/diet logging, goal setting, journaling, finance tracking). The App does not provide medical, mental health, legal, or financial advice and is not a substitute for professional services. Always consult qualified professionals for advice specific to your situation."),
        ("4. Your Account & Security", "You are responsible for maintaining the confidentiality of your login credentials and for all activity under your account. Notify us immediately if you suspect unauthorized access."),
        ("5. Your Content", "You may input content such as text entries, goals, journal notes, photos, and other materials (\"User Content\"). You retain ownership of your User Content. You grant Alchemize a limited license to store, process, and display your User Content solely to operate and improve the App."),
        ("6. Acceptable Use", "You agree not to:\n• Use the App for unlawful purposes\n• Attempt to hack, disrupt, or reverse engineer the App\n• Upload malicious code or abuse the platform\n• Infringe the rights of others"),
        ("7. Privacy", "Your use of Alchemize is also governed by our Privacy Policy. Where these Terms and the Privacy Policy conflict, the Privacy Policy controls for privacy-related topics."),
        ("8. Subscriptions & Payments (if applicable)", "If Alchemize offers paid features, subscription terms, pricing, and billing details will be shown at purchase. Payments are processed by the relevant app store. Refunds follow the app store's refund policy unless otherwise required by law."),
        ("9. Changes to the App", "We may update, modify, or discontinue features of the App at any time. We are not liable for any modifications, suspensions, or discontinuation."),
        ("10. Disclaimer of Warranties", "The App is provided \"as is\" and \"as available.\" We make no warranties of any kind, express or implied, including fitness for a particular purpose and non-infringement."),
        ("11. Limitation of Liability", "To the maximum extent permitted by law, Alchemize and its creators will not be liable for indirect, incidental, special, consequential, or punitive damages, or any loss of data, profits, or revenue arising from your use of the App."),
        ("12. Termination", "We may suspend or terminate access to the App if you violate these Terms or if required for security or legal reasons."),
        ("13. Governing Law", "These Terms are governed by the laws of the jurisdiction where Alchemize is operated, without regard to conflict of law rules."),
        ("14. Contact", "For support or legal questions, contact: Admin@crfenterprise.com"),
    ]

    static let privacy: [(String, String)] = [
        ("1. Overview", "This Privacy Policy explains how Alchemize collects, uses, and protects your information when you use the App."),
        ("2. Information We Collect", "• Account info: name, email, login identifiers\n• Profile info: display name\n• App content you create: affirmations, goals, habits, journal entries, logs (fitness, diet, finance), and similar entries\n• Device/app data: app version, device type, crash logs, and performance metrics (for reliability and improvement)"),
        ("3. How We Use Information", "We use your information to:\n• Provide and operate app features\n• Save and sync your data (if sync is enabled)\n• Improve performance, reliability, and user experience\n• Provide support and respond to requests\n• Protect against fraud, abuse, or security threats"),
        ("4. Sharing", "We do not sell your personal information. We may share information with:\n• Service providers that help operate the App (hosting, analytics, storage), under confidentiality obligations\n• Legal authorities if required by law or to protect safety and rights"),
        ("5. Data Storage & Security", "Your entries are stored on your device. Account credentials are protected in the iOS Keychain. No method of storage is 100% secure."),
        ("6. Your Choices", "• You can update your profile name in Settings\n• You can sign out at any time\n• You may request access, correction, or deletion of your data by contacting Admin@crfenterprise.com"),
        ("7. Retention", "We keep your data for as long as your account is active or as needed to provide the App. You can reset all data from Settings at any time."),
        ("8. Children's Privacy", "Alchemize is not directed to children under 13, and we do not knowingly collect personal information from them."),
        ("9. Changes", "We may update this Privacy Policy from time to time. Continued use of the App means you accept the updated policy."),
        ("10. Contact", "Questions? Contact Admin@crfenterprise.com"),
    ]

    static let about = [
        "Build a Manifest Board to keep your future front and center",
        "Write and repeat Affirmations to reprogram self-talk",
        "Set Goals and break them into aligned, measurable steps",
        "Track Habits to create consistency and identity change",
        "Log Fitness and Diet to support discipline and energy",
        "Track Finances to build clarity and reduce scarcity thinking",
        "Use Journals and planning tools to reflect, reset, and move forward",
    ]
}
