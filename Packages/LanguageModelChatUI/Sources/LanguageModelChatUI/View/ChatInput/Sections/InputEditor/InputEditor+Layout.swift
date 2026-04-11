//
//  InputEditor+Layout.swift
//  LanguageModelChatUI
//

import UIKit

extension InputEditor {
    func textLayoutHeight(_ input: CGFloat) -> CGFloat {
        var finalHeight = input
        finalHeight = max(font.lineHeight, finalHeight)
        finalHeight = min(finalHeight, maxTextEditorHeight)
        return ceil(finalHeight)
    }

    func switchToRequiredStatus() {
        assert(Thread.isMainThread)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(switchToRequiredStatusEx), object: nil)
        perform(#selector(switchToRequiredStatusEx), with: nil, afterDelay: 0.1)
    }

    @objc private func switchToRequiredStatusEx() {
        guard layoutStatus != .voice else { return }
        doWithAnimation { [self] in
            bossButton.transform = .identity
            moreButton.transform = .identity
            sendButton.transform = .identity
            voiceButton.transform = .identity
            if textView.isFirstResponder {
                if textView.text.isEmpty {
                    layoutStatus = .preFocusText
                } else {
                    layoutStatus = .editingText
                }
            } else {
                if textView.text.isEmpty {
                    layoutStatus = .standard
                } else {
                    layoutStatus = .editingText
                }
            }
        }
    }

    func hideVoiceModeElements() {
        voiceKeyboardButton.alpha = 0
        voiceStopButton.alpha = 0
        voiceOrbView.alpha = 0
        voiceOrbView.stopAnimating()
        voiceStatusLabel.alpha = 0
        conversationListButton.alpha = 0
    }

    func layoutAsEditingText() {
        hideVoiceModeElements()
        conversationListButton.alpha = 0
        sendButton.frame = CGRect(
            x: bounds.width - inset.right - iconSize.width,
            y: bounds.height - iconSize.height - inset.bottom,
            width: iconSize.width,
            height: iconSize.height
        )
        sendButton.alpha = 1
        moreButton.frame = CGRect(
            x: bounds.width - inset.right - iconSize.width,
            y: bounds.height - iconSize.height - inset.bottom,
            width: iconSize.width,
            height: iconSize.height
        )
        defer { moreButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5) }
        moreButton.alpha = 0

        let textLeading = inset.left
        let textTrailing: CGFloat
        if minimalistLayout {
            voiceButton.alpha = 0
            textTrailing = sendButton.frame.minX - iconSpacing
        } else {
            voiceButton.frame = CGRect(
                x: sendButton.frame.minX - iconSize.width - iconSpacing,
                y: sendButton.frame.minY,
                width: iconSize.width,
                height: iconSize.height
            )
            voiceButton.alpha = 1
            textTrailing = voiceButton.frame.minX - iconSpacing
        }

        let textLayoutHeight = textLayoutHeight(textHeight.value)
        textView.frame = CGRect(
            x: textLeading,
            y: (bounds.height - textLayoutHeight) / 2,
            width: textTrailing - textLeading,
            height: textLayoutHeight
        )
        placeholderLabel.frame = textView.frame

