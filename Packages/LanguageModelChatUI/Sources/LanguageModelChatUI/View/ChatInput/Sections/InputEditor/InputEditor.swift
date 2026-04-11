//
//  InputEditor.swift
//  LanguageModelChatUI
//

import Combine
import UIKit

class InputEditor: EditorSectionView {
    let font = UIFont.preferredFont(forTextStyle: .body)
    let textHeight: CurrentValueSubject<CGFloat, Never> = .init(0)
    let maxTextEditorHeight: CGFloat = 200

    let elementClipper = UIView()

    let conversationListButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        btn.setImage(UIImage(systemName: "list.bullet", withConfiguration: config), for: .normal)
        btn.tintColor = .secondaryLabel
        return btn
    }()
    let bossButton = IconButton(icon: "camera")
    let textView = TextEditorView()
    let placeholderLabel = UILabel()
    let voiceButton = IconButton(icon: "mic")
    let moreButton = IconButton(icon: "plus.circle")
    let sendButton = IconButton(icon: "send")

    // Voice mode elements
    let voiceKeyboardButton = UIButton(type: .system)
    let voiceStopButton = UIButton(type: .system)
    let voiceOrbView = VoiceOrbView()
    let voiceStatusLabel = UILabel()

    /// When true, only the + button and text/send are shown (no camera or mic).
    var minimalistLayout: Bool = true

    let inset: UIEdgeInsets = .init(top: 10, left: 10, bottom: 10, right: 10)
    let iconSpacing: CGFloat = 10
    let iconSize = CGSize(width: 30, height: 30)

    var isControlPanelOpened: Bool = false {
        didSet { moreButton.change(icon: isControlPanelOpened ? "x.circle" : "plus.circle") }
    }

    enum LayoutStatus {
        case standard
        case preFocusText
        case editingText
        case voice
    }

    /// Voice mode height (approx 2x text mode).
    let voiceModeHeight: CGFloat = 120

    var layoutStatus: LayoutStatus = .standard {
        didSet {
            guard oldValue != layoutStatus else { return }
            if layoutStatus == .voice {
                heightPublisher.send(voiceModeHeight)
            } else if oldValue == .voice {
                // Recalculate text-based height
                let h = max(textLayoutHeight(textHeight.value), iconSize.height) + inset.top + inset.bottom
                heightPublisher.send(h)
            }
            setNeedsLayout()
        }
    }

    /// Configuration injected from ChatInputView.
    var configuration: ChatInputConfiguration = .default

    weak var delegate: Delegate?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func initializeViews() {
        super.initializeViews()

        conversationListButton.addTarget(self, action: #selector(conversationListTapped), for: .touchUpInside)
        bossButton.tapAction = { [weak self] in
            self?.delegate?.onInputEditorCaptureButtonTapped()
        }
        addSubview(elementClipper)
        elementClipper.addSubview(conversationListButton)
        elementClipper.clipsToBounds = true
        elementClipper.addSubview(bossButton)
        textView.font = font
        textView.delegate = self
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.alwaysBounceVertical = false
        textView.alwaysBounceHorizontal = false
        textView.textColor = .label
        textView.textAlignment = .natural
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineBreakMode = .byTruncatingTail
        textView.textContainer.lineFragmentPadding = .zero
        textView.textContainer.maximumNumberOfLines = 0
        textView.clipsToBounds = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.onReturnKeyPressed = { [weak self] in
            guard let self else { return }
            textView.insertText("\n")
        }
        textView.onCommandReturnKeyPressed = { [weak self] in
            self?.sendButton.tapAction()
        }
        textView.onImagePasted = { [weak self] image in
            self?.delegate?.onInputEditorPastingImage(image: image)
        }
        elementClipper.addSubview(textView)
        placeholderLabel.text = String.localized("Type something...")
        placeholderLabel.font = font
        placeholderLabel.textColor = .placeholderText
        elementClipper.addSubview(placeholderLabel)
        voiceButton.tapAction = { [weak self] in
            self?.delegate?.onInputEditorMicButtonTapped()
        }
        elementClipper.addSubview(voiceButton)
        moreButton.tapAction = { [weak self] in
            self?.isControlPanelOpened.toggle()
            self?.setNeedsLayout()
            self?.delegate?.onInputEditorToggleMoreButtonTapped()
        }
        elementClipper.addSubview(moreButton)
        sendButton.tapAction = { [weak self] in
            self?.delegate?.onInputEditorSubmitButtonTapped()
        }
        elementClipper.addSubview(sendButton)

        // Voice mode elements
        voiceKeyboardButton.setImage(
            UIImage(systemName: "keyboard")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            ),
            for: .normal
        )
        voiceKeyboardButton.tintColor = .label
        voiceKeyboardButton.addTarget(self, action: #selector(voiceKeyboardTapped), for: .touchUpInside)
        voiceKeyboardButton.alpha = 0
        elementClipper.addSubview(voiceKeyboardButton)

        voiceStopButton.setTitle(String.localized("End"), for: .normal)
        voiceStopButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        voiceStopButton.setTitleColor(.white, for: .normal)
        voiceStopButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.85)
        voiceStopButton.layer.cornerRadius = 15
        voiceStopButton.addTarget(self, action: #selector(voiceStopTapped), for: .touchUpInside)
        voiceStopButton.alpha = 0
        elementClipper.addSubview(voiceStopButton)

        voiceOrbView.alpha = 0
        elementClipper.addSubview(voiceOrbView)

        voiceStatusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        voiceStatusLabel.textColor = .secondaryLabel
        voiceStatusLabel.textAlignment = .center
        voiceStatusLabel.text = String.localized("Listening...")
        voiceStatusLabel.alpha = 0
        elementClipper.addSubview(voiceStatusLabel)

        textHeight.removeDuplicates()
            .compactMap { [weak self] textHeight -> CGFloat? in
                guard let self else { return nil }
                if layoutStatus == .voice {
                    return voiceModeHeight
                }
                return max(textLayoutHeight(textHeight), iconSize.height)
                    + inset.top + inset.bottom
            }
            .ensureMainThread()
            .sink { [weak self] height in self?.heightPublisher.send(height) }
            .store(in: &cancellables)
        updateTextHeight()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        elementClipper.frame = bounds

        switch layoutStatus {
        case .standard:
            layoutAsStandard()
        case .preFocusText:
            layoutAsPreEditingText()
        case .editingText:
            layoutAsEditingText()
        case .voice:
            layoutAsVoice()
        }

        updatePlaceholderAlpha()
    }

    func set(text: String) {
        textView.text = text
        updatePlaceholderAlpha()
        switchToRequiredStatus()
        updateTextHeight()
    }

    @objc private func conversationListTapped() {
        delegate?.onInputEditorConversationListTapped()
    }

    @objc private func voiceStopTapped() {
        delegate?.onInputEditorVoiceSessionStop()
    }

    @objc private func voiceKeyboardTapped() {
        delegate?.onInputEditorVoiceSessionToggle()
    }

    /// Enter or exit voice mode externally (e.g. from top-right button).
    func setVoiceMode(_ active: Bool) {
        if active {
            textView.resignFirstResponder()
            doWithAnimation { [self] in
                layoutStatus = .voice
            }
        } else {
            doWithAnimation { [self] in
                layoutStatus = .standard
            }
        }
    }

    /// Update voice status text shown in voice mode.
    func updateVoiceStatus(_ text: String) {
        voiceStatusLabel.text = text
    }
}
