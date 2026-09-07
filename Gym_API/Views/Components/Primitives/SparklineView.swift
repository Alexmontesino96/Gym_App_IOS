//
//  SparklineView.swift
//  Gym_API
//
//  Gráfica de línea compacta, sin ejes ni leyenda.
//
//  Se dibuja con `Path` en lugar de Swift Charts a propósito. Charts está disponible y ya se
//  usa en las estadísticas de encuestas, pero para ocho puntos sin ejes ni interacción obliga
//  a apagar todo su cromado y aun así no da control fino sobre el punto final ni el degradado.
//  Con Path son unas cuarenta líneas y se anima con `.trim`, el mismo gesto que ya usa
//  CircularProgressView.
//
//  Segmentos rectos, no curva: con pocos puntos una curva suavizada se pasa en los picos y
//  dibuja valores que no existen.
//

import SwiftUI

struct SparklineView: View {
    let values: [Double]
    var lineWidth: CGFloat = 2
    var showsLastPoint: Bool = true

    @EnvironmentObject var themeManager: ThemeManager
    @State private var progress: CGFloat = 0

    private let verticalInset: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let points = normalizedPoints(in: geo.size)

            ZStack {
                if points.count >= 2 {
                    areaPath(points, height: geo.size.height)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.18),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    linePath(points)
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.dynamicAccent(theme: themeManager.currentTheme),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                }

                if showsLastPoint, let last = points.last {
                    Circle()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .frame(width: 5, height: 5)
                        .overlay(
                            Circle().stroke(Color.dynamicSurface(theme: themeManager.currentTheme), lineWidth: 2)
                        )
                        .position(x: last.x, y: last.y)
                        .opacity(progress > 0.9 ? 1 : 0)
                }
            }
            .animation(.easeOut(duration: 0.35), value: progress)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { progress = 1 }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Geometría

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }

        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let span = maxV - minV
        let usableHeight = max(size.height - verticalInset * 2, 1)

        if values.count == 1 {
            return [CGPoint(x: size.width / 2, y: size.height / 2)]
        }

        // Todos los valores iguales: línea plana centrada. Con un span mínimo artificial la
        // división daba ratio 0 y la línea se pintaba pegada al borde inferior, que se lee
        // como una caída a cero.
        let flat = span < 0.000_001

        return values.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            guard !flat else { return CGPoint(x: x, y: size.height / 2) }
            let ratio = (value - minV) / span
            let y = verticalInset + usableHeight * (1 - CGFloat(ratio))
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func areaPath(_ points: [CGPoint], height: CGFloat) -> Path {
        var path = linePath(points)
        guard let first = points.first, let last = points.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: height))
        path.addLine(to: CGPoint(x: first.x, y: height))
        path.closeSubpath()
        return path
    }
}

#Preview {
    SparklineView(values: [88, 90, 89, 94, 97, 96, 102, 105])
        .frame(height: 56)
        .padding()
        .environmentObject(ThemeManager())
}
