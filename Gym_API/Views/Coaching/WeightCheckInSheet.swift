//
//  WeightCheckInSheet.swift
//  Gym_API
//
//  Registro de peso del check-in semanal.
//
//  Primera pieza de la pantalla 13 del diseño. Faltan las escalas de energía, sueño y agujetas
//  y las tres fotos de progreso: las escalas necesitan la tabla de check-in semanal y las fotos
//  necesitan almacenamiento privado, ninguna de las dos cosas existe todavía. Se entrega el peso
//  porque es lo único que ya tiene backend, y es además el dato del que cuelga el widget 7.
//
//  Unidades: el servidor guarda kilos y esta pantalla enseña lo que se usa en el país de quien
//  la abre. Con el lanzamiento en Estados Unidos eso son libras. La conversión vive aquí, en el
//  borde: `weight` está en la unidad que se ve, y solo se pasa a kilos al guardar.
//

import SwiftUI

struct WeightCheckInSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var healthService: HealthService
    @Environment(\.dismiss) private var dismiss

    /// Unidad en la que se teclea y se lee. El servidor sigue recibiendo kilos.
    private let unit = WeightUnit.preferred

    @State private var weight: Double = WeightUnit.preferred.defaultWeight
    @State private var notes: String = ""

    // Las tres escalas del diseño. Opcionales: nadie está obligado a puntuar, y arrancar en un
    // valor por defecto metería un dato que el entrenador leería como dicho por su cliente.
    @State private var energy: Int?
    @State private var sleep: Int?
    @State private var soreness: Int?

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    /// Última medición conocida, ya convertida a la unidad que se enseña.
    /// Incluye el respaldo de la última medición: `weightHistory` está acotado a 90 días.
    private var previousWeight: Double? {
        healthService.currentWeight.map { unit.fromKilograms($0) }
    }

    private var deltaText: String? {
        guard let previous = previousWeight else { return nil }
        let delta = ((weight - previous) * 10).rounded() / 10
        guard abs(delta) >= 0.05 else { return "Same as last time" }
        return "\(NumberFormat.signedDecimal(delta)) \(unit.symbol) since last time"
    }

    var body: some View {
        NavigationStack {
            // Desplazable: con las tres escalas el contenido ya no cabe en un iPhone pequeño, y
            // sin esto el botón de guardar quedaba fuera de la pantalla.
            ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What do you weigh today?")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.4)
                        .foregroundColor(Color.dynamicText(theme: theme))
                    Text("Weigh yourself at the same time and in the same conditions so the comparison means something.")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    NumericStepperFieldView(
                        value: $weight,
                        step: unit.step,
                        range: unit.editableRange,
                        unit: unit.symbol,
                        decimals: 1
                    )

                    if let deltaText {
                        Text(deltaText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    }
                }

                VStack(spacing: 10) {
                    ScaleSelectorView(
                        title: "Energy",
                        lowLabel: "Drained",
                        highLabel: "Full tank",
                        value: $energy
                    )
                    ScaleSelectorView(
                        title: "Sleep",
                        lowLabel: "Poor",
                        highLabel: "Great",
                        value: $sleep
                    )
                    ScaleSelectorView(
                        title: "Soreness",
                        lowLabel: "None",
                        highLabel: "A lot",
                        value: $soreness
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTE FOR YOUR TRAINER")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                    TextField("Optional: how this week felt", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .onChange(of: notes) { _, value in
                            // El backend valida max_length=1000 y responde 422 sin guardar nada,
                            // así que se corta aquí en vez de perder el peso por una nota larga.
                            if value.count > HealthService.maxNotesLength {
                                notes = String(value.prefix(HealthService.maxNotesLength))
                            }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .padding(12)
                        .background(Color.dynamicSurface2(theme: theme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let error = healthService.saveErrorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(Color.errorRed)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // El botón va al final del contenido, no empujado por un Spacer: dentro de un
                // desplazable un Spacer no reparte nada.
                Button(action: save) {
                    HStack(spacing: 8) {
                        if healthService.isSaving {
                            ProgressView().tint(Color.accentInk)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                        }
                        Text(healthService.isSaving ? "Saving…" : "Save")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(Color.accentInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
                }
                .buttonStyle(.plain)
                .disabled(healthService.isSaving)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                }
            }
            .onAppear {
                // Se parte del último peso conocido: es el gesto de menos fricción.
                if let previous = previousWeight { weight = previous }
                healthService.saveErrorMessage = nil
            }
        }
    }

    private func save() {
        Task {
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            // Un solo envío para el peso y las escalas. El servidor crea además la medición en
            // el histórico, así que la serie que alimenta el widget de la home se sigue llenando
            // por el mismo sitio que antes.
            //
            // El backend valida el peso en kilos (0 < weight <= 500), así que se convierte aquí.
            let saved = await healthService.submitWeeklyCheckIn(
                weightKilograms: unit.toKilograms(weight),
                energy: energy,
                sleep: sleep,
                soreness: soreness,
                notes: trimmed.isEmpty ? nil : trimmed
            )
            if saved {
                HapticManager.shared.goalCompleted()
                dismiss()
            }
        }
    }
}
