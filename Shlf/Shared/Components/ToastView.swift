//
//  ToastView.swift
//  Shlf
//
//  Created by Codex on 19/01/2026.
//

import SwiftUI

struct ToastView: View {
    @Environment(\.themeColor) private var themeColor
    let toast: ToastData
    let onDismiss: () -> Void
    @GestureState private var dragOffset: CGFloat = 0

    private var tint: Color {
        toast.tint ?? themeColor.color
    }

    var body: some View {
        HStack(spacing: 8) {
            switch toast.style {
            case .successCheck:
                AnimatedCheckmark(color: tint)
            }

            Text(verbatim: toast.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Theme.Shadow.medium, radius: 10, y: 6)
        .contentShape(Capsule())
        .onTapGesture {
            onDismiss()
        }
        .offset(y: dragOffset < 0 ? dragOffset : 0)
        .gesture(
            DragGesture(minimumDistance: 4)
                .updating($dragOffset) { value, state, _ in
                    if value.translation.height < 0 {
                        state = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -16 {
                        onDismiss()
                    }
                }
        )
        .animation(.easeOut(duration: 0.15), value: dragOffset)
        .accessibilityLabel(Text(verbatim: toast.title))
    }
}

struct ToastHost: ViewModifier {
    @EnvironmentObject private var toastCenter: ToastCenter

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = toastCenter.toast {
                ToastView(toast: toast) {
                    toastCenter.dismiss()
                }
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

extension View {
    func toastHost() -> some View {
        modifier(ToastHost())
    }
}

private struct AnimatedCheckmark: View {
    let color: Color
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 1.5)

            CheckmarkShape()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
        }
        .frame(width: 20, height: 20)
        .onAppear {
            progress = 0
            withAnimation(.easeOut(duration: 0.9)) {
                progress = 1
            }
        }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: width * 0.24, y: height * 0.52))
        path.addLine(to: CGPoint(x: width * 0.42, y: height * 0.70))
        path.addLine(to: CGPoint(x: width * 0.76, y: height * 0.34))
        return path
    }
}
