//
//  DictationWaveformView.swift
//  LanguageModelChatUI
//

import UIKit

/// A simple waveform animation view that shows audio levels during dictation.
/// Displays animated bars whose height responds to the current audio level.
class DictationWaveformView: UIView {
    private let barCount = 5
    private var barLayers: [CAShapeLayer] = []
    private var displayLink: CADisplayLink?
    private var targetLevel: Float = 0
    private var currentLevel: Float = 0

    /// Set the audio level (0.0–1.0) to drive the animation.
    var audioLevel: Float = 0 {
        didSet {
            targetLevel = audioLevel
            if audioLevel > 0 && displayLink == nil {
                startDisplayLink()
            } else if audioLevel == 0 {
                stopDisplayLink()
                currentLevel = 0
                updateBars()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBars()
    }

    private func setupBars() {
        for _ in 0..<barCount {
            let layer = CAShapeLayer()
            layer.fillColor = UIColor.systemRed.cgColor
            layer.cornerRadius = 2
            self.layer.addSublayer(layer)
            barLayers.append(layer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateBars()
    }

    private func updateBars() {
        let barWidth: CGFloat = 3
        let spacing: CGFloat = 3
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        let startX = (bounds.width - totalWidth) / 2

        for (i, layer) in barLayers.enumerated() {
            // Each bar has a different phase to create wave effect
            let phase = Float(i) / Float(barCount) * .pi
            let barLevel = max(0.15, currentLevel * (0.5 + 0.5 * sin(phase + Float(CACurrentMediaTime()) * 6)))
            let barHeight = max(4, CGFloat(barLevel) * bounds.height)

            layer.frame = CGRect(
                x: startX + CGFloat(i) * (barWidth + spacing),
                y: (bounds.height - barHeight) / 2,
                width: barWidth,
                height: barHeight
            )
            layer.cornerRadius = barWidth / 2
        }
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        // Smooth interpolation toward target level
        currentLevel += (targetLevel - currentLevel) * 0.3
        updateBars()
    }

    deinit {
        stopDisplayLink()
    }
}
