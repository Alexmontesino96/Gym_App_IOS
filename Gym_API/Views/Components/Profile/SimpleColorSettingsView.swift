//
//  SimpleColorSettingsView.swift
//  Gym_API
//
//  Elección de tema y acento. Es la pantalla que responde a «¿funciona el cambio de color?»,
//  así que lo primero que enseña es una previsualización EN VIVO del acento: un pequeño héroe
//  y un botón pintados con el color elegido, que cambian en el instante en que se toca un
//  círculo. Antes era una rejilla de 23 círculos sin nombre ni previsualización, con el check
//  siempre blanco —invisible sobre el lima y el amarillo—, sin etiquetas para VoiceOver y con
//  un `NavigationView` obsoleto.
//

import SwiftUI

struct SimpleColorSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var accent: Color { Color.dynamicAccent(theme: theme) }
    private var ink: Color { ThemeManager.accentInkForCurrentAccent(theme: theme) }
    private var currentHex: String { themeManager.accentHex(for: theme) }
    private var options: [String] {
        theme == .light ? ThemeManager.lightAccentOptions : ThemeManager.darkAccentOptions
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    preview
                    themeSection
                    accentSection
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accent)
                }
            }
        }
    }

    // MARK: - Previsualización en vivo

    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrow("PREVIEW")

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR SESSION TODAY")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.0)
                            .opacity(0.7)
                        Text("Personal Training")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.7)
                        Text("1:00 PM–2:00 PM · Studio A")
                            .font(.system(size: 13, weight: .medium))
                            .opacity(0.8)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 0) {
                        Text("60")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                        Text("MIN")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(accent)
                    .frame(width: 50, height: 50)
                    .background(Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                HStack {
                    Text(ThemeManager.accentName(for: currentHex))
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(0.75)
                    Spacer(minLength: 0)
                    Text("I'M HERE")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(ink)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [accent, accent.opacity(0.72)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .animation(.easeInOut(duration: 0.25), value: currentHex)
            .accessibilityLabel("Preview of the \(ThemeManager.accentName(for: currentHex)) accent")
        }
    }

    // MARK: - Tema

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrow("THEME")
            HStack(spacing: 4) {
                themeButton(.light, label: "Light", icon: "sun.max.fill")
                themeButton(.dark, label: "Dark", icon: "moon.fill")
            }
            .padding(4)
            .background(Color.dynamicSurface(theme: theme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
            )
        }
    }

    private func themeButton(_ value: ThemeManager.AppTheme, label: String, icon: String) -> some View {
        let selected = theme == value
        return Button {
            guard !selected else { return }
            HapticManager.shared.buttonTap()
            withAnimation(.easeInOut(duration: 0.2)) { themeManager.setTheme(value) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(selected ? Color.dynamicBackground(theme: theme) : Color.dynamicTextSecondary(theme: theme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 11).fill(selected ? Color.dynamicText(theme: theme) : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Acento

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                eyebrow("ACCENT")
                Spacer()
                Text(ThemeManager.accentName(for: currentHex))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 14) {
                ForEach(options, id: \.self) { hex in
                    swatch(hex)
                }
            }
            .padding(16)
            .background(Color.dynamicSurface(theme: theme))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
            )

            Text("The accent colours the hero card, buttons and the tab bar. It changes right away, everywhere.")
                .font(.system(size: 12))
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 2)
        }
    }

    private func swatch(_ hex: String) -> some View {
        let color = Color(hex: hex) ?? .gray
        let selected = hex.caseInsensitiveCompare(currentHex) == .orderedSame
        // La tinta del check por contraste, no blanca: sobre el lima o el amarillo el blanco
        // desaparece, y ese es justamente el acento por defecto.
        let luminance = ThemeManager.relativeLuminance(hex: hex)
        let check: Color = (luminance + 0.05) / (ThemeManager.relativeLuminance(hex: "#0A0A0A") + 0.05)
            >= 1.05 / (luminance + 0.05) ? Color.accentInk : .white

        return Button {
            guard !selected else { return }
            HapticManager.shared.buttonTap()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                themeManager.setAccentHex(hex, for: theme)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 42, height: 42)
                if selected {
                    Circle()
                        .stroke(Color.dynamicText(theme: theme), lineWidth: 2.5)
                        .frame(width: 50, height: 50)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(check)
                }
            }
            .frame(width: 50, height: 50)
            .scaleEffect(selected ? 1.0 : 0.92)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ThemeManager.accentName(for: hex))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.9)
            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            .padding(.leading, 2)
    }
}

#Preview {
    SimpleColorSettingsView()
        .environmentObject(ThemeManager())
}
