//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Charts
import SwiftUI

struct OpenRockyUsageSettingsView: View {
    @StateObject private var usageService = OpenRockyUsageService.shared
    @State private var selectedRange: UsageRange = .week
    @State private var selectedCategory: OpenRockyUsageCategory? = nil
    @State private var showClearConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCards
                rangePicker
                categoryFilter
                dailyTokenChart
                modelBreakdownSection
                recentActivitySection
                clearDataButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(OpenRockyPalette.background.ignoresSafeArea())
        .navigationTitle("Usage")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear All Usage Data?", isPresented: $showClearConfirmation) {
            Button("Clear", role: .destructive) { usageService.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all recorded usage data.")
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        let summaries = usageService.dailySummaries(category: selectedCategory, days: selectedRange.days)
        let totalTokens = summaries.reduce(0) { $0 + $1.totalTokens }
        let totalRequests = summaries.reduce(0) { $0 + $1.requestCount }
        let avgDaily = summaries.isEmpty ? 0 : totalTokens / max(summaries.count, 1)

        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            SummaryCard(
                title: "Total Tokens",
                value: Self.formatTokenCount(totalTokens),
                icon: "number.circle.fill",
                tint: OpenRockyPalette.accent
            )
            SummaryCard(
                title: "Requests",
                value: "\(totalRequests)",
                icon: "arrow.up.arrow.down.circle.fill",
                tint: OpenRockyPalette.secondary
            )
            SummaryCard(
                title: "Avg / Day",
                value: Self.formatTokenCount(avgDaily),
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                tint: OpenRockyPalette.success
            )
        }
        .padding(.top, 8)
    }

    // MARK: - Range Picker

    private var rangePicker: some View {
        HStack(spacing: 0) {
            ForEach(UsageRange.allCases) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedRange = range }
                } label: {
                    Text(range.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selectedRange == range ? .white : OpenRockyPalette.muted)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedRange == range
                                ? OpenRockyPalette.accent.opacity(0.25)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(OpenRockyPalette.card, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        HStack(spacing: 8) {
            CategoryPill(title: "All", isSelected: selectedCategory == nil) {
                withAnimation { selectedCategory = nil }
            }
            CategoryPill(title: "Chat", isSelected: selectedCategory == .chat, tint: OpenRockyPalette.accent) {
                withAnimation { selectedCategory = .chat }
            }
            CategoryPill(title: "Voice", isSelected: selectedCategory == .voice, tint: OpenRockyPalette.secondary) {
                withAnimation { selectedCategory = .voice }
            }
            Spacer()
        }
    }

    // MARK: - Daily Token Chart

    private var dailyTokenChart: some View {
        let summaries = usageService.dailySummaries(category: selectedCategory, days: selectedRange.days)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Tokens")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(OpenRockyPalette.text)
                Spacer()
                if !summaries.isEmpty {
                    Text("\(selectedRange.label)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(OpenRockyPalette.muted)
                }
            }

            if summaries.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(summaries) { summary in
                        BarMark(
                            x: .value("Date", summary.date, unit: .day),
                            y: .value("Prompt", summary.promptTokens)
                        )
                        .foregroundStyle(OpenRockyPalette.accent.gradient)

                        BarMark(
                            x: .value("Date", summary.date, unit: .day),
                            y: .value("Completion", summary.completionTokens)
                        )
                        .foregroundStyle(OpenRockyPalette.secondary.gradient)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: xAxisStride)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(OpenRockyPalette.strokeSubtle)
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.system(size: 10))
                                    .foregroundStyle(OpenRockyPalette.label)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(OpenRockyPalette.strokeSubtle)
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text(Self.formatTokenCount(intValue))
                                    .font(.system(size: 10))
                                    .foregroundStyle(OpenRockyPalette.label)
                            }
                        }
                    }
                }
                .chartPlotStyle { content in
                    content.frame(height: 200)
                }
                .chartLegend(position: .bottom, spacing: 16) {
                    HStack(spacing: 16) {
                        LegendItem(color: OpenRockyPalette.accent, label: "Prompt")
                        LegendItem(color: OpenRockyPalette.secondary, label: "Completion")
                    }
                }
            }
        }
        .padding(16)
        .background(OpenRockyPalette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var xAxisStride: Int {
        switch selectedRange {
        case .week: 1
        case .twoWeeks: 2
        case .month: 5
        }
    }

    // MARK: - Model Breakdown

    private var modelBreakdownSection: some View {
        let models = usageService.modelSummaries(category: selectedCategory, days: selectedRange.days)
        let maxTokens = models.first?.totalTokens ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            Text("Model Breakdown")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(OpenRockyPalette.text)

            if models.isEmpty {
                HStack {
                    Spacer()
                    Text("No usage data yet")
                        .font(.system(size: 13))
                        .foregroundStyle(OpenRockyPalette.muted)
                    Spacer()
                }
                .padding(.vertical, 24)
            } else {
                // Donut chart
                if models.count > 1 {
                    Chart(models) { model in
                        SectorMark(
                            angle: .value("Tokens", model.totalTokens),
                            innerRadius: .ratio(0.618),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("Model", model.displayName))
                        .cornerRadius(4)
                    }
                    .chartLegend(position: .bottom, spacing: 12)
                    .frame(height: 180)
                    .padding(.bottom, 8)
                }

                // Bar breakdown per model
                ForEach(models) { model in
                    VStack(spacing: 6) {
                        HStack {
                            Circle()
                                .fill(colorForModel(model, in: models))
                                .frame(width: 8, height: 8)
                            Text(model.displayName)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(OpenRockyPalette.text)
                                .lineLimit(1)
                            Spacer()
                            Text(Self.formatTokenCount(model.totalTokens))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(OpenRockyPalette.muted)
                            Text("\(model.requestCount) req")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(OpenRockyPalette.label)
                        }
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(colorForModel(model, in: models).opacity(0.35))
                                .frame(
                                    width: geo.size.width * CGFloat(model.totalTokens) / CGFloat(maxTokens),
                                    height: 6
                                )
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .padding(16)
        .background(OpenRockyPalette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        let recent = Array(usageService.records.suffix(10).reversed())

        return VStack(alignment: .leading, spacing: 12) {
            Text("Recent Requests")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(OpenRockyPalette.text)

            if recent.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 28))
                            .foregroundStyle(OpenRockyPalette.label)
                        Text("Usage data will appear here")
                            .font(.system(size: 13))
                            .foregroundStyle(OpenRockyPalette.muted)
                    }
                    Spacer()
                }
                .padding(.vertical, 24)
            } else {
                ForEach(recent) { record in
                    HStack(spacing: 10) {
                        Image(systemName: record.category == .chat ? "bubble.left.fill" : "waveform")
                            .font(.system(size: 12))
                            .foregroundStyle(record.category == .chat ? OpenRockyPalette.accent : OpenRockyPalette.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.model)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(OpenRockyPalette.text)
                                .lineLimit(1)
                            Text(record.provider)
                                .font(.system(size: 10))
                                .foregroundStyle(OpenRockyPalette.label)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Self.formatTokenCount(record.totalTokens))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(OpenRockyPalette.text)
                            Text(record.date.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 10))
                                .foregroundStyle(OpenRockyPalette.label)
                        }
                    }
                    .padding(.vertical, 4)

                    if record.id != recent.last?.id {
                        Divider().overlay(OpenRockyPalette.separator)
                    }
                }
            }
        }
        .padding(16)
        .background(OpenRockyPalette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Clear Data

    private var clearDataButton: some View {
        Button {
            showClearConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Clear All Usage Data")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.red.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis.ascending")
                .font(.system(size: 32))
                .foregroundStyle(OpenRockyPalette.label)
            Text("No usage data for this period")
                .font(.system(size: 13))
                .foregroundStyle(OpenRockyPalette.muted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - Helpers

    private static func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private let modelColors: [Color] = [
        OpenRockyPalette.accent,
        OpenRockyPalette.secondary,
        OpenRockyPalette.success,
        OpenRockyPalette.warning,
        .purple,
        .pink,
        .indigo,
        .mint
    ]

    private func colorForModel(_ model: OpenRockyUsageModelSummary, in models: [OpenRockyUsageModelSummary]) -> Color {
        guard let index = models.firstIndex(where: { $0.id == model.id }) else {
            return OpenRockyPalette.accent
        }
        return modelColors[index % modelColors.count]
    }
}

// MARK: - Supporting Views

private struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(OpenRockyPalette.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(OpenRockyPalette.label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(OpenRockyPalette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(OpenRockyPalette.strokeSubtle, lineWidth: 1)
        )
    }
}

private struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    var tint: Color = OpenRockyPalette.text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : OpenRockyPalette.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    isSelected ? tint.opacity(0.3) : OpenRockyPalette.cardElevated,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(OpenRockyPalette.muted)
        }
    }
}

// MARK: - Range Enum

private enum UsageRange: String, CaseIterable, Identifiable {
    case week
    case twoWeeks
    case month

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: "7 Days"
        case .twoWeeks: "14 Days"
        case .month: "30 Days"
        }
    }

    var days: Int {
        switch self {
        case .week: 7
        case .twoWeeks: 14
        case .month: 30
        }
    }
}
