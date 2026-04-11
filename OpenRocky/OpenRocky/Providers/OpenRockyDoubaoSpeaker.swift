//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

enum OpenRockyDoubaoSpeaker: String, CaseIterable, Identifiable {
    case vivi = "zh_female_vv_jupiter_bigtts"
    case xiaohe = "zh_female_xiaohe_jupiter_bigtts"
    case xiaotian = "zh_male_xiaotian_jupiter_bigtts"
    case yunzhou = "zh_male_yunzhou_jupiter_bigtts"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vivi: String(localized: "Vivi 2.0")
        case .xiaohe: String(localized: "小何 2.0")
        case .xiaotian: String(localized: "小天 2.0")
        case .yunzhou: String(localized: "云舟 2.0")
        }
    }

    var subtitle: String {
        switch self {
        case .vivi: String(localized: "语调平稳、咬字柔和、自带治愈安抚力的女声音色")
        case .xiaohe: String(localized: "声线甜美有活力的妹妹，活泼开朗，笑容明媚")
        case .xiaotian: String(localized: "眉目清朗男大，清澈温润有朝气，开朗真诚")
        case .yunzhou: String(localized: "声音磁性的男生，成熟理性，做事有条理")
        }
    }

    static let `default`: OpenRockyDoubaoSpeaker = .vivi
}
