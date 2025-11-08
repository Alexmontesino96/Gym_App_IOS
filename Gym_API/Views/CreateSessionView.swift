//
//  CreateSessionView.swift
//  Gym_API
//
//  View for creating new class sessions
//
// TODO: This view needs to be refactored to work with the new ScheduledActivityService
// Temporarily simplified to fix build errors

import SwiftUI

// Temporary placeholder - remove when implementation is fixed
struct CreateSessionView_PLACEHOLDER: View {
    var body: some View {
        Text("Create Session View - Coming Soon")
            .font(.title2)
            .foregroundColor(.secondary)
    }
}

// Restored implementation
struct CreateSessionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var classService: ClassService
    @StateObject private var activityService = ScheduledActivityService.shared
    @StateObject private var gymService = GymService.shared
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var selectedClassId: Int?
    @State private var selectedTrainerId: Int?
    @State private var startDate = Date().addingTimeInterval(3600) // Default to 1 hour from now
    @State private var endDate = Date().addingTimeInterval(7200) // Default to 2 hours from now
    @State private var room = ""
    @State private var notes = ""
    @State private var showingDatePicker = false
    @State private var showingEndDatePicker = false
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    @State private var validationErrors: [String] = []
    
    // Computed property for selected class
    private var selectedClass: ClassInfo? {
        guard let classId = selectedClassId else { return nil }
        return activityService.availableClasses.first { $0.id == classId }
    }

    // Computed property for selected trainer
    private var selectedTrainer: UserPublicProfile? {
        guard let trainerId = selectedTrainerId else { return nil }
        return activityService.trainers.first { $0.id == trainerId }
    }
    
    // Date formatters
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Class Selection
                        classSelectionSection
                        
                        // Trainer Selection
                        trainerSelectionSection
                        
                        // Date & Time Section
                        dateTimeSection
                        
                        // Room & Notes Section
                        roomNotesSection
                        
                        // Create Button
                        createSessionButton
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Create Session")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            )
        }
        .onAppear {
            Task {
                await activityService.loadAvailableClasses()
                await activityService.loadTrainers()
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(activityService.operationError ?? "An error occurred")
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Session created successfully")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New Class Session")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text("Schedule a new session for your gym members")
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Class Selection Section
    private var classSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Class", systemImage: "figure.run")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Menu {
                ForEach(activityService.availableClasses) { classInfo in
                    Button(action: {
                        selectedClassId = classInfo.id
                        // Auto-calculate end time based on class duration
                        let duration = TimeInterval(classInfo.duration * 60)
                        endDate = startDate.addingTimeInterval(duration)
                    }) {
                        VStack(alignment: .leading) {
                            Text(classInfo.name)
                            Text("\(classInfo.duration) min • \(classInfo.difficultyLevel.displayName)")
                                .font(.caption)
                        }
                    }
                }
            } label: {
                HStack {
                    if let selectedClass = selectedClass {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedClass.name)
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            Text("\(selectedClass.duration) min • Max: \(selectedClass.maxCapacity)")
                                .font(.caption)
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                    } else {
                        Text("Select a class")
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                )
            }
            
            if activityService.isCreating {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Trainer Selection Section
    private var trainerSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Trainer", systemImage: "person.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Menu {
                ForEach(activityService.trainers) { trainer in
                    Button(action: {
                        selectedTrainerId = trainer.id
                    }) {
                        Text(trainer.fullName)
                    }
                }
            } label: {
                HStack {
                    if let selectedTrainer = selectedTrainer {
                        Text(selectedTrainer.fullName)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    } else {
                        Text("Select a trainer")
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                )
            }
            
            if activityService.isCreating {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Date & Time Section
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Schedule", systemImage: "calendar")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            // Start Date/Time Picker
            DatePicker(
                "Start Time",
                selection: $startDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
            .onChange(of: startDate) { _, newValue in
                // Auto-update end time based on class duration
                if let selectedClass = selectedClass {
                    let duration = TimeInterval(selectedClass.duration * 60)
                    endDate = newValue.addingTimeInterval(duration)
                }
            }
            
            // End Date/Time Display
            HStack {
                Text("End Time")
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                Spacer()
                Text(dateFormatter.string(from: endDate))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
        }
    }
    
    // MARK: - Room & Notes Section
    private var roomNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Room Field
            VStack(alignment: .leading, spacing: 8) {
                Label("Room (Optional)", systemImage: "door.left.hand.open")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                TextField("e.g., Studio A", text: $room)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    )
            }
            
            // Notes Field
            VStack(alignment: .leading, spacing: 8) {
                Label("Notes (Optional)", systemImage: "note.text")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                TextField("Additional information...", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...6)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    )
            }
        }
    }
    
    // MARK: - Create Button
    private var createSessionButton: some View {
        Button(action: createSession) {
            if activityService.isCreating {
                HStack {
                    ProgressView()
                        .tint(.white)
                    Text("Creating...")
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                Text("Create Session")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .foregroundColor(.white)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    (selectedClassId == nil || selectedTrainerId == nil || activityService.isCreating) ?
                    Color.gray.opacity(0.5) :
                    Color.dynamicAccent(theme: themeManager.currentTheme)
                )
        )
        .disabled(selectedClassId == nil || selectedTrainerId == nil || activityService.isCreating)
    }
    
    // MARK: - Create Session Action
    private func createSession() {
        guard let classId = selectedClassId,
              let trainerId = selectedTrainerId else {
            // Show error in alert
            showingErrorAlert = true
            return
        }

        // Validate dates
        guard startDate > Date() else {
            showingErrorAlert = true
            return
        }

        guard endDate > startDate else {
            showingErrorAlert = true
            return
        }

        // Create activity request for a class session
        let request = ActivityCreationRequest(
            type: .gymClass,
            title: "Class Session", // You might want to get the class name here
            description: notes.isEmpty ? "Class session" : notes,
            startTime: startDate,
            endTime: endDate,
            location: room.isEmpty ? "TBD" : room,
            maxParticipants: 20, // Default capacity - you might want to get this from the class
            instructorId: trainerId,
            isRecurring: false,
            recurrencePattern: nil,
            notes: notes.isEmpty ? nil : notes
        )

        Task {
            do {
                let newActivityId = try await activityService.createActivity(request)
                await MainActor.run {
                    print("✅ Session created successfully with ID: \(newActivityId)")
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to create session: \(error)")
                    showingErrorAlert = true
                }
            }
        }
    }
}

#Preview {
    CreateSessionView()
        .environmentObject(ThemeManager())
        .environmentObject(AuthServiceDirect())
        .environmentObject(ClassService())
}