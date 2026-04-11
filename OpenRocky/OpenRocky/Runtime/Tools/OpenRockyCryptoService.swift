//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import CommonCrypto
import CryptoKit
import Foundation

/// Provides cryptographic operations as a tool, replacing Python pycryptodome.
@MainActor
final class OpenRockyCryptoService {
    static let shared = OpenRockyCryptoService()

    // MARK: - HMAC

    func hmacSHA256(key: Data, message: Data) -> String {
        let hmac = HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: key))
        return Data(hmac).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Hash

    func sha256(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func md5(data: Data) -> String {
        Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - AES

    func aesEncryptCBC(key: Data, iv: Data, plaintext: Data) throws -> Data {
        try aesOperation(key: key, iv: iv, data: plaintext, operation: CCOperation(kCCEncrypt))
    }

    func aesDecryptCBC(key: Data, iv: Data, ciphertext: Data) throws -> Data {
        try aesOperation(key: key, iv: iv, data: ciphertext, operation: CCOperation(kCCDecrypt))
    }

    private func aesOperation(key: Data, iv: Data, data: Data, operation: CCOperation) throws -> Data {
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesProcessed = 0

        let status = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                data.withUnsafeBytes { dataBytes in
                    CCCrypt(
                        operation,
                        CCAlgorithm(kCCAlgorithmAES128),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, key.count,
                        ivBytes.baseAddress,
                        dataBytes.baseAddress, data.count,
                        &buffer, bufferSize,
                        &numBytesProcessed
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw CryptoError.aesOperationFailed(status: status)
        }
        return Data(buffer.prefix(numBytesProcessed))
    }

    // MARK: - Base64

    func base64Encode(data: Data) -> String {
        data.base64EncodedString()
    }

    func base64Decode(string: String) throws -> Data {
        guard let data = Data(base64Encoded: string) else {
            throw CryptoError.invalidBase64
        }
        return data
    }

    enum CryptoError: Error, LocalizedError {
        case aesOperationFailed(status: CCCryptorStatus)
        case invalidBase64
        case invalidHex

        var errorDescription: String? {
            switch self {
            case let .aesOperationFailed(status): return "AES operation failed (status: \(status))"
            case .invalidBase64: return "Invalid base64 string"
            case .invalidHex: return "Invalid hex string"
            }
        }
    }
}
