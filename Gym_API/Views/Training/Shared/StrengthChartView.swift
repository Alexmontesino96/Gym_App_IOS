//
//  StrengthChartView.swift
//  Gym_API
//
//  La curva de 1RM estimado de W6 y S15 (UX §4 y §5).
//
//  No se reutiliza `SparklineView` por dos razones concretas: anima el trazo siempre, sin mirar
//  Reduce Motion (checklist §10.14), y no tiene dónde colgar el scrub ni el descriptor de
//  audio-gráfico que S15 exige. Aquí las tres cosas son parte del componente.
//
//  El gráfico es UN elemento de accesibilidad, no ocho puntos que VoiceOver recorre: se lee con
//  una frase entera y, para quien quiera el detalle, con el rotor de audio-gráficos.
//

import SwiftUI
import Accessibility
import TrainingCore

struct StrengthChartView: View {

    let points: [StrengthSummaryPoint]
    let unit: WeightUnit
    /// Nombre del ejercicio, para el descriptor y la etiqueta hablada.
    let exerciseName: String
    /// S15 permite arrastrar sobre el gráfico; W6 no (el trazo es demasiado pequeño).
    var allowsScrub: Bool = false
    var height: CGFloat = 96
    /// Frase que resume la tendencia: «Up 10 lb over six weeks».
    var summary: String?

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.trainingReduceMotion) private var reduceMotion

    @State private var progress: CGFloat = 0
    @State private var selectedIndex: Int?
    @State private var lastHapticIndex: Int?

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var values: [Double] { points.map { unit.fromKilograms($0.e1rmKg) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if allowsScrub, let selectedIndex, points.indices.contains(selectedIndex) {
                tooltip(for: points[selectedIndex])
            }

            chart
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityChartDescriptor(
            StrengthChartDescriptor(
                title: exerciseName,
                summary: summary,
                unitSymbol: unit.symbol,
                points: points,
                values: values
            )
        )
    }

    // MARK: - Trazo

    private var chart: some View {
        GeometryReader { geo in
            let coordinates = normalized(in: geo.size)

            ZStack(alignment: .topLeading) {
                if coordinates.count >= 2 {
                    area(coordinates, height: geo.size.height)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.dynamicAccent(theme: theme).opacity(0.16),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(progress)

                    line(coordinates)
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.dynamicAccent(theme: theme),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                }

                if let last = coordinates.last, progress > 0.9 {
                    Circle()
                        .fill(Color.dynamicAccent(theme: theme))
                        .frame(width: 6, height: 6)
                        .overlay(Circle().stroke(Color.dynamicSurface(theme: theme), lineWidth: 2))
                        .position(last)
                }

                if allowsScrub, let selectedIndex, coordinates.indices.contains(selectedIndex) {
                    let point = coordinates[selectedIndex]
                    Rectangle()
                        .fill(Color.dynamicBorder(theme: theme).opacity(0.5))
                        .frame(width: 1, height: geo.size.height)
                        .position(x: point.x, y: geo.size.height / 2)
                    Circle()
                        .fill(Color.dynamicText(theme: theme))
                        .frame(width: 8, height: 8)
                        .position(point)
                }
            }
            .contentShape(Rectangle())
            .gesture(allowsScrub ? scrubGesture(in: geo.size) : nil)
        }
        .frame(height: height)
        .onAppear(perform: draw)
    }

    private func draw() {
        guard progress == 0 else { return }
        if reduceMotion {
            // Sin recorrido: la línea aparece entera con un fundido corto (UX §4, W6).
            withAnimation(.easeOut(duration: 0.15)) { progress = 1 }
        } else {
            withAnimation(.easeOut(duration: 0.42)) { progress = 1 }
        }
    }

    // MARK: - Scrub

    private func scrubGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard points.count > 1 else { return }
                let step = size.width / CGFloat(points.count - 1)
                let index = Int((value.location.x / max(step, 1)).rounded())
                let clamped = min(max(index, 0), points.count - 1)
                if clamped != selectedIndex {
                    selectedIndex = clamped
                    // Un háptico por punto cruzado, no por píxel.
                    if lastHapticIndex != clamped {
                        lastHapticIndex = clamped
                        HapticManager.shared.play(.selection)
                    }
                }
            }
            .onEnded { _ in
                lastHapticIndex = nil
            }
    }

    private func tooltip(for point: StrengthSummaryPoint) -> some View {
        HStack(spacing: 6) {
            if let date = point.date {
                Text(TrainingFormat.dayMonth(date.startOfDay(in: .current)))
                    .font(TrainingType.monoS())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
            Text(unit.loadLabel(kilograms: point.e1rmKg))
                .font(TrainingType.monoS())
                .foregroundColor(Color.dynamicText(theme: theme))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.dynamicSurface2(theme: theme))
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    // MARK: - Geometría

    private func normalized(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = maxValue - minValue
        let inset: CGFloat = 5
        let usable = max(size.height - inset * 2, 1)

        return values.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            guard span > 0.000_001 else { return CGPoint(x: x, y: size.height / 2) }
            let ratio = (value - minValue) / span
            return CGPoint(x: x, y: inset + usable * (1 - CGFloat(ratio)))
        }
    }

    private func line(_ coordinates: [CGPoint]) -> Path {
        var path = Path()
        guard let first = coordinates.first else { return path }
        path.move(to: first)
        coordinates.dropFirst().forEach { path.addLine(to: $0) }
        return path
    }

    private func area(_ coordinates: [CGPoint], height: CGFloat) -> Path {
        var path = line(coordinates)
        guard let first = coordinates.first, let last = coordinates.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: height))
        path.addLine(to: CGPoint(x: first.x, y: height))
        path.closeSubpath()
        return path
    }

    // MARK: - Accesibilidad

    private var accessibilityLabel: String {
        var text = "\(exerciseName) estimated one rep max"
        if let current = points.last?.e1rmKg {
            text += ", \(spoken(current))"
        }
        if let summary { text += ". \(summary)" }
        return text + "."
    }

    private var accessibilityValue: String {
        guard !points.isEmpty else { return "No data yet." }
        let list = points.map { Celebration.number(unit.fromKilograms($0.e1rmKg)) }.joined(separator: ", ")
        let unitWord = unit == .pounds ? "pounds" : "kilograms"
        return "Trend over the last \(points.count) sessions: \(list) \(unitWord)."
    }

    private func spoken(_ kilograms: Double) -> String {
        let value = Celebration.number(unit.fromKilograms(kilograms))
        return "\(value) \(unit == .pounds ? "pounds" : "kilograms")"
    }
}

// MARK: - Audio-gráfico

/// Descriptor del rotor de audio-gráficos. Es lo que permite «oír» la curva de fuerza en vez de
/// solo escuchar una lista de números (UX §4 W6 y §5 S15).
struct StrengthChartDescriptor: AXChartDescriptorRepresentable {

    let title: String
    let summary: String?
    let unitSymbol: String
    let points: [StrengthSummaryPoint]
    let values: [Double]

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels: [String] = points.enumerated().map { index, point in
            guard let date = point.date else { return "Session \(index + 1)" }
            return TrainingFormat.dayMonth(date.startOfDay(in: .current))
        }

        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Session",
            categoryOrder: labels
        )

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Estimated one rep max in \(unitSymbol)",
            range: minValue...(maxValue > minValue ? maxValue : minValue + 1),
            gridlinePositions: [],
            valueDescriptionProvider: { value in
                "\(Celebration.number(value)) \(unitSymbol)"
            }
        )

        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: true,
            dataPoints: zip(labels, values).map { AXDataPoint(x: $0, y: $1) }
        )

        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {
        // El descriptor se reconstruye con la vista: no hay estado que actualizar en sitio.
    }
}
