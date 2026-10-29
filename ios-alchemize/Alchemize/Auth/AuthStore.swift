import Foundation
import Security
import CryptoKit
import Observation

enum Keychain {
    static func set(_ data: Data, for key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}

struct AppUser: Codable, Equatable {
    var id: String
    var email: String
    var name: String
    var provider: String
}

private struct StoredUser: Codable {
    var user: AppUser
    var passwordHash: String
}

enum AuthError: LocalizedError {
    case fillFields, invalidEmail, shortPassword, exists, invalidCredentials, enterName

    var errorDescription: String? {
        switch self {
        case .fillFields: "Please fill in all fields"
        case .invalidEmail: "Please enter a valid email address"
        case .shortPassword: "Password must be at least 6 characters"
        case .exists: "An account with this email already exists"
        case .invalidCredentials: "Invalid email or password"
        case .enterName: "Please enter your name"
        }
    }
}

@Observable
final class AuthStore {
    private(set) var user: AppUser?
    var isAuthenticated: Bool { user != nil }

    private let sessionKey = "alchemize.session"
    private let usersKey = "alchemize.users"

    init() {
        if let data = Keychain.get(sessionKey), let u = try? JSONDecoder().decode(AppUser.self, from: data) {
            user = u
        }
    }

    private func users() -> [StoredUser] {
        guard let data = Keychain.get(usersKey) else { return [] }
        return (try? JSONDecoder().decode([StoredUser].self, from: data)) ?? []
    }

    private func save(users: [StoredUser]) {
        if let data = try? JSONEncoder().encode(users) { Keychain.set(data, for: usersKey) }
    }

    private func hash(_ password: String, email: String) -> String {
        let digest = SHA256.hash(data: Data("\(email.lowercased()):alchemize:\(password)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func setSession(_ u: AppUser?) {
        user = u
        if let u, let data = try? JSONEncoder().encode(u) {
            Keychain.set(data, for: sessionKey)
        } else {
            Keychain.delete(sessionKey)
        }
    }

    func login(email: String, password: String) throws {
        let email = email.trimmingCharacters(in: .whitespaces)
        guard !email.isEmpty, !password.isEmpty else { throw AuthError.fillFields }
        guard let match = users().first(where: { $0.user.email.lowercased() == email.lowercased() }),
              match.passwordHash == hash(password, email: email) else { throw AuthError.invalidCredentials }
        setSession(match.user)
    }

    func signup(email: String, password: String, name: String) throws {
        let email = email.trimmingCharacters(in: .whitespaces)
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { throw AuthError.enterName }
        guard !email.isEmpty, !password.isEmpty else { throw AuthError.fillFields }
        guard email.contains("@"), email.contains(".") else { throw AuthError.invalidEmail }
        guard password.count >= 6 else { throw AuthError.shortPassword }
        var all = users()
        guard !all.contains(where: { $0.user.email.lowercased() == email.lowercased() }) else { throw AuthError.exists }
        let u = AppUser(id: UUID().uuidString, email: email, name: name, provider: "email")
        all.append(StoredUser(user: u, passwordHash: hash(password, email: email)))
        save(users: all)
        setSession(u)
    }

    func loginWithApple(userId: String, email: String?, fullName: String?) {
        var all = users()
        if let existing = all.first(where: { $0.user.id == userId }) {
            setSession(existing.user)
            return
        }
        let u = AppUser(id: userId, email: email ?? "", name: (fullName?.isEmpty == false ? fullName! : "Alchemist"), provider: "apple")
        all.append(StoredUser(user: u, passwordHash: ""))
        save(users: all)
        setSession(u)
    }

    func updateName(_ name: String) {
        guard var u = user else { return }
        u.name = name
        var all = users()
        if let i = all.firstIndex(where: { $0.user.id == u.id }) { all[i].user = u; save(users: all) }
        setSession(u)
    }

    func signOut() { setSession(nil) }

    func deleteAccount() {
        guard let u = user else { return }
        save(users: users().filter { $0.user.id != u.id })
        setSession(nil)
    }
}
