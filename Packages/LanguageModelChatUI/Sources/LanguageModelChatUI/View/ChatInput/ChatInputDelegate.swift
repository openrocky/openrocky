//
//  ChatInputDelegate.swift
//  LanguageModelChatUI
//

import UIKit

/// Delegate protocol for handling chat input events.
@MainActor
public protocol ChatInputDelegate: AnyObject {
    /// Called when the user submits input. Call `completion(true)` to confirm, `false` to reject.
    func chatInputDidSubmit(_ input: ChatInputView, object: ChatInputContent, completion: @escaping @Sendable (Bool) -> Void)
    /// Called when the input content changes.
    func chatInputDidUpdateObject(_ input: ChatInputView, object: ChatInputContent)
    /// Called to request a previously saved object for restoration.
    func chatInputDidRequestObjectForRestore(_ input: ChatInputView) -> ChatInputContent?
    /// Called when an error occurs in the input view.
    func chatInputDidReportError(_ input: ChatInputView, error: String)
    /// Called when user toggles voice session on/off from the input bar.
    func chatInputDidToggleVoiceSession(_ input: ChatInputView)
    /// Called when user stops the voice session from the input bar.
    func chatInputDidStopVoiceSession(_ input: ChatInputView)
    /// Called when user taps the conversation list button.
    func chatInputDidTapConversationList(_ input: ChatInputView)
    /// Called when user taps the prompts button in the control panel.
    func chatInputDidTapPrompts(_ input: ChatInputView)
    /// Called when user taps the mic button to start STT dictation (speech-to-text into the text field).
    func chatInputDidRequestDictation(_ input: ChatInputView)
    /// Called when user cancels an in-progress dictation.
    func chatInputDidCancelDictation(_ input: ChatInputView)
}

/// Default implementations making all methods optional.
@MainActor
public extension ChatInputDelegate {
    func chatInputDidUpdateObject(_: ChatInputView, object _: ChatInputContent) {}
    func chatInputDidRequestObjectForRestore(_: ChatInputView) -> ChatInputContent? {
        nil
    }

    func chatInputDidReportError(_: ChatInputView, error _: String) {}
    func chatInputDidToggleVoiceSession(_: ChatInputView) {}
    func chatInputDidStopVoiceSession(_: ChatInputView) {}
    func chatInputDidTapConversationList(_: ChatInputView) {}
    func chatInputDidTapPrompts(_: ChatInputView) {}
    func chatInputDidRequestDictation(_: ChatInputView) {}
    func chatInputDidCancelDictation(_: ChatInputView) {}
}