        bossButton.frame = CGRect(
            x: 0 - inset.left - iconSize.width,
            y: inset.top,
            width: iconSize.width,
            height: iconSize.height
        )
        bossButton.alpha = 0
    }

    func layoutAsPreEditingText() {
        hideVoiceModeElements()
        defer { bossButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5) }
        defer { sendButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5) }

        conversationListButton.alpha = 0

        bossButton.frame = CGRect(
            x: 0 - inset.left - iconSize.width,
            y: inset.top,
            width: iconSize.width,
            height: iconSize.height
        )
        bossButton.alpha = 0

        moreButton.frame = CGRect(
            x: bounds.width - inset.right - iconSize.width,
            y: inset.top,
            width: iconSize.width,
            height: iconSize.height
        )
        moreButton.alpha = 1

        let textTrailing: CGFloat
        if minimalistLayout {
            voiceButton.alpha = 0
            textTrailing = moreButton.frame.minX - iconSpacing
        } else {
            voiceButton.frame = CGRect(
                x: moreButton.frame.minX - iconSize.width - iconSpacing,
                y: inset.top,
                width: iconSize.width,
                height: iconSize.height
            )
            voiceButton.alpha = 1
            textTrailing = voiceButton.frame.minX - iconSpacing
        }

        let textLayoutHeight = textLayoutHeight(textHeight.value)
        textView.frame = CGRect(
            x: inset.left,
            y: (bounds.height - textLayoutHeight) / 2,
            width: textTrailing - inset.left,
            height: textLayoutHeight
        )
        textView.alpha = 1
        placeholderLabel.frame = textView.frame

        sendButton.frame = CGRect(
            x: bounds.width + iconSpacing + inset.right,
            y: bounds.height - iconSize.height - inset.bottom,
            width: iconSize.width,
            height: iconSize.height
        )
        sendButton.alpha = 0
    }

    func layoutAsVoice() {
        // Hide text-mode elements
        bossButton.alpha = 0
        textView.alpha = 0
        placeholderLabel.alpha = 0
        voiceButton.alpha = 0
        moreButton.alpha = 0
        sendButton.alpha = 0

        let bottomRow: CGFloat = bounds.height - inset.bottom - iconSize.height

        // Keyboard toggle button (bottom-left)
        voiceKeyboardButton.frame = CGRect(
            x: inset.left,
            y: bottomRow,
            width: iconSize.width,
            height: iconSize.height
        )
        voiceKeyboardButton.alpha = 1

        // Stop button (bottom-right)
        let stopWidth: CGFloat = 64
        let stopHeight: CGFloat = 30
        voiceStopButton.frame = CGRect(
            x: bounds.width - inset.right - stopWidth,
            y: bottomRow + (iconSize.height - stopHeight) / 2,
            width: stopWidth,
            height: stopHeight
        )
        voiceStopButton.alpha = 1

        // Voice orb (centered in upper area)
        let orbSize: CGFloat = 44
        let topAreaHeight = bottomRow - inset.top
        let orbCenterY = inset.top + topAreaHeight * 0.35
        voiceOrbView.frame = CGRect(
            x: (bounds.width - orbSize) / 2,
            y: orbCenterY - orbSize / 2,
            width: orbSize,
            height: orbSize
        )
        voiceOrbView.alpha = 1
        voiceOrbView.startAnimating()

        // Status label (below orb)
        let labelY = voiceOrbView.frame.maxY + 6
        voiceStatusLabel.frame = CGRect(
            x: inset.left,
            y: labelY,
            width: bounds.width - inset.left - inset.right,
            height: 18
        )
        voiceStatusLabel.alpha = 1
    }

    func layoutAsStandard() {
        hideVoiceModeElements()
        defer { sendButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5) }

        // Conversation list button at far left
        conversationListButton.frame = CGRect(
            x: inset.left,
            y: inset.top,
            width: iconSize.width,
            height: iconSize.height
        )
        conversationListButton.alpha = 1

        moreButton.frame = CGRect(
            x: bounds.width - inset.right - iconSize.width,
            y: inset.top,
            width: iconSize.width,
            height: iconSize.height
        )
        moreButton.alpha = 1
        moreButton.transform = .identity

        let textLeading: CGFloat
        let textTrailing: CGFloat
        if minimalistLayout {
            bossButton.alpha = 0
            voiceButton.alpha = 0
            textLeading = conversationListButton.frame.maxX + iconSpacing
            textTrailing = moreButton.frame.minX - iconSpacing
        } else {
            bossButton.frame = CGRect(
                x: inset.left,
                y: inset.top,
                width: iconSize.width,
                height: iconSize.height
            )
            bossButton.alpha = 1
            voiceButton.frame = CGRect(
                x: moreButton.frame.minX - iconSize.width - iconSpacing,
                y: inset.top,
                width: iconSize.width,
                height: iconSize.height
            )
            voiceButton.alpha = 1
            textLeading = bossButton.frame.maxX + iconSpacing
            textTrailing = voiceButton.frame.minX - iconSpacing
        }

        let textLayoutHeight = textLayoutHeight(textHeight.value)
        textView.frame = CGRect(
            x: textLeading,
            y: (bounds.height - textLayoutHeight) / 2,
            width: textTrailing - textLeading,
            height: textLayoutHeight
        )
        textView.alpha = 1
        placeholderLabel.frame = textView.frame

        sendButton.frame = CGRect(
            x: bounds.width + inset.right,
            y: inset.top,
            width: iconSize.width,
            height: iconSize.height
        )
        sendButton.alpha = 0
    }
}
