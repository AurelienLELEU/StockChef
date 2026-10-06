import Foundation
import CryptoKit

struct EncryptedBackupEnvelope: Codable {
    let format: String
    let salt: Data
    let sealedData: Data
}

enum EncryptedBackupService {
    static func encrypt(_ data: Data, password: String) throws -> Data {
        guard password.count >= 8 else { throw EncryptedBackupError.passwordTooShort }
        let salt = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
        let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(password.utf8)), salt: salt, info: Data("BTBU.StockChef.Backup.v1".utf8), outputByteCount: 32)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw EncryptedBackupError.encryptionFailed }
        return try JSONEncoder().encode(EncryptedBackupEnvelope(format: "StockChef.encrypted.v1", salt: salt, sealedData: combined))
    }

    static func decrypt(_ data: Data, password: String) throws -> Data {
        let envelope = try JSONDecoder().decode(EncryptedBackupEnvelope.self, from: data)
        guard envelope.format == "StockChef.encrypted.v1" else { throw EncryptedBackupError.invalidFile }
        let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(password.utf8)), salt: envelope.salt, info: Data("BTBU.StockChef.Backup.v1".utf8), outputByteCount: 32)
        let box = try AES.GCM.SealedBox(combined: envelope.sealedData)
        return try AES.GCM.open(box, using: key)
    }
}

enum EncryptedBackupError: LocalizedError {
    case passwordTooShort, encryptionFailed, invalidFile
    var errorDescription: String? { switch self { case .passwordTooShort: "Choisissez un mot de passe d’au moins 8 caractères."; case .encryptionFailed: "La sauvegarde chiffrée n’a pas pu être créée."; case .invalidFile: "Ce fichier chiffré StockChef est invalide." } }
}
