//
//  CreateEventView.swift
//  Gym_API
//
//  Created by Assistant on 8/18/25.
//

import SwiftUI

struct CreateEventView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var eventService: EventService
    @StateObject private var activityService = ScheduledActivityService.shared
    @StateObject private var gymService = GymService.shared
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var formData = EventFormData()
    @State private var selectedTemplate: EventTemplate = .custom
    @State private var showingTemplateSelector = false
    @State private var showingDatePicker = false
    @State private var showingEndDatePicker = false
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    @State private var validationErrors: [String] = []
    
    // Keyboard / focus management
    @FocusState private var focusedField: Field?
    
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
                        // Template Selector
                        templateSelectorSection
                        
                        // Event Details Form
                        eventDetailsForm
                        
                        // Date & Time Section
                        dateTimeSection
                        
                        // Participants & Location
                        participantsLocationSection
                        
                        // Optional Chat Message
                        chatMessageSection
                        
                        // Create Button
                        createEventButton
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                // Dismiss keyboard by dragging the scroll
                .scrollDismissesKeyboard(.interactively)
                // Dismiss keyboard by tapping the background
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                    hideKeyboard()
                }
            }
            .navigationTitle("Crear Evento")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancelar") {
                    dismiss()
                }
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme)),
                trailing: Button("Plantillas") {
                    showingTemplateSelector = true
                }
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            )
        }
        .sheet(isPresented: $showingTemplateSelector) {
            TemplateSelectionView(selectedTemplate: $selectedTemplate) { template in
                applyTemplate(template)
            }
            .environmentObject(themeManager)
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(activityService.operationError ?? "Error desconocido")
        }
        .alert("¡Éxito!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Evento creado exitosamente")
        }
        .onAppear {
            setupServices()
        }
        .onChange(of: activityService.operationError) { _, error in
            if error != nil {
                showingErrorAlert = true
            }
        }
    }
    
    // MARK: - Template Selector Section
    private var templateSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tipo de Evento")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            HStack {
                Image(systemName: selectedTemplate.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                
                Text(selectedTemplate.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                Button("Cambiar") {
                    showingTemplateSelector = true
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
        }
    }
    
    // MARK: - Event Details Form
    private var eventDetailsForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detalles del Evento")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Título *")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                TextField("Nombre del evento", text: $formData.title)
                    .textFieldStyle(CustomTextFieldStyle(themeManager: themeManager))
                    .focused($focusedField, equals: .title)
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Descripción *")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                TextField("Describe tu evento", text: $formData.description, axis: .vertical)
                    .textFieldStyle(CustomTextFieldStyle(themeManager: themeManager))
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .description)
            }
        }
    }
    
    // MARK: - Date & Time Section
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fecha y Hora")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            // Start Date
            VStack(alignment: .leading, spacing: 8) {
                Text("Fecha y hora de inicio *")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Button(action: { showingDatePicker = true }) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        Text(dateFormatter.string(from: formData.startDate))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    )
                }
                .sheet(isPresented: $showingDatePicker) {
                    DatePickerView(selectedDate: $formData.startDate, title: "Fecha de inicio")
                        .environmentObject(themeManager)
                }
            }
            
            // End Date
            VStack(alignment: .leading, spacing: 8) {
                Text("Fecha y hora de fin *")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Button(action: { showingEndDatePicker = true }) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        Text(dateFormatter.string(from: formData.endDate))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    )
                }
                .sheet(isPresented: $showingEndDatePicker) {
                    DatePickerView(selectedDate: $formData.endDate, title: "Fecha de fin")
                        .environmentObject(themeManager)
                }
            }
        }
    }
    
    // MARK: - Participants & Location Section
    private var participantsLocationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ubicación y Participantes")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Ubicación *")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                TextField("Ej: Sala de spinning, Gimnasio principal", text: $formData.location)
                    .textFieldStyle(CustomTextFieldStyle(themeManager: themeManager))
                    .focused($focusedField, equals: .location)
            }
            
            // Max Participants
            VStack(alignment: .leading, spacing: 8) {
                Text("Máximo de participantes")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                HStack {
                    TextField("20", value: $formData.maxParticipants, format: .number)
                        .textFieldStyle(CustomTextFieldStyle(themeManager: themeManager))
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .maxParticipants)
                
                Stepper("", value: $formData.maxParticipants, in: 1...200)
                    .labelsHidden()
            }
        }
    }
    }
    
    // MARK: - Chat Message Section
    private var chatMessageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mensaje de Bienvenida")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Primer mensaje del chat (opcional)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                TextField("¡Bienvenidos! Estoy emocionado de entrenar con ustedes...", text: $formData.firstMessage, axis: .vertical)
                    .textFieldStyle(CustomTextFieldStyle(themeManager: themeManager))
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .firstMessage)
            }
        }
    }
    
    // MARK: - Create Event Button
    private var createEventButton: some View {
        VStack(spacing: 16) {
            // Validation errors
            if !validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(validationErrors, id: \.self) { error in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )
            }
            
            // Create button
            Button(action: createEvent) {
                HStack {
                    if activityService.isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    Text(activityService.isCreating ? "Creando..." : "Crear Evento")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            formData.isValid && !activityService.isCreating 
                                ? Color.dynamicAccent(theme: themeManager.currentTheme)
                                : Color.gray
                        )
                )
            }
            .disabled(!formData.isValid || activityService.isCreating)
        }
    }
    
    // MARK: - Helper Methods
    private func setupServices() {
        activityService.configure(authService: authService, gymService: gymService)
    }
    
    private func applyTemplate(_ template: EventTemplate) {
        selectedTemplate = template
        let templateData = template.formData
        
        formData.title = templateData.title
        formData.description = templateData.description
        formData.maxParticipants = templateData.maxParticipants
        
        // Keep current dates but apply template's duration if applicable
        if template != .custom {
            formData.endDate = formData.startDate.addingTimeInterval(3600) // 1 hour default
        }
    }
    
    private func createEvent() {
        // Validate form
        validationErrors = []

        // Basic validation
        if formData.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors.append("El título es requerido")
        }
        if formData.startDate <= Date() {
            validationErrors.append("La fecha de inicio debe ser futura")
        }
        if formData.endDate <= formData.startDate {
            validationErrors.append("La fecha de fin debe ser después del inicio")
        }

        if !validationErrors.isEmpty {
            return
        }

        // Create event
        Task {
            let request = ActivityCreationRequest(
                type: .event,
                title: formData.title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: formData.description.trimmingCharacters(in: .whitespacesAndNewlines),
                startTime: formData.startDate,
                endTime: formData.endDate,
                location: formData.location.trimmingCharacters(in: .whitespacesAndNewlines),
                maxParticipants: formData.maxParticipants,
                instructorId: nil,  // Events don't have instructors
                isRecurring: false,
                recurrencePattern: nil,
                notes: formData.firstMessage.isEmpty ? nil : formData.firstMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            do {
                let newEventId = try await activityService.createActivity(request)
                await MainActor.run {
                    print("✅ Event created successfully with ID: \(newEventId)")
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to create event: \(error)")
                    showingErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Focusable Fields
private enum Field: Hashable {
    case title
    case description
    case location
    case maxParticipants
    case firstMessage
}

// MARK: - Keyboard Helper
#if canImport(UIKit)
private extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
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

// MARK: - Date Picker View
struct DatePickerView: View {
    @Binding var selectedDate: Date
    let title: String
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    title,
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") {
                        dismiss()
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
        }
    }
}

// MARK: - Template Selection View
struct TemplateSelectionView: View {
    @Binding var selectedTemplate: EventTemplate
    let onTemplateSelected: (EventTemplate) -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(EventTemplate.allCases, id: \.rawValue) { template in
                    TemplateRow(
                        template: template,
                        isSelected: selectedTemplate == template,
                        themeManager: themeManager
                    ) {
                        selectedTemplate = template
                        onTemplateSelected(template)
                        dismiss()
                    }
                }
            }
            .listStyle(.plain)
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationTitle("Plantillas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }
        }
    }
}

// MARK: - Template Row
struct TemplateRow: View {
    let template: EventTemplate
    let isSelected: Bool
    let themeManager: ThemeManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: template.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    if template != .custom {
                        Text("Máx. \(template.formData.maxParticipants) participantes")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CreateEventView()
        .environmentObject(ThemeManager())
        .environmentObject(AuthServiceDirect())
        .environmentObject(EventService())
}
