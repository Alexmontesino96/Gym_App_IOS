//
//  EditSessionView.swift
//  Gym_API
//
//  View for editing existing class sessions
//

import SwiftUI

struct EditSessionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var classService: ClassService
    @StateObject private var sessionService = SessionCreationService()
    @StateObject private var gymService = GymService.shared
    @Environment(\.dismiss) private var dismiss
    
    // Session data to edit
    let sessionToEdit: SessionWithClass
    
    // Form state
    @State private var selectedClassId: Int?
    @State private var selectedTrainerId: Int?
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var room = ""
    @State private var notes = ""
    @State private var selectedStatus = "scheduled"
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var showSuccessOverlay = false
    @State private var successMessage = ""
    
    // Available status options
    private let statusOptions = [
        ("scheduled", "Scheduled"),
        ("in_progress", "In Progress"),
        ("completed", "Completed"),
        ("cancelled", "Cancelled")
    ]
    
    // Computed property for selected class
    private var selectedClass: ClassInfo? {
        guard let classId = selectedClassId else { return nil }
        return sessionService.availableClasses.first { $0.id == classId }
    }
    
    // Computed property for selected trainer
    private var selectedTrainer: UserPublicProfile? {
        guard let trainerId = selectedTrainerId else { return nil }
        return sessionService.trainers.first { $0.id == trainerId }
    }
    
    // Date formatters
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
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
                        
                        // Status Selection
                        statusSelectionSection
                        
                        // Room & Notes Section
                        roomNotesSection
                        
                        // Action Buttons
                        actionButtons
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .overlay(successOverlay)
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }
        }
        .onAppear {
            setupServices()
            loadSessionData()
            Task {
                await sessionService.fetchAvailableClasses()
                await sessionService.fetchTrainers()
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(sessionService.updateSessionErrorMessage ?? sessionService.deleteSessionErrorMessage ?? "An error occurred while processing your request.")
        }
        .alert("Success! ✅", isPresented: $showingSuccessAlert) {
            Button("OK") { 
                // Haptic feedback
                if #available(iOS 13.0, *) {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
                dismiss()
            }
        } message: {
            if sessionService.updateSessionSuccessMessage != nil {
                Text("The session has been successfully updated.\n\nChanges will be reflected in the schedule immediately.")
            } else if sessionService.deleteSessionSuccessMessage != nil {
                Text("The session has been successfully removed.\n\n\(sessionService.deleteSessionSuccessMessage ?? "")")
            } else {
                Text("Operation completed successfully.")
            }
        }
        .alert("Confirm Deletion", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Session", role: .destructive) {
                Task {
                    await deleteSession()
                }
            }
        } message: {
            Text("Are you sure you want to delete this session?\n\nClass: \(sessionToEdit.classInfo.name)\nTime: \(dateFormatter.string(from: sessionToEdit.session.startTime))\n\nNote: If participants are registered, the session will be cancelled instead of deleted.")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Edit Class Session")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text("Update the details of this gym session")
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
                ForEach(sessionService.availableClasses) { classInfo in
                    Button(action: {
                        selectedClassId = classInfo.id
                        // Auto-calculate end time based on class duration
                        let duration = TimeInterval(classInfo.duration * 60)
                        endDate = startDate.addingTimeInterval(duration)
                    }) {
                        VStack(alignment: .leading) {
                            Text(classInfo.name)
                            Text("\\(classInfo.duration) min • \\(classInfo.difficultyLevel.displayName)")
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
                            Text("\\(selectedClass.duration) min • Max: \\(selectedClass.maxCapacity)")
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
            
            if sessionService.isLoadingClasses {
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
                ForEach(sessionService.trainers) { trainer in
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
            
            if sessionService.isLoadingTrainers {
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
            
            // End Date/Time Picker
            DatePicker(
                "End Time",
                selection: $endDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
        }
    }
    
    // MARK: - Status Selection Section
    private var statusSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Status", systemImage: "flag.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Menu {
                ForEach(statusOptions, id: \.0) { status in
                    Button(action: {
                        selectedStatus = status.0
                    }) {
                        Text(status.1)
                    }
                }
            } label: {
                HStack {
                    Text(statusOptions.first { $0.0 == selectedStatus }?.1 ?? "Scheduled")
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
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
    
    // MARK: - Success Overlay
    @ViewBuilder
    private var successOverlay: some View {
        if showSuccessOverlay {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 20) {
                    // Checkmark animation
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(showSuccessOverlay ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showSuccessOverlay)
                    
                    Text("Success!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(successMessage)
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                )
                .scaleEffect(showSuccessOverlay ? 1.0 : 0.8)
                .opacity(showSuccessOverlay ? 1.0 : 0.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showSuccessOverlay)
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Update Button
            Button(action: updateSession) {
                if sessionService.isUpdatingSession {
                    HStack {
                        ProgressView()
                            .tint(.white)
                        Text("Updating...")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    Text("Update Session")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        (selectedClassId == nil || selectedTrainerId == nil || sessionService.isUpdatingSession) ?
                        Color.gray.opacity(0.5) :
                        Color.dynamicAccent(theme: themeManager.currentTheme)
                    )
            )
            .disabled(selectedClassId == nil || selectedTrainerId == nil || sessionService.isUpdatingSession)
            
            // Delete Button
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                if sessionService.isDeletingSession {
                    HStack {
                        ProgressView()
                            .tint(.white)
                        Text("Deleting...")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    Text("Delete Session")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(sessionService.isDeletingSession ? Color.gray.opacity(0.5) : Color.red)
            )
            .disabled(sessionService.isDeletingSession)
        }
    }
    
    // MARK: - Helper Methods
    private func setupServices() {
        sessionService.authService = authService
        sessionService.classService = classService
    }
    
    private func loadSessionData() {
        // Pre-fill the form with existing session data
        selectedClassId = sessionToEdit.classInfo.id
        selectedTrainerId = sessionToEdit.session.trainerId
        startDate = sessionToEdit.session.startTime
        endDate = sessionToEdit.session.endTime
        room = sessionToEdit.session.room ?? ""
        notes = sessionToEdit.session.notes ?? ""
        selectedStatus = sessionToEdit.session.status.rawValue
    }
    
    private func updateSession() {
        guard let classId = selectedClassId,
              let trainerId = selectedTrainerId else {
            sessionService.updateSessionErrorMessage = "Please select both a class and a trainer"
            showingErrorAlert = true
            return
        }
        
        // Validate dates
        guard endDate > startDate else {
            sessionService.updateSessionErrorMessage = "End time must be after start time"
            showingErrorAlert = true
            return
        }
        
        let sessionData = ClassSessionUpdate(
            classId: classId,
            trainerId: trainerId,
            startTime: startDate,
            endTime: endDate,
            room: room.isEmpty ? nil : room,
            isRecurring: nil,
            recurrencePattern: nil,
            status: selectedStatus,
            currentParticipants: nil,
            notes: notes.isEmpty ? nil : notes,
            overrideCapacity: nil
        )
        
        Task {
            let success = await sessionService.updateSession(sessionId: sessionToEdit.session.id, sessionData: sessionData)
            
            await MainActor.run {
                if success {
                    // Show success overlay
                    successMessage = "Session updated successfully!"
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSuccessOverlay = true
                    }
                    
                    // Haptic feedback
                    if #available(iOS 13.0, *) {
                        let notificationFeedback = UINotificationFeedbackGenerator()
                        notificationFeedback.notificationOccurred(.success)
                    }
                    
                    // Hide overlay and dismiss after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showSuccessOverlay = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
                    }
                } else {
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func deleteSession() async {
        let success = await sessionService.deleteSession(sessionId: sessionToEdit.session.id)
        
        await MainActor.run {
            if success {
                // Show success overlay
                successMessage = "Session deleted successfully!"
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showSuccessOverlay = true
                }
                
                // Haptic feedback
                if #available(iOS 13.0, *) {
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                }
                
                // Hide overlay and dismiss after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSuccessOverlay = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                }
            } else {
                showingErrorAlert = true
            }
        }
    }
}

#Preview {
    // Create a sample session for preview
    let sampleSession = ClassSession(
        classId: 1,
        trainerId: 1,
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        room: "Studio A",
        isRecurring: false,
        recurrencePattern: nil,
        status: .scheduled,
        overrideCapacity: nil,
        notes: "Sample session",
        id: 1,
        gymId: 1,
        currentParticipants: 5,
        createdAt: Date(),
        updatedAt: nil,
        createdBy: 1,
        gymTimezone: "UTC",
        timeInfo: TimeInfo(
            localTime: "10:00 AM",
            gymTimezone: "UTC",
            isoWithTimezone: "2025-01-01T10:00:00Z",
            utcTime: "2025-01-01T10:00:00Z"
        )
    )
    
    let sampleClassInfo = ClassInfo(
        name: "Yoga Class",
        description: "Relaxing yoga session",
        duration: 60,
        maxCapacity: 20,
        difficultyLevel: .beginner,
        categoryId: 1,
        categoryEnum: "fitness",
        category: "Fitness",
        isActive: true,
        gymId: 1,
        id: 1,
        createdAt: Date(),
        updatedAt: nil,
        createdBy: 1,
        customCategory: nil
    )
    
    let sampleSessionWithClass = SessionWithClass(
        session: sampleSession,
        classInfo: sampleClassInfo
    )
    
    EditSessionView(sessionToEdit: sampleSessionWithClass)
        .environmentObject(ThemeManager())
        .environmentObject(AuthServiceDirect())
        .environmentObject(ClassService())
}