//
//  VoiceOrbView.swift
//  LanguageModelChatUI
//

import UIKit

/// An animated voice orb with radial gradient, glow, waveform icon,
/// and concentric pulse rings for inline voice mode.
class VoiceOrbView: UIView {
    // Layers back-to-front
    private let outerPulseLayer = CAShapeLayer()
    private let innerPulseLayer = CAShapeLayer()
    private let glowLayer = CALayer()
    private let gradientLayer = CAGradientLayer()
    private let borderLayer = CAShapeLayer()
    private let waveformView = UIImageView()

    private let tint: UIColor = .tintColor

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        // Outer pulse ring
        outerPulseLayer.fillColor = UIColor.clear.cgColor
        outerPulseLayer.strokeColor = tint.withAlphaComponent(0.15).cgColor
        outerPulseLayer.lineWidth = 2
        layer.addSublayer(outerPulseLayer)

        // Inner pulse ring
        innerPulseLayer.fillColor = tint.withAlphaComponent(0.10).cgColor
        layer.addSublayer(innerPulseLayer)

        // Glow layer (shadow behind the orb)
        glowLayer.shadowColor = tint.cgColor
        glowLayer.shadowOpacity = 0.5
        glowLayer.shadowRadius = 12
        glowLayer.shadowOffset = .zero
        layer.addSublayer(glowLayer)

        // Radial gradient orb (approximated with CAGradientLayer radial)
        gradientLayer.type = .radial
        gradientLayer.startPoint = CGPoint(x: 0.45, y: 0.40) // Slight top-left highlight
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradientLayer)

        // Thin white border ring
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.15).cgColor
        borderLayer.lineWidth = 1
        layer.addSublayer(borderLayer)

        // Waveform icon
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        waveformView.image = UIImage(systemName: "waveform", withConfiguration: config)
        waveformView.tintColor = .white
        waveformView.contentMode = .scaleAspectFit
        addSubview(waveformView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let orbRadius = min(bounds.width, bounds.height) / 2

        // Outer pulse ring (1.5x)
        let outerR = orbRadius * 1.5
        outerPulseLayer.path = UIBezierPath(
            arcCenter: center, radius: outerR,
            startAngle: 0, endAngle: .pi * 2, clockwise: true
        ).cgPath

        // Inner pulse ring (1.2x)
        let innerR = orbRadius * 1.25
        innerPulseLayer.path = UIBezierPath(
            arcCenter: center, radius: innerR,
            startAngle: 0, endAngle: .pi * 2, clockwise: true
        ).cgPath

        // Glow
        let glowRect = CGRect(
            x: center.x - orbRadius,
            y: center.y - orbRadius,
            width: orbRadius * 2,
            height: orbRadius * 2
        )
        glowLayer.frame = glowRect
        glowLayer.cornerRadius = orbRadius
        glowLayer.backgroundColor = tint.withAlphaComponent(0.4).cgColor
        glowLayer.shadowPath = UIBezierPath(
            roundedRect: glowLayer.bounds,
            cornerRadius: orbRadius
        ).cgPath

        // Gradient orb
        gradientLayer.frame = glowRect
        gradientLayer.cornerRadius = orbRadius
        gradientLayer.masksToBounds = true
        updateGradientColors()

        // Border ring
        borderLayer.path = UIBezierPath(
            arcCenter: center, radius: orbRadius,
            startAngle: 0, endAngle: .pi * 2, clockwise: true
        ).cgPath

        // Waveform icon centered
        let iconSize: CGFloat = orbRadius * 1.1
        waveformView.frame = CGRect(
            x: center.x - iconSize / 2,
            y: center.y - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
    }

    private func updateGradientColors() {
        gradientLayer.colors = [
            tint.withAlphaComponent(0.95).cgColor,
            tint.withAlphaComponent(0.70).cgColor,
            tint.withAlphaComponent(0.35).cgColor,
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
    }

    func startAnimating() {
        // Outer ring: slow expanding pulse
        outerPulseLayer.removeAnimation(forKey: "outerPulse")
        let outerScale = CABasicAnimation(keyPath: "transform.scale")
        outerScale.fromValue = 0.85
        outerScale.toValue = 1.1
        outerScale.duration = 2.0
        outerScale.autoreverses = true
        outerScale.repeatCount = .infinity
        outerScale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        outerPulseLayer.add(outerScale, forKey: "outerPulse")

        let outerOpacity = CABasicAnimation(keyPath: "opacity")
        outerOpacity.fromValue = 0.6
        outerOpacity.toValue = 1.0
        outerOpacity.duration = 2.0
        outerOpacity.autoreverses = true
        outerOpacity.repeatCount = .infinity
        outerOpacity.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        outerPulseLayer.add(outerOpacity, forKey: "outerOpacity")

        // Inner ring: faster breathing
        innerPulseLayer.removeAnimation(forKey: "innerPulse")
        let innerScale = CABasicAnimation(keyPath: "transform.scale")
        innerScale.fromValue = 0.92
        innerScale.toValue = 1.08
        innerScale.duration = 1.2
        innerScale.autoreverses = true
        innerScale.repeatCount = .infinity
        innerScale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        innerPulseLayer.add(innerScale, forKey: "innerPulse")

        // Glow pulsing
        glowLayer.removeAnimation(forKey: "glow")
        let glowAnim = CABasicAnimation(keyPath: "shadowRadius")
        glowAnim.fromValue = 8
        glowAnim.toValue = 18
        glowAnim.duration = 1.5
        glowAnim.autoreverses = true
        glowAnim.repeatCount = .infinity
        glowAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glowLayer.add(glowAnim, forKey: "glow")

        // Waveform subtle scale
        waveformView.layer.removeAnimation(forKey: "waveScale")
        let waveScale = CABasicAnimation(keyPath: "transform.scale")
        waveScale.fromValue = 0.95
        waveScale.toValue = 1.08
        waveScale.duration = 0.8
        waveScale.autoreverses = true
        waveScale.repeatCount = .infinity
        waveScale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        waveformView.layer.add(waveScale, forKey: "waveScale")
    }

    func stopAnimating() {
        outerPulseLayer.removeAllAnimations()
        innerPulseLayer.removeAllAnimations()
        glowLayer.removeAllAnimations()
        waveformView.layer.removeAllAnimations()
    }
}
