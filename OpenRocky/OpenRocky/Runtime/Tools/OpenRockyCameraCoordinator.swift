//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import UIKit

final class OpenRockyCameraCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private var continuation: CheckedContinuation<Data, Error>?

    init(continuation: CheckedContinuation<Data, Error>) {
        self.continuation = continuation
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage,
              let data = image.jpegData(compressionQuality: 0.8) else {
            continuation?.resume(throwing: CameraError.noImage)
            continuation = nil
            return
        }
        continuation?.resume(returning: data)
        continuation = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        continuation?.resume(throwing: CameraError.cancelled)
        continuation = nil
    }

    enum CameraError: Error, LocalizedError {
        case noImage
        case cancelled
        var errorDescription: String? {
            switch self {
            case .noImage: return "Could not capture image"
            case .cancelled: return "Camera was cancelled by user"
            }
        }
    }
}
