//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-11
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

enum OpenRockyGLMVoice: String, CaseIterable, Identifiable {
    case tongtong = "tongtong"
    case xiaochen = "xiaochen"
    case femaleTianmei = "female-tianmei"
    case femaleShaonv = "female-shaonv"
    case maleQnDaxuesheng = "male-qn-daxuesheng"
    case maleQnJingying = "male-qn-jingying"
    case lovelyGirl = "lovely_girl"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .tongtong: "童童"
        case .xiaochen: "小辰"
        case .femaleTianmei: "甜美女声"
        case .femaleShaonv: "少女音"
        case .maleQnDaxuesheng: "大学生"
        case .maleQnJingying: "精英男声"
        case .lovelyGirl: "可爱女声"
        }
    }

    nonisolated var subtitle: String {
        switch self {
        case .tongtong: "温柔女声，自然亲切（默认）"
        case .xiaochen: "成熟男声，稳重大方"
        case .femaleTianmei: "甜美温柔，轻声细语"
        case .femaleShaonv: "活泼少女，清新可爱"
        case .maleQnDaxuesheng: "青年男声，阳光活力"
        case .maleQnJingying: "精英男声，沉稳干练"
        case .lovelyGirl: "可爱女声，俏皮灵动"
        }
    }

    static let `default`: OpenRockyGLMVoice = .tongtong
}
