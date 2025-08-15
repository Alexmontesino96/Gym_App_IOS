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

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("edit_profile", comment: "Edit Profile"))) {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                    TextField("Bio", text: $bio, axis: .vertical)
                }

                Section(header: Text("Measurements (metric)")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("height", comment: "Height"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Picker("Height", selection: $heightValue) {
                            ForEach(100...220, id: \.self) { v in
                                Text("\(v) cm").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("weight", comment: "Weight"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Picker("Weight", selection: $weightValue) {
                            ForEach(30...200, id: \.self) { v in
                                Text("\(v) kg").tag(v)
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
            .navigationTitle(NSLocalizedString("edit_profile", comment: "Edit Profile"))
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
