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

    /// Lo que la persona ha tecleado, si ha tecleado algo. `nil` NO es «cero»: es «todavía no».
    ///
    /// Antes esto era `Double` inicializado a `WeightUnit.preferred.defaultWeight`, o sea 165 lb.
    /// Ese inicializador corre ANTES de que exista el entorno, así que era imposible consultar
    /// ahí el peso previo, y el `.onAppear` que lo copiaba era un disparo único: si la red no
    /// había respondido todavía, la hoja se quedaba con las 165 y nada volvía a sincronizarla.
    /// Abrir y pulsar Save escribía ese número inventado en el histórico del cliente.
    @State private var weight: Double?
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

    /// El valor que pinta el control. Se lee EN VIVO, no se copia: si la medición previa llega
    /// tarde, el control se actualiza solo y la carrera desaparece sin `onAppear` ni `onChange`.
    private var effectiveWeight: Double {
        weight ?? previousWeight ?? unit.stepperStartValue
    }

    /// No hay nada que guardar: ni peso previo ni nada tecleado.
    private var hasNoWeight: Bool {
        weight == nil && previousWeight == nil
    }

    private var weightBinding: Binding<Double> {
        Binding(get: { effectiveWeight }, set: { weight = $0 })
    }

    /// Qué decir bajo el control cuando no hay cifra: cargando, no se pudo, o de verdad es la
    /// primera vez. Antes las tres se veían igual, y las tres enseñaban 165 lb.
    private var weightHint: String? {
        guard hasNoWeight else { return deltaText }
        switch healthService.weightState {
        case .loading, .idle: return "Looking up your last weigh-in…"
        case .failed: return "Couldn't load your last weigh-in. Enter today's weight."
        case .loaded: return "First weigh-in. Enter today's weight."
        }
    }

    private var deltaText: String? {
        guard let previous = previousWeight else { return nil }
        let delta = ((effectiveWeight - previous) * 10).rounded() / 10
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
                        value: weightBinding,
                        step: unit.step,
                        range: unit.editableRange,
                        unit: unit.symbol,
                        decimals: 1,
                        isUnset: hasNoWeight
                    )

                    if let weightHint {
                        Text(weightHint)
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
                .disabled(healthService.isSaving || hasNoWeight)
                .opacity(hasNoWeight ? 0.5 : 1)
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
                // Ya no se copia el peso previo aquí: `effectiveWeight` lo lee en vivo, así que
                // llegue cuando llegue el control lo recoge solo.
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
            guard !hasNoWeight else { return }
            let saved = await healthService.submitWeeklyCheckIn(
                weightKilograms: unit.toKilograms(effectiveWeight),
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
