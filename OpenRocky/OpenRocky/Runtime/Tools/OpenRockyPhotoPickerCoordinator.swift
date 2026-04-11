//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import PhotosUI
import UIKit

@MainActor
final class OpenRockyPhotoPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
    private var continuation: CheckedContinuation<Data, Error>?

    init(continuation: CheckedContinuation<Data, Error>) {
        self.continuation = continuation
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else {
            continuation?.resume(throwing: PhotoPickerError.cancelled)
            continuation = nil
            return
        }

        let itemProvider = result.itemProvider
        guard itemProvider.canLoadObject(ofClass: UIImage.self) else {
            continuation?.resume(throwing: PhotoPickerError.unsupportedType)
            continuation = nil
            return
        }

        itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            let result: Result<Data, Error>
            if let error {
                result = .failure(error)
            } else if let image = object as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.8) {
                result = .success(data)
            } else {
                result = .failure(PhotoPickerError.noImage)
            }
            Task { @MainActor in
                self?.continuation?.resume(with: result)
                self?.continuation = nil
            }
        }
    }

    enum PhotoPickerError: Error, LocalizedError {
        case cancelled
        case noImage
        case unsupportedType
        var errorDescription: String? {
            switch self {
            case .cancelled: return "Photo selection was cancelled"
            case .noImage: return "Could not load selected image"
            case .unsupportedType: return "Selected item is not an image"
            }
        }
    }
}
