import SwiftUI

struct EditProfileSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var profileService = UserProfileService.shared

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var height: String = ""
    @State private var weight: String = ""
    @State private var bio: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("edit_profile", comment: "Edit Profile"))) {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                    TextField(NSLocalizedString("height", comment: "Height"), text: $height)
                        .keyboardType(.numberPad)
                    TextField(NSLocalizedString("weight", comment: "Weight"), text: $weight)
                        .keyboardType(.numberPad)
                    TextField("Bio", text: $bio, axis: .vertical)
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
            if let h = p.height { height = String(Int(h)) }
            if let w = p.weight { weight = String(Int(w)) }
            bio = p.bio ?? ""
        }
    }

    private func save() async {
        let hVal = Double(height)
        let wVal = Double(weight)
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

