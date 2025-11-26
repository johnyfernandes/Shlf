//
//  ConfettiView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

// Native confetti effect using AVCaptureReactionType
struct ConfettiModifier: ViewModifier {
    @Binding var isActive: Bool
    @State private var counter = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    if isActive {
                        ConfettiEffectView()
                            .allowsHitTesting(false)
                    }
                }
            )
            .sensoryFeedback(.success, trigger: counter)
            .onChange(of: isActive) { oldValue, newValue in
                if newValue {
                    counter += 1
                    // Auto-dismiss after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        isActive = false
                    }
                }
            }
    }
}

struct ConfettiEffectView: UIViewRepresentable {
    func makeUIView(context: Context) -> ConfettiUIView {
        return ConfettiUIView()
    }

    func updateUIView(_ uiView: ConfettiUIView, context: Context) {
        uiView.startConfetti()
    }
}

class ConfettiUIView: UIView {
    private var emitterLayer: CAEmitterLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupEmitter()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupEmitter() {
        let emitter = CAEmitterLayer()
        // Use placeholder position, will be updated in layoutSubviews
        emitter.emitterPosition = CGPoint(x: 200, y: -50)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: 400, height: 1)
        emitter.birthRate = 0  // Start with 0 - no confetti until triggered

        var cells: [CAEmitterCell] = []
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemOrange, .systemPurple, .systemPink]

        for color in colors {
            let cell = CAEmitterCell()
            cell.birthRate = 6
            cell.lifetime = 10.0  // Live longer
            cell.lifetimeRange = 1.0
            cell.velocity = 150  // Slower falling
            cell.velocityRange = 50
            cell.emissionLongitude = .pi  // Downward
            cell.emissionRange = .pi / 6  // Narrow spread
            cell.spin = 2.0  // Less spinning
            cell.spinRange = 1.0
            cell.scaleRange = 0.3
            cell.scale = 0.1
            cell.yAcceleration = 100  // Gentle gravity
            cell.contents = createConfettiImage(color: color).cgImage
            cells.append(cell)
        }

        emitter.emitterCells = cells
        self.emitterLayer = emitter
        self.layer.addSublayer(emitter)
    }

    private func createConfettiImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: 2).fill()
        }
    }

    func startConfetti() {
        emitterLayer?.birthRate = 1

        // Emit for 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.emitterLayer?.birthRate = 0
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitterLayer?.frame = bounds
        emitterLayer?.emitterPosition = CGPoint(x: bounds.width / 2, y: -50)
        emitterLayer?.emitterSize = CGSize(width: bounds.width, height: 1)
    }
}

extension View {
    func confetti(isActive: Binding<Bool>) -> some View {
        modifier(ConfettiModifier(isActive: isActive))
    }
}
