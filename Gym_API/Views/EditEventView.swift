//
//  EditEventView.swift
//  Gym_API
//
//  Created by Assistant on 8/18/25.
//

import SwiftUI

struct EditEventView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var eventService: EventService
    @Environment(\.dismiss) private var dismiss
    
    let event: Event
    
    @State private var formData: EventFormData
    @State private var isSubmitting = false
    @State private var showingSuccessMessage = false
    @State private var showingErrorMessage = false
    @State private var errorMessage = ""
    
    init(event: Event) {
        self.event = event
        // Initialize form data with event values
        self._formData = State(initialValue: EventFormData(
            title: event.title,
            description: event.description,
            startDate: event.startTime,
            endDate: event.endTime,
            location: event.location,
            maxParticipants: event.maxParticipants,
            firstMessage: ""
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Event Details Section
                        SettingsCard(title: "Detalles del Evento", themeManager: themeManager) {
                            formSection
                        }
                        
                        // Validation Errors Section
                        if !formData.validationErrors.isEmpty {
                            validationErrorsSection
                        }
                        
                        // Save Button
                        saveButtonSection
                        bulkRegistrationSheet // attach sheet host
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { 
                        dismiss() 
                    }
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                ToolbarItem(placement: .principal) {
                    Text("Editar Evento")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if RolePermissions.canBulkRegisterUsers(GymService.shared.currentGym?.userRoleInGym) {
                        Button {
                            showingBulkRegistration = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                        .accessibilityLabel("Registro Masivo")
                    }
                }
            }
        }
    }
    
    
    // MARK: - Save Button Section
    @ViewBuilder
    private var saveButtonSection: some View {
        Button(action: updateEvent) {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Text(isSubmitting ? "Guardando..." : "Guardar Cambios")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        formData.isValid && !isSubmitting 
                            ? Color.dynamicAccent(theme: themeManager.currentTheme)
                            : Color.gray
                    )
            )
        }
        .disabled(!formData.isValid || isSubmitting)
    }
    
    // MARK: - Form Section
    @ViewBuilder
    private var formSection: some View {
        VStack(spacing: 16) {
            // Title Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Título del Evento")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                TextField("Ingresa el título del evento", text: $formData.title)
                    .textFieldStyle(ConsistentTextFieldStyle(themeManager: themeManager))
            }
            
            // Description Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Descripción")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                        )
                        .frame(minHeight: 100)
                    
                    if formData.description.isEmpty {
                        Text("Describe los detalles del evento...")
                            .font(.system(size: 16))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.6))
                            .padding(.top, 22)
                            .padding(.leading, 18)
                    }
                    
                    TextEditor(text: $formData.description)
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .padding(16)
                }
            }
            
            // Location Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Ubicación")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                TextField("Donde se realizará el evento", text: $formData.location)
                    .textFieldStyle(ConsistentTextFieldStyle(themeManager: themeManager))
            }
            
            // Date and Time Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Programación")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                VStack(spacing: 16) {
                    // Start Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Inicio")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        
                        DatePicker("", selection: $formData.startDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    
                    Divider()
                        .background(Color.dynamicBorder(theme: themeManager.currentTheme))
                    
                    // End Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fin")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        
                        DatePicker("", selection: $formData.endDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                        )
                )
            }
            
            // Max Participants
            VStack(alignment: .leading, spacing: 12) {
                Text("Capacidad")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Participantes máximos")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Text("Actualmente: \(event.participantsCount) inscritos")
                                .font(.system(size: 12))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                        
                        Spacer()
                        
                        Text("\(formData.maxParticipants)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .frame(minWidth: 60)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(formData.maxParticipants) },
                            set: { formData.maxParticipants = Int($0) }
                        ),
                        in: Double(max(event.participantsCount, 1))...100,
                        step: 1
                    )
                    .tint(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Validation Errors Section
    @ViewBuilder
    private var validationErrorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Revisa los siguientes campos")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text("Algunos campos necesitan corrección")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(formData.validationErrors, id: \.self) { error in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Functions
    private func updateEvent() {
        guard formData.isValid else { return }
        
        isSubmitting = true
        
        Task {
            let updateRequest = UpdateEventRequest.fromEventFormData(formData)
            let success = await eventService.updateEvent(eventId: event.id, request: updateRequest)
            
            await MainActor.run {
                isSubmitting = false
                
                if success {
                    showingSuccessMessage = true
                } else {
                    errorMessage = eventService.createEventErrorMessage ?? "Error desconocido al actualizar el evento"
                    showingErrorMessage = true
                }
            }
        }
    }

    // MARK: - Bulk Registration Sheet
    @State private var showingBulkRegistration = false
}

extension EditEventView {
    @ViewBuilder
    var bulkRegistrationSheet: some View {
        EmptyView()
            .sheet(isPresented: $showingBulkRegistration) {
                BulkRegistrationView(event: event)
                    .environmentObject(themeManager)
                    .environmentObject(authService)
                    .environmentObject(eventService)
                    .environmentObject(GymService.shared)
            }
    }
}

// MARK: - Consistent Text Field Style
struct ConsistentTextFieldStyle: TextFieldStyle {
    let themeManager: ThemeManager
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                    )
            )
            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
    }
}

#Preview {
    let sampleEvent = Event(
        id: 1,
        title: "Sample Event",
        description: "This is a sample event for testing",
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        location: "Main Gym",
        maxParticipants: 20,
        status: .scheduled,
        creatorId: 1,
        createdAt: Date(),
        updatedAt: Date(),
        participantsCount: 5,
        isPaid: false,
        priceCents: nil,
        currency: nil,
        refundPolicy: nil,
        refundDeadlineHours: nil,
        partialRefundPercentage: nil,
        stripeProductId: nil,
        stripePriceId: nil
    )
    
    EditEventView(event: sampleEvent)
        .environmentObject(ThemeManager())
        .environmentObject(AuthServiceDirect())
        .environmentObject(EventService())
}
