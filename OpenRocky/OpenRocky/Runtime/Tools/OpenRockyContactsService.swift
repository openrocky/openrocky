//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Contacts
import Foundation

@MainActor
final class OpenRockyContactsService {
    static let shared = OpenRockyContactsService()

    private let store = CNContactStore()

    private func requestAccess() async throws {
        let granted = try await store.requestAccess(for: .contacts)
        guard granted else {
            throw OpenRockyContactsError.permissionDenied
        }
    }

    /// Returns total contact count and group summary (no personal data).
    func summary() async throws -> [String: Any] {
        try await requestAccess()
        let keys: [CNKeyDescriptor] = [CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var count = 0
        try store.enumerateContacts(with: request) { _, _ in count += 1 }
        return ["total_contacts": count]
    }

    /// Search contacts by name. Pass "*" or empty to list all (limited to `limit`).
    func search(query: String, limit: Int = 1000) async throws -> [[String: String]] {
        try await requestAccess()

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
        ]

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cap = max(1, limit)
        var results: [CNContact] = []

        if trimmed.isEmpty || trimmed == "*" {
            // Enumerate all contacts
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            request.sortOrder = .familyName
            try store.enumerateContacts(with: request) { contact, stop in
                results.append(contact)
                if results.count >= cap { stop.pointee = true }
            }
        } else {
            // Name-based search
            let predicate = CNContact.predicateForContacts(matchingName: trimmed)
            results = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        }

        return results.prefix(cap).map(formatContact)
    }

    private func formatContact(_ contact: CNContact) -> [String: String] {
        var entry: [String: String] = [:]

        let fullName = [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !fullName.isEmpty { entry["name"] = fullName }
        if !contact.organizationName.isEmpty { entry["organization"] = contact.organizationName }

        let phones = contact.phoneNumbers.map { $0.value.stringValue }
        if !phones.isEmpty { entry["phones"] = phones.joined(separator: ", ") }

        let emails = contact.emailAddresses.map { $0.value as String }
        if !emails.isEmpty { entry["emails"] = emails.joined(separator: ", ") }

        if let birthday = contact.birthday, let date = Calendar.current.date(from: birthday) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            entry["birthday"] = formatter.string(from: date)
        }

        return entry
    }
}

enum OpenRockyContactsError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Contacts access was denied. Please enable it in Settings."
        }
    }
}
