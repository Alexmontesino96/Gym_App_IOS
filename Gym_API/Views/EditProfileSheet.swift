import SwiftUI

struct EditProfileSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var profileService = UserProfileService.shared

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var heightValue: Int = 170
    @State private var weightValue: Int = 70
    @State private var bio: String = ""
    @Environment(\.dismiss) private var dismiss

    /// El servidor guarda centímetros y kilos; esto solo decide cómo se enseñan.
    private let heightUnit = HeightUnit.preferred
    private let weightUnit = WeightUnit.preferred

    /// La rueda de peso sigue recorriendo kilos, que es lo que se guarda, y muestra la
    /// equivalencia en la unidad de quien mira. Así no hace falta convertir al guardar.
    private func weightLabel(kilograms: Int) -> String {
        let shown = weightUnit.fromKilograms(Double(kilograms))
        return "\(NumberFormat.decimal(shown, digits: 0)) \(weightUnit.symbol)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Edit Profile")) {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                    TextField("Bio", text: $bio, axis: .vertical)
                }

                // Las etiquetas venían de NSLocalizedString con es.lproj como única tabla:
                // en un teléfono en inglés no había recurso que resolver y la sección
                // mostraba las claves crudas ("height", "weight"). Y las unidades eran
                // métricas fijas, que no le dicen nada a quien piensa en libras y pies.
                Section(header: Text(heightUnit.sectionTitle)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Height")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Picker("Height", selection: $heightValue) {
                            ForEach(heightUnit.selectableCentimeters, id: \.self) { centimeters in
                                Text(heightUnit.label(centimeters: centimeters)).tag(centimeters)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Weight")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Picker("Weight", selection: $weightValue) {
                            ForEach(30...200, id: \.self) { kilograms in
                                Text(weightLabel(kilograms: kilograms)).tag(kilograms)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                }

                if let error = profileService.error {
                    Section {
                        Text(error.localizedDescription)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(profileService.isLoading)
                }
            }
            .onAppear(perform: preload)
        }
    }

    private func preload() {
        if let p = profileService.userProfile {
            firstName = p.firstName
            lastName = p.lastName
            if let h = p.height { heightValue = max(100, min(220, Int(h))) }
            if let w = p.weight { weightValue = max(30, min(200, Int(w))) }
            bio = p.bio ?? ""
        }
    }

    private func save() async {
        let hVal = Double(heightValue)
        let wVal = Double(weightValue)
        let ok = await profileService.updateProfile(
            firstName: firstName.isEmpty ? nil : firstName,
            lastName: lastName.isEmpty ? nil : lastName,
            birthDate: nil,
            height: hVal,
            weight: wVal,
            bio: bio.isEmpty ? nil : bio
        )
        if ok {
            await profileService.refreshProfile()
            await MainActor.run { dismiss() }
        }
    }
}
