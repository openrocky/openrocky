//
//  Created by ktiays on 2025/2/28.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import UIKit

final class ToolHintView: MessageListRowView {
    var text: String?

    var toolName: String = .init()

    var toolIcon: String?

    var result: String? {
        didSet { updateDetailText() }
    }

    var state: ToolCallState = .running {
        didSet {
            updateContentText()
            updateStateImage()
            updateDetailText()
        }
    }

    var clickHandler: (() -> Void)?

    private let backgroundGradientLayer = CAGradientLayer()
    private let label: ShimmerTextLabel = .init().with {
        $0.font = UIFont.preferredFont(forTextStyle: .footnote)
        $0.textColor = .label
        $0.minimumScaleFactor = 0.5
        $0.adjustsFontForContentSizeCategory = true
        $0.lineBreakMode = .byTruncatingTail
        $0.numberOfLines = 1
        $0.adjustsFontSizeToFitWidth = true
        $0.textAlignment = .left
        $0.animationDuration = 1.6
    }

    private let detailLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.preferredFont(forTextStyle: .caption2)
        l.textColor = .secondaryLabel
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        l.isHidden = true
        return l
    }()

    private let symbolView: UIImageView = .init().with {
        $0.contentMode = .scaleAspectFit
    }

    private let stateBadge: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()

    private var isClickable: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundGradientLayer.startPoint = .init(x: 0.6, y: 0)
        backgroundGradientLayer.endPoint = .init(x: 0.4, y: 1)

        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 10
        contentView.layer.cornerCurve = .continuous
        contentView.layer.insertSublayer(backgroundGradientLayer, at: 0)
        contentView.addSubview(symbolView)
        contentView.addSubview(stateBadge)
        contentView.addSubview(label)
        contentView.addSubview(detailLabel)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        contentView.addGestureRecognizer(tapGesture)

        updateStateImage()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let labelSize = label.intrinsicContentSize
        let hasDetail = !detailLabel.isHidden
        let detailSize = hasDetail ? detailLabel.intrinsicContentSize : .zero
        let totalTextHeight = hasDetail ? labelSize.height + 2 + detailSize.height : labelSize.height
        let topY = (contentView.bounds.height - totalTextHeight) / 2
        let iconSize: CGFloat = 14

        symbolView.frame = .init(
            x: 8,
            y: topY + (labelSize.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )

        // State badge: small overlay at bottom-right of icon
        let badgeSize: CGFloat = 8
        stateBadge.frame = .init(
            x: symbolView.frame.maxX - badgeSize + 2,
            y: symbolView.frame.maxY - badgeSize + 2,
            width: badgeSize,
            height: badgeSize
        )

        label.frame = .init(
            x: symbolView.frame.maxX + 6,
            y: topY,
            width: labelSize.width,
            height: labelSize.height
        )

        if hasDetail {
            let maxDetailWidth = max(0, 280 - label.frame.minX - 12)
            detailLabel.frame = .init(
                x: label.frame.minX,
                y: label.frame.maxY + 1,
                width: min(detailSize.width, maxDetailWidth),
                height: detailSize.height
            )
            contentView.frame.size.width = max(label.frame.maxX, detailLabel.frame.maxX) + 12
        } else {
            contentView.frame.size.width = label.frame.maxX + 12
        }

        backgroundGradientLayer.frame = contentView.bounds
        backgroundGradientLayer.cornerRadius = contentView.layer.cornerRadius
    }

    override func themeDidUpdate() {
        super.themeDidUpdate()
        label.font = theme.fonts.footnote
    }

    private func updateStateImage() {
        let configuration = UIImage.SymbolConfiguration(scale: .small)
        let iconName = toolIcon ?? stateDefaultIconName
        let image = UIImage(systemName: iconName, withConfiguration: configuration)
        symbolView.image = image

        let badgeConfig = UIImage.SymbolConfiguration(pointSize: 8, weight: .bold)

        switch state {
        case .succeeded:
            backgroundGradientLayer.colors = [
                UIColor.systemGreen.withAlphaComponent(0.08).cgColor,
                UIColor.systemGreen.withAlphaComponent(0.12).cgColor,
            ]
            symbolView.tintColor = .systemGreen
            if toolIcon != nil {
                stateBadge.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: badgeConfig)
                stateBadge.tintColor = .systemGreen
                stateBadge.isHidden = false
            } else {
                stateBadge.isHidden = true
            }
            label.stopShimmer()
        case .running:
            backgroundGradientLayer.colors = [
                UIColor.systemBlue.withAlphaComponent(0.08).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.12).cgColor,
            ]
            symbolView.tintColor = .systemBlue
            stateBadge.isHidden = true
            label.startShimmer()
        case .failed:
            backgroundGradientLayer.colors = [
                UIColor.systemRed.withAlphaComponent(0.08).cgColor,
                UIColor.systemRed.withAlphaComponent(0.12).cgColor,
            ]
            symbolView.tintColor = .systemRed
            if toolIcon != nil {
                stateBadge.image = UIImage(systemName: "xmark.circle.fill", withConfiguration: badgeConfig)
                stateBadge.tintColor = .systemRed
                stateBadge.isHidden = false
            } else {
                stateBadge.isHidden = true
            }
            label.stopShimmer()
        }
        invalidateLayout()
    }

    private var stateDefaultIconName: String {
        switch state {
        case .running: "hourglass"
        case .succeeded: "checkmark.seal"
        case .failed: "xmark.seal"
        }
    }

    private func updateContentText() {
        isClickable = true
        label.text = toolName
        invalidateLayout()
    }

    private func updateDetailText() {
        switch state {
        case .running:
            if let summary = parametersSummary() {
                detailLabel.text = summary
                detailLabel.isHidden = false
            } else {
                detailLabel.text = String.localized("Running...")
                detailLabel.isHidden = false
            }
        case .succeeded, .failed:
            // Prefer a human-readable summary from parameters, fall back to result summary
            if let summary = parametersSummary() {
                detailLabel.text = summary
                detailLabel.isHidden = false
            } else if let result, !result.isEmpty {
                detailLabel.text = resultSummary(result)
                detailLabel.isHidden = false
            } else {
                detailLabel.isHidden = true
            }
        }
        invalidateLayout()
    }

    /// Extract a short human-readable summary from the result JSON.
    private func resultSummary(_ result: String) -> String {
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        // Try to extract a meaningful value from JSON
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Look for common summary keys in result
            for key in ["summary", "result", "message", "text", "title", "description", "name", "address", "location", "status"] {
                if let value = json[key] as? String, !value.isEmpty {
                    return String(value.prefix(100))
                }
            }
            // Fall back to first string value
            if let first = json.first(where: { $0.value is String }), let str = first.value as? String {
                return String(str.prefix(100))
            }
        }
        // Plain text result - clean up for display
        let clean = trimmed
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        return String(clean.prefix(100))
    }

    private func parametersSummary() -> String? {
        guard let text, !text.isEmpty, text != "{}" else { return nil }
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        if let query = json["query"] as? String { return query }
        if let title = json["title"] as? String { return title }
        if let key = json["key"] as? String {
            if let value = json["value"] as? String { return "\(key): \(value)" }
            return key
        }
        if let action = json["action"] as? String {
            if let itemTitle = json["title"] as? String { return "\(action): \(itemTitle)" }
            return action
        }
        if let path = json["path"] as? String { return path }
        if let command = json["command"] as? String { return String(command.prefix(60)) }
        if let address = json["address"] as? String { return address }
        if let date = json["date"] as? String { return date }

        let pairs = json.compactMap { k, v -> String? in
            guard let s = v as? String ?? (v as? NSNumber)?.stringValue else { return nil }
            return "\(k): \(s)"
        }.joined(separator: ", ")
        return pairs.isEmpty ? nil : String(pairs.prefix(80))
    }

    func invalidateLayout() {
        label.invalidateIntrinsicContentSize()
        label.sizeToFit()
        detailLabel.invalidateIntrinsicContentSize()
        detailLabel.sizeToFit()
        setNeedsLayout()

        doWithAnimation {
            self.layoutIfNeeded()
        }
    }

    @objc
    private func handleTap(_ sender: UITapGestureRecognizer) {
        if isClickable, sender.state == .ended {
            clickHandler?()
        }
    }
}
