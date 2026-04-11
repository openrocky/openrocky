//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI
import UIKit

final class OpenRockyEmptyStateView: UIView {
    /// Called when the user taps a quick action button.
    var onQuickAction: ((String) -> Void)?

    private static let quickActions: [(icon: String, title: String, prompt: String)] = [
        ("sparkles", "What can you do?", "What can you do? Show me your capabilities."),
        ("figure.walk", "Steps This Week", "How many steps did I walk in the past 7 days?"),
        ("cloud.sun.fill", "Weather", "What's the weather like today?"),
        ("calendar", "Today's Events", "What events do I have today?"),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setup() {
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Rocky"
        titleLabel.font = .systemFont(ofSize: 22, weight: .black).rounded()
        titleLabel.textColor = .white.withAlphaComponent(0.30)
        titleLabel.textAlignment = .center

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Hey, what can I do for you?"
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .medium).rounded()
        subtitleLabel.textColor = .white.withAlphaComponent(0.20)
        subtitleLabel.textAlignment = .center

        // Quick action buttons — two rows
        let row1 = UIStackView()
        row1.axis = .horizontal
        row1.spacing = 8
        row1.alignment = .center
        row1.distribution = .fill

        let row2 = UIStackView()
        row2.axis = .horizontal
        row2.spacing = 8
        row2.alignment = .center
        row2.distribution = .fill

        for (index, action) in Self.quickActions.enumerated() {
            let button = makeQuickActionButton(icon: action.icon, title: action.title, tag: index)
            if index < 2 {
                row1.addArrangedSubview(button)
            } else {
                row2.addArrangedSubview(button)
            }
        }

        let buttonsStack = UIStackView(arrangedSubviews: [row1, row2])
        buttonsStack.axis = .vertical
        buttonsStack.spacing = 10
        buttonsStack.alignment = .center

        // Main vertical stack
        let mainStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, buttonsStack])
        mainStack.axis = .vertical
        mainStack.spacing = 0
        mainStack.alignment = .center
        mainStack.setCustomSpacing(6, after: titleLabel)
        mainStack.setCustomSpacing(28, after: subtitleLabel)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            mainStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            mainStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
        ])
    }

    private func makeQuickActionButton(icon: String, title: String, tag: Int) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: icon)?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        )
        config.title = title
        config.baseForegroundColor = .white.withAlphaComponent(0.55)
        config.baseBackgroundColor = .white.withAlphaComponent(0.08)
        config.cornerStyle = .capsule
        config.imagePadding = 5
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = UIFont.systemFont(ofSize: 12, weight: .semibold).rounded()
            return attrs
        }

        let button = UIButton(configuration: config)
        button.tag = tag
        button.addTarget(self, action: #selector(quickActionTapped(_:)), for: .touchUpInside)
        return button
    }

    @objc private func quickActionTapped(_ sender: UIButton) {
        guard sender.tag < Self.quickActions.count else { return }
        let action = Self.quickActions[sender.tag]
        onQuickAction?(action.prompt)
    }
}

// MARK: - UIFont helper

private extension UIFont {
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
