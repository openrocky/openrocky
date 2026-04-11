//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-07
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI
import UIKit

// MARK: - Data Model

struct OpenRockyPromptItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let prompt: String
    let category: OpenRockyPromptCategory
}

enum OpenRockyPromptCategory: String, CaseIterable {
    case tools = "Tools"
    case skills = "Skills"
}

// MARK: - Prompt Library

enum OpenRockyPromptLibrary {
    static func allItems() -> [OpenRockyPromptItem] {
        return toolPrompts() + skillPrompts()
    }

    static func toolPrompts() -> [OpenRockyPromptItem] {
        let tools = OpenRockyBuiltInToolStore.shared.tools
        let prompts: [(id: String, prompt: String)] = [
            ("apple-location", "Where am I right now? Show my current location."),
            ("apple-geocode", "What are the coordinates of the Eiffel Tower in Paris?"),
            ("weather", "What's the weather like today and for the rest of the week?"),
            ("nearby-search", "Find coffee shops near me."),
            ("apple-health-summary", "Show me my health summary for today."),
            ("apple-health-metric", "How many steps did I walk this week?"),
            ("memory_get", "What do you remember about me?"),
            ("memory_write", "Remember that my favorite color is blue."),
            ("shell-execute", "Run 'uname -a' to show system info."),
            ("python-execute", "Use Python to calculate the first 20 Fibonacci numbers."),
            ("ffmpeg-execute", "List the formats supported by FFmpeg."),
            ("file-read", "List all files in my workspace."),
            ("file-write", "Create a file called notes.txt with today's date."),
            ("camera-capture", "Take a photo with the camera."),
            ("photo-pick", "Let me pick a photo from my library to analyze."),
            ("file-pick", "Let me pick a file to work with."),
            ("apple-alarm", "Set an alarm for 7:30 AM tomorrow."),
            ("todo", "Show my todo list."),
            ("browser-open", "Open the Apple website for me."),
            ("browser-cookies", "Get my browser cookies for authentication."),
            ("browser-read", "Read the content of https://news.ycombinator.com"),
            ("oauth-authenticate", "Help me authenticate with a third-party service."),
            ("crypto", "Generate an MD5 hash of the text 'hello world'."),
            ("web-search", "Search the web for the latest Swift 6 features."),
            ("apple-calendar-list", "What events do I have on my calendar this week?"),
            ("apple-calendar-create", "Create a meeting called 'Team Sync' tomorrow at 2 PM."),
            ("apple-reminder-list", "Show my pending reminders."),
            ("apple-reminder-create", "Remind me to buy groceries at 6 PM today."),
            ("apple-contacts-search", "Search for John in my contacts."),
            ("email-send", "Send an email to test@example.com saying hello."),
            ("notification-schedule", "Send me a notification in 5 minutes saying 'Time to stretch'."),
            ("open-url", "Open the Settings app."),
        ]

        return prompts.compactMap { entry in
            guard let tool = tools.first(where: { $0.id == entry.id }) else { return nil }
            return OpenRockyPromptItem(
                icon: tool.icon,
                title: tool.displayName,
                subtitle: tool.description,
                prompt: entry.prompt,
                category: .tools
            )
        }
    }

    static func skillPrompts() -> [OpenRockyPromptItem] {
        let skillPrompts: [(name: String, icon: String, prompt: String)] = [
            ("Translator", "character.book.closed.fill", "Translate 'The early bird catches the worm' into Chinese, Japanese, and Korean."),
            ("Summarizer", "doc.text.magnifyingglass", "Summarize the key points of this article: https://en.wikipedia.org/wiki/Artificial_intelligence"),
            ("Writing Coach", "pencil.and.outline", "Proofread and improve this text: 'Their going to the store tommorrow to by some food for there party.'"),
            ("Code Helper", "chevron.left.forwardslash.chevron.right", "Explain what a Python decorator is and give me a practical example."),
            ("Math Solver", "function", "Solve this step by step: If a train leaves at 60 km/h and another at 80 km/h from the same station, how far apart are they after 2.5 hours?"),
            ("Travel Planner", "airplane", "Help me plan a 3-day trip to Tokyo. I like food and history."),
            ("Health Insights", "heart.text.clipboard", "Analyze my health data trends for the past week and give me wellness tips."),
            ("Daily Briefing", "sun.horizon.fill", "Give me my morning briefing."),
            ("Research Assistant", "magnifyingglass", "Research the latest developments in quantum computing in 2026."),
            ("Quick Convert", "arrow.left.arrow.right", "Convert 72 degrees Fahrenheit to Celsius, and 100 miles to kilometers."),
        ]

        return skillPrompts.map { entry in
            let skill = OpenRockyBuiltInSkills.all.first { $0.name == entry.name }
            return OpenRockyPromptItem(
                icon: entry.icon,
                title: entry.name,
                subtitle: skill?.description ?? "",
                prompt: entry.prompt,
                category: .skills
            )
        }
    }
}

// MARK: - SwiftUI View

private struct OpenRockyPromptsPickerView: View {
    let items: [OpenRockyPromptItem]
    let onSelect: (String) -> Void

    var body: some View {
        List {
            ForEach(Array(OpenRockyPromptCategory.allCases.enumerated()), id: \.element) { index, category in
                let categoryItems = items.filter { $0.category == category }
                if !categoryItems.isEmpty {
                    Section {
                        ForEach(categoryItems) { item in
                            Button {
                                onSelect(item.prompt)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: item.icon)
                                        .foregroundStyle(.secondary)
                                        .font(.callout)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Text("\"\(item.prompt)\"")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                    } header: {
                        VStack(spacing: 2) {
                            if index == 0 {
                                Text("Prompts")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            Text(LocalizedStringKey(category.rawValue))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - UIKit Bridge (used by LanguageModelChatUI)

final class OpenRockyPromptsPickerViewController: UIViewController {

    var onPromptSelected: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        let items = OpenRockyPromptLibrary.allItems()
        let callback = onPromptSelected
        let pickerView = OpenRockyPromptsPickerView(
            items: items,
            onSelect: { [weak self] prompt in
                self?.dismiss(animated: true) {
                    callback?(prompt)
                }
            }
        )
        let hostingView = UIHostingController(rootView: pickerView)

        addChild(hostingView)
        hostingView.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView.view)
        NSLayoutConstraint.activate([
            hostingView.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingView.didMove(toParent: self)
    }
}
