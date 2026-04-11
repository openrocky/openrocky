//
//  ChartView.swift
//  MarkdownView
//
//  Created on 2026/4/8.
//

#if canImport(UIKit) && canImport(Charts)
    import Charts
    import SwiftUI
    import UIKit

    final class ChartView: UIView {
        var theme: MarkdownTheme = .default {
            didSet { updateChart() }
        }

        var chartData: ChartData = .init() {
            didSet {
                guard oldValue != chartData else { return }
                updateChart()
            }
        }

        private var hostingController: UIHostingController<AnyView>?

        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.cornerRadius = 8
            layer.cornerCurve = .continuous
            clipsToBounds = true
            backgroundColor = .gray.withAlphaComponent(0.05)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        static let defaultHeight: CGFloat = 240

        override var intrinsicContentSize: CGSize {
            CGSize(
                width: UIView.noIntrinsicMetric,
                height: Self.defaultHeight
            )
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            hostingController?.view.frame = bounds
        }

        private func updateChart() {
            hostingController?.view.removeFromSuperview()
            hostingController = nil

            let data = chartData
            let chartView = Self.makeChartView(data: data)
            let hosting = UIHostingController(rootView: chartView)
            hosting.view.backgroundColor = .clear
            hosting.view.frame = bounds
            addSubview(hosting.view)
            hostingController = hosting
        }

        @MainActor
        private static func makeChartView(data: ChartData) -> AnyView {
            let titleView = data.title.map { title in
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            switch data.type {
            case .bar:
                return AnyView(
                    VStack(spacing: 0) {
                        if let titleView { titleView }
                        Chart(data.entries) { entry in
                            BarMark(
                                x: .value("Label", entry.label),
                                y: .value("Value", entry.value)
                            )
                            .foregroundStyle(.blue.gradient)
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .padding(12)
                    }
                )
            case .line:
                return AnyView(
                    VStack(spacing: 0) {
                        if let titleView { titleView }
                        Chart(data.entries) { entry in
                            LineMark(
                                x: .value("Label", entry.label),
                                y: .value("Value", entry.value)
                            )
                            .foregroundStyle(.blue)
                            PointMark(
                                x: .value("Label", entry.label),
                                y: .value("Value", entry.value)
                            )
                            .foregroundStyle(.blue)
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .padding(12)
                    }
                )
            case .pie:
                if #available(iOS 17.0, macOS 14.0, *) {
                    return AnyView(
                        VStack(spacing: 0) {
                            if let titleView { titleView }
                            Chart(data.entries) { entry in
                                SectorMark(
                                    angle: .value("Value", entry.value),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 1
                                )
                                .foregroundStyle(by: .value("Label", entry.label))
                            }
                            .padding(12)
                        }
                    )
                } else {
                    // Fall back to bar chart on iOS 16
                    return AnyView(
                        VStack(spacing: 0) {
                            if let titleView { titleView }
                            Chart(data.entries) { entry in
                                BarMark(
                                    x: .value("Label", entry.label),
                                    y: .value("Value", entry.value)
                                )
                                .foregroundStyle(.blue.gradient)
                            }
                            .chartYAxis { AxisMarks(position: .leading) }
                            .padding(12)
                        }
                    )
                }
            case .area:
                return AnyView(
                    VStack(spacing: 0) {
                        if let titleView { titleView }
                        Chart(data.entries) { entry in
                            AreaMark(
                                x: .value("Label", entry.label),
                                y: .value("Value", entry.value)
                            )
                            .foregroundStyle(.blue.opacity(0.3).gradient)
                            LineMark(
                                x: .value("Label", entry.label),
                                y: .value("Value", entry.value)
                            )
                            .foregroundStyle(.blue)
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .padding(12)
                    }
                )
            }
        }
    }

    extension ChartView: LTXAttributeStringRepresentable {
        func attributedStringRepresentation() -> NSAttributedString {
            NSAttributedString(string: chartData.title ?? "Chart")
        }
    }

#elseif canImport(AppKit) && canImport(Charts)
    import AppKit
    import Charts
    import SwiftUI

    final class ChartView: NSView {
        var theme: MarkdownTheme = .default {
            didSet { updateChart() }
        }

        var chartData: ChartData = .init() {
            didSet {
                guard oldValue != chartData else { return }
                updateChart()
            }
        }

        private var hostingView: NSHostingView<AnyView>?

        override init(frame: CGRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.cornerRadius = 8
            layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.05).cgColor
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var isFlipped: Bool { true }

        static let defaultHeight: CGFloat = 240

        override var intrinsicContentSize: CGSize {
            CGSize(
                width: NSView.noIntrinsicMetric,
                height: Self.defaultHeight
            )
        }

        override func layout() {
            super.layout()
            hostingView?.frame = bounds
        }

        private func updateChart() {
            hostingView?.removeFromSuperview()
            hostingView = nil

            let data = chartData
            let chartSwiftUIView = Self.makeChartView(data: data)
            let hosting = NSHostingView(rootView: chartSwiftUIView)
            hosting.frame = bounds
            addSubview(hosting)
            hostingView = hosting
        }

        @MainActor
        private static func makeChartView(data: ChartData) -> AnyView {
            let titleView = data.title.map { title in
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            switch data.type {
            case .bar:
                return AnyView(
                    VStack(spacing: 0) {
                        if let titleView { titleView }
                        Chart(data.entries) { entry in
                            BarMark(
                                x: .value("Label", entry.label),
                                y: .value("Value", entry.value)
                            )
                            .foregroundStyle(.blue.gradient)
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .padding(12)
                    }
                )
            case .line:
                return AnyView(
                    VStack(spacing: 0) {
                        if let titleView { titleView }
                        Chart(data.entries) { entry in
                            LineMark(
                                x: .value("Label", entry.label),
                                y: .value("Value", entry.value)
                            )
                            .foregroundStyle(.blue)
                            PointMark(
                                x: .value("Label", entry.label),
                                y: .value("Value", entry.value)
                            )
                            .foregroundStyle(.blue)
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .padding(12)
                    }
                )
            case .pie:
                if #available(iOS 17.0, macOS 14.0, *) {
                    return AnyView(
                        VStack(spacing: 0) {
                            if let titleView { titleView }
                            Chart(data.entries) { entry in
                                SectorMark(
                                    angle: .value("Value", entry.value),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 1
                                )
                                .foregroundStyle(by: .value("Label", entry.label))
                            }
                            .padding(12)
                        }
                    )
                } else {
                    // Fall back to bar chart on iOS 16
                    return AnyView(
                        VStack(spacing: 0) {
                            if let titleView { titleView }
                            Chart(data.entries) { entry in
                                BarMark(
                                    x: .value("Label", entry.label),
                                    y: .value("Value", entry.value)
                                )
                                .foregroundStyle(.blue.gradient)
                            }
                            .chartYAxis { AxisMarks(position: .leading) }
                            .padding(12)
                        }
                    )
                }
            case .area:
                return AnyView(
                    VStack(spacing: 0) {
                        if let titleView { titleView }
                        Chart(data.entries) { entry in
                            AreaMark(
                                x: .value("Label", entry.label),
                                y: .value("Value", entry.value)
                            )
                            .foregroundStyle(.blue.opacity(0.3).gradient)
                            LineMark(
                                x: .value("Label", entry.label),
                                y: .value("Value", entry.value)
                            )
                            .foregroundStyle(.blue)
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .padding(12)
                    }
                )
            }
        }
    }

    extension ChartView: LTXAttributeStringRepresentable {
        func attributedStringRepresentation() -> NSAttributedString {
            NSAttributedString(string: chartData.title ?? "Chart")
        }
    }
#endif
