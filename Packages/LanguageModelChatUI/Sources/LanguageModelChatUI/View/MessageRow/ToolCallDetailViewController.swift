//
//  ToolCallDetailViewController.swift
//  LanguageModelChatUI
//

import UIKit

final class ToolCallDetailViewController: UIViewController {

    struct Content {
        let toolName: String
        let toolIcon: String?
        let parameters: String
        let result: String?
        let state: ToolCallState
    }

    private let content: Content

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    init(content: Content) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        // Navigation bar
        title = content.toolName
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissSelf)
        )

        if let iconName = content.toolIcon {
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            let image = UIImage(systemName: iconName, withConfiguration: config)
            let imageView = UIImageView(image: image)
            imageView.tintColor = tintForState(content.state)
            imageView.contentMode = .scaleAspectFit
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: imageView)
        }

        // ScrollView + StackView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])

        // Status badge
        let statusView = makeStatusBadge()
        stackView.addArrangedSubview(statusView)

        // Parameters section
        if !content.parameters.isEmpty, content.parameters != "{}" {
            // Extract highlighted fields (code, command, etc.)
            let highlighted = extractHighlightedFields(from: content.parameters)
            let remaining = removeKeys(highlighted.map(\.key), from: content.parameters)

            if let remaining, !remaining.isEmpty, remaining != "{}" {
                let section = makeSection(
                    title: "Parameters",
                    body: prettyJSON(remaining) ?? remaining
                )
                stackView.addArrangedSubview(section)
            } else if highlighted.isEmpty {
                let section = makeSection(
                    title: "Parameters",
                    body: prettyJSON(content.parameters) ?? content.parameters
                )
                stackView.addArrangedSubview(section)
            }

            for field in highlighted {
                let section = makeCodeSection(title: field.title, code: field.value)
                stackView.addArrangedSubview(section)
            }
        }

        // Result section — extract output if present
        if let result = content.result, !result.isEmpty {
            let resultHighlighted = extractHighlightedFields(from: result)
            let resultRemaining = removeKeys(resultHighlighted.map(\.key), from: result)

            if let resultRemaining, !resultRemaining.isEmpty, resultRemaining != "{}" {
                let section = makeSection(
                    title: "Result",
                    body: prettyJSON(resultRemaining) ?? resultRemaining
                )
                stackView.addArrangedSubview(section)
            } else if resultHighlighted.isEmpty {
                let section = makeSection(
                    title: "Result",
                    body: prettyJSON(result) ?? result
                )
                stackView.addArrangedSubview(section)
            }

            for field in resultHighlighted {
                let section = makeCodeSection(title: field.title, code: field.value)
                stackView.addArrangedSubview(section)
            }
        }
    }

    private func makeStatusBadge() -> UIView {
        let container = UIView()
        let badge = UILabel()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.font = .preferredFont(forTextStyle: .caption1)
        badge.textColor = .white

        let color: UIColor
        switch content.state {
        case .running:
            badge.text = "  Running  "
            color = .systemBlue
        case .succeeded:
            badge.text = "  Succeeded  "
            color = .systemGreen
        case .failed:
            badge.text = "  Failed  "
            color = .systemRed
        }

        badge.backgroundColor = color
        badge.layer.cornerRadius = 8
        badge.layer.cornerCurve = .continuous
        badge.clipsToBounds = true

        container.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: container.topAnchor),
            badge.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            badge.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            badge.heightAnchor.constraint(equalToConstant: 24),
        ])
        return container
    }

    private func makeSection(title: String, body: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.text = title
        stack.addArrangedSubview(titleLabel)

        let bodyView = UITextView()
        bodyView.isEditable = false
        bodyView.isScrollEnabled = false
        bodyView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        bodyView.textColor = .secondaryLabel
        bodyView.backgroundColor = UIColor.secondarySystemBackground
        bodyView.layer.cornerRadius = 10
        bodyView.layer.cornerCurve = .continuous
        bodyView.textContainerInset = .init(top: 12, left: 12, bottom: 12, right: 12)
        bodyView.text = body
        stack.addArrangedSubview(bodyView)

        return stack
    }

    private struct HighlightedField {
        let key: String
        let title: String
        let value: String
    }

    /// Keys whose values are code/text worth displaying in a dedicated section.
    private static let highlightKeys: [(key: String, title: String)] = [
        ("code", "Code"),
        ("command", "Command"),
        ("content", "Content"),
        ("output", "Output"),
        ("text", "Text"),
        ("query", "Query"),
    ]

    private func extractHighlightedFields(from jsonString: String) -> [HighlightedField] {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var results: [HighlightedField] = []
        for entry in Self.highlightKeys {
            if let value = json[entry.key] as? String, value.count > 20 {
                let unescaped = value
                    .replacingOccurrences(of: "\\n", with: "\n")
                    .replacingOccurrences(of: "\\t", with: "\t")
                    .replacingOccurrences(of: "\\\"", with: "\"")
                results.append(HighlightedField(key: entry.key, title: entry.title, value: unescaped))
            }
        }
        return results
    }

    private func removeKeys(_ keys: [String], from jsonString: String) -> String? {
        guard !keys.isEmpty,
              let data = jsonString.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return jsonString }
        for key in keys { json.removeValue(forKey: key) }
        if json.isEmpty { return nil }
        guard let result = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: result, encoding: .utf8) else { return nil }
        return str
    }

    private func makeCodeSection(title: String, code: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.text = title
        stack.addArrangedSubview(titleLabel)

        let codeView = UITextView()
        codeView.isEditable = false
        codeView.isScrollEnabled = false
        codeView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        codeView.textColor = .label
        codeView.backgroundColor = UIColor(white: 0.1, alpha: 1)
        codeView.layer.cornerRadius = 10
        codeView.layer.cornerCurve = .continuous
        codeView.textContainerInset = .init(top: 12, left: 12, bottom: 12, right: 12)
        codeView.text = code
        stack.addArrangedSubview(codeView)

        return stack
    }

    private func prettyJSON(_ string: String) -> String? {
        guard let data = string.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: pretty, encoding: .utf8)
        else { return nil }
        return result
    }

    private func tintForState(_ state: ToolCallState) -> UIColor {
        switch state {
        case .running: .systemBlue
        case .succeeded: .systemGreen
        case .failed: .systemRed
        }
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}
