//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import UIKit
import PhotosUI

@MainActor
final class OpenRockyUIPresenterService {
    static let shared = OpenRockyUIPresenterService()

    private weak var presenterViewController: UIViewController?

    func setPresenter(_ vc: UIViewController) {
        presenterViewController = vc
    }

    private var presenter: UIViewController {
        get throws {
            guard let vc = presenterViewController ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController else {
                throw PresenterError.noPresenter
            }
            return vc
        }
    }

    // MARK: - Camera

    func capturePhoto() async throws -> Data {
        let presenter = try self.presenter
        return try await withCheckedThrowingContinuation { continuation in
            let coordinator = OpenRockyCameraCoordinator(continuation: continuation)
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.mediaTypes = ["public.image"]
            picker.delegate = coordinator
            // Prevent coordinator from being deallocated
            objc_setAssociatedObject(picker, &AssociatedKeys.coordinator, coordinator, .OBJC_ASSOCIATION_RETAIN)
            presenter.present(picker, animated: true)
        }
    }

    // MARK: - Photo Library

    func pickPhoto() async throws -> Data {
        let presenter = try self.presenter
        return try await withCheckedThrowingContinuation { continuation in
            var config = PHPickerConfiguration()
            config.selectionLimit = 1
            config.filter = .images
            let coordinator = OpenRockyPhotoPickerCoordinator(continuation: continuation)
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = coordinator
            objc_setAssociatedObject(picker, &AssociatedKeys.coordinator, coordinator, .OBJC_ASSOCIATION_RETAIN)
            presenter.present(picker, animated: true)
        }
    }

    // MARK: - File Picker

    func pickFile() async throws -> (data: Data, filename: String) {
        let presenter = try self.presenter
        return try await withCheckedThrowingContinuation { continuation in
            let coordinator = OpenRockyFilePickerCoordinator(continuation: continuation)
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .image, .text, .plainText, .pdf])
            picker.allowsMultipleSelection = false
            picker.delegate = coordinator
            objc_setAssociatedObject(picker, &AssociatedKeys.coordinator, coordinator, .OBJC_ASSOCIATION_RETAIN)
            presenter.present(picker, animated: true)
        }
    }

    // MARK: - Errors

    enum PresenterError: Error, LocalizedError {
        case noPresenter
        var errorDescription: String? { "No view controller available to present UI" }
    }
}

private enum AssociatedKeys {
    nonisolated(unsafe) static var coordinator: UInt8 = 0
}
