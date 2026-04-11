//
//  ChartData.swift
//  MarkdownView
//
//  Created on 2026/4/8.
//

import Foundation

struct ChartData: Equatable, Hashable {
    enum ChartType: String, Codable, Equatable, Hashable {
        case bar
        case line
        case pie
        case area
    }

    struct Entry: Identifiable, Equatable, Hashable {
        let id: String
        let label: String
        let value: Double

        init(label: String, value: Double) {
            id = label
            self.label = label
            self.value = value
        }
    }

    var type: ChartType = .bar
    var title: String?
    var entries: [Entry] = []

    static func parse(from jsonString: String) -> ChartData? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        var chart = ChartData()

        if let typeStr = json["type"] as? String,
           let chartType = ChartType(rawValue: typeStr)
        {
            chart.type = chartType
        }

        chart.title = json["title"] as? String

        if let dataArray = json["data"] as? [[String: Any]] {
            chart.entries = dataArray.compactMap { item in
                guard let label = item["label"] as? String else { return nil }
                let value: Double
                if let v = item["value"] as? Double {
                    value = v
                } else if let v = item["value"] as? Int {
                    value = Double(v)
                } else {
                    return nil
                }
                return Entry(label: label, value: value)
            }
        }

        guard !chart.entries.isEmpty else { return nil }
        return chart
    }
}
