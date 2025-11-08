//
//  AppointmentsView.swift
//  Gym_API
//
//  Created by Claude Code on 2025-01-25
//

import SwiftUI

struct AppointmentsView: View {
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var selectedDate = Date()
    @State private var viewMode: ViewMode = .list
    @State private var showingAddAppointment = false
    @State private var isRefreshing = false

    // Mock data - TODO: Replace with actual service call
    @State private var appointments: [Appointment] = [
        Appointment(id: 1, clientName: "John Doe", sessionType: "Personal Training", startTime: Date(), duration: 60, status: .confirmed),
        Appointment(id: 2, clientName: "Jane Smith", sessionType: "Consultation", startTime: Date().addingTimeInterval(7200), duration: 30, status: .pending),
        Appointment(id: 3, clientName: "Bob Johnson", sessionType: "Follow-up", startTime: Date().addingTimeInterval(14400), duration: 45, status: .confirmed)
    ]

    var filteredAppointments: [Appointment] {
        appointments.filter { appointment in
            Calendar.current.isDate(appointment.startTime, inSameDayAs: selectedDate)
        }
        .sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View Mode Picker
                viewModePicker

                // Date Picker
                datePicker

                // Stats Summary
                statsSummary

                // Content
                if viewMode == .calendar {
                    calendarView
                } else {
                    appointmentsList
                }
            }
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .navigationTitle(workspaceContext.getCapitalizedTerm("schedule"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddAppointment = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(themeManager.currentTheme == .dark ?
                                Color(red: 0.85, green: 0.2, blue: 0.2) :
                                Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0))
                    }
                }
            }
            .refreshable {
                await refreshAppointments()
            }
            .sheet(isPresented: $showingAddAppointment) {
                AddAppointmentView()
            }
        }
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        Picker("View Mode", selection: $viewMode) {
            Label("List", systemImage: "list.bullet")
                .tag(ViewMode.list)
            Label("Calendar", systemImage: "calendar")
                .tag(ViewMode.calendar)
        }
        .pickerStyle(.segmented)
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
    }

    // MARK: - Date Picker

    private var datePicker: some View {
        HStack {
            Button(action: {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(themeManager.currentTheme == .dark ?
                        Color(red: 0.85, green: 0.2, blue: 0.2) :
                        Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0))
            }

            Spacer()

            VStack(spacing: 2) {
                Text(selectedDate, style: .date)
                    .font(.headline)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                if Calendar.current.isDateInToday(selectedDate) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme == .dark ?
                            Color(red: 0.85, green: 0.2, blue: 0.2) :
                            Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0))
                }
            }

            Spacer()

            Button(action: {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(themeManager.currentTheme == .dark ?
                        Color(red: 0.85, green: 0.2, blue: 0.2) :
                        Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0))
            }

            Button(action: {
                selectedDate = Date()
            }) {
                Text("Today")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.currentTheme == .dark ?
                                Color(red: 0.85, green: 0.2, blue: 0.2) :
                                Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0))
                    )
            }
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
    }

    // MARK: - Stats Summary

    private var statsSummary: some View {
        HStack(spacing: 20) {
            AppointmentStatBadge(
                icon: "checkmark.circle.fill",
                value: "\(filteredAppointments.filter { $0.status == .confirmed }.count)",
                label: "Confirmed",
                color: .green,
                theme: themeManager.currentTheme
            )

            AppointmentStatBadge(
                icon: "clock.fill",
                value: "\(filteredAppointments.filter { $0.status == .pending }.count)",
                label: "Pending",
                color: .orange,
                theme: themeManager.currentTheme
            )

            AppointmentStatBadge(
                icon: "calendar",
                value: "\(filteredAppointments.count)",
                label: "Total",
                color: .blue,
                theme: themeManager.currentTheme
            )
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
    }

    // MARK: - Calendar View

    private var calendarView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Mini calendar grid
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    )
                    .padding()

                // Appointments for selected date
                if filteredAppointments.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredAppointments) { appointment in
                            AppointmentCard(appointment: appointment, theme: themeManager.currentTheme)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Appointments List

    private var appointmentsList: some View {
        ScrollView {
            if filteredAppointments.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredAppointments) { appointment in
                        NavigationLink(destination: AppointmentDetailView(appointment: appointment)) {
                            AppointmentCard(appointment: appointment, theme: themeManager.currentTheme)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No \(workspaceContext.getTerm("appointments"))")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text("No appointments scheduled for this day")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                showingAddAppointment = true
            }) {
                Text("Schedule \(workspaceContext.getCapitalizedTerm("appointment"))")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeManager.currentTheme == .dark ?
                                Color(red: 0.85, green: 0.2, blue: 0.2) :
                                Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0))
                    )
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .padding(.top, 60)
    }

    // MARK: - Data Methods

    private func refreshAppointments() async {
        isRefreshing = true
        // TODO: Call actual service to fetch appointments
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
}

// MARK: - View Mode Enum

enum ViewMode {
    case list
    case calendar
}

// MARK: - Appointment Stat Badge Component

struct AppointmentStatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let theme: ThemeManager.AppTheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color.dynamicText(theme: theme))

                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Appointment Card Component

struct AppointmentCard: View {
    let appointment: Appointment
    let theme: ThemeManager.AppTheme

    var body: some View {
        HStack(spacing: 12) {
            // Time Indicator
            VStack(spacing: 4) {
                Text(appointment.startTime, style: .time)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.dynamicText(theme: theme))

                Text("\(appointment.duration) min")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70)

            // Colored Bar
            Rectangle()
                .fill(appointment.status == .confirmed ? Color.green : Color.orange)
                .frame(width: 4)
                .cornerRadius(2)

            // Appointment Details
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.clientName)
                    .font(.headline)
                    .foregroundColor(Color.dynamicText(theme: theme))

                Text(appointment.sessionType)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: appointment.status.icon)
                        .font(.caption2)

                    Text(appointment.status.displayName)
                        .font(.caption2)
                }
                .foregroundColor(appointment.status.color)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: theme))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Appointment Model

struct Appointment: Identifiable {
    let id: Int
    let clientName: String
    let sessionType: String
    let startTime: Date
    let duration: Int // in minutes
    let status: AppointmentStatus
}

enum AppointmentStatus {
    case confirmed
    case pending
    case cancelled
    case completed

    var displayName: String {
        switch self {
        case .confirmed: return "Confirmed"
        case .pending: return "Pending"
        case .cancelled: return "Cancelled"
        case .completed: return "Completed"
        }
    }

    var icon: String {
        switch self {
        case .confirmed: return "checkmark.circle.fill"
        case .pending: return "clock.fill"
        case .cancelled: return "xmark.circle.fill"
        case .completed: return "checkmark.seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .confirmed: return .green
        case .pending: return .orange
        case .cancelled: return .red
        case .completed: return .blue
        }
    }
}

// MARK: - Add Appointment View (Placeholder)

struct AddAppointmentView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var selectedClient = ""
    @State private var sessionType = ""
    @State private var selectedDate = Date()
    @State private var duration = 60

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("\(workspaceContext.getCapitalizedTerm("appointment")) Details")) {
                    TextField("\(workspaceContext.getCapitalizedTerm("client")) Name", text: $selectedClient)

                    TextField("Session Type", text: $sessionType)

                    DatePicker("Date & Time", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])

                    Stepper("Duration: \(duration) min", value: $duration, in: 15...180, step: 15)
                }
            }
            .navigationTitle("New \(workspaceContext.getCapitalizedTerm("appointment"))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Save appointment
                        dismiss()
                    }
                    .disabled(selectedClient.isEmpty || sessionType.isEmpty)
                }
            }
        }
    }
}

// MARK: - Appointment Detail View (Placeholder)

struct AppointmentDetailView: View {
    let appointment: Appointment
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var workspaceContext: WorkspaceContextService

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: appointment.status.icon)
                        .font(.system(size: 60))
                        .foregroundColor(appointment.status.color)

                    Text(appointment.sessionType)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Text(appointment.status.displayName)
                        .font(.subheadline)
                        .foregroundColor(appointment.status.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(appointment.status.color.opacity(0.1))
                        )
                }
                .padding()

                // Details
                VStack(alignment: .leading, spacing: 16) {
                    DetailRow(icon: "person.fill", title: workspaceContext.getCapitalizedTerm("client"), value: appointment.clientName)
                    DetailRow(icon: "calendar", title: "Date", value: appointment.startTime.formatted(date: .long, time: .omitted))
                    DetailRow(icon: "clock", title: "Time", value: appointment.startTime.formatted(date: .omitted, time: .shortened))
                    DetailRow(icon: "hourglass", title: "Duration", value: "\(appointment.duration) minutes")
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                )
                .padding(.horizontal)

                // Actions
                VStack(spacing: 12) {
                    Button(action: {
                        // TODO: Edit appointment
                    }) {
                        Label("Edit \(workspaceContext.getCapitalizedTerm("appointment"))", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.currentTheme == .dark ?
                                        Color(red: 0.85, green: 0.2, blue: 0.2) :
                                        Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0))
                            )
                            .foregroundColor(.white)
                    }

                    if appointment.status != .cancelled {
                        Button(action: {
                            // TODO: Cancel appointment
                        }) {
                            Label("Cancel \(workspaceContext.getCapitalizedTerm("appointment"))", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.red, lineWidth: 2)
                                )
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .navigationTitle(appointment.clientName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Note: DetailRow component already exists in EventDetailView.swift
// Using existing component

// MARK: - Preview

#Preview {
    AppointmentsView()
        .environmentObject(WorkspaceContextService.shared)
        .environmentObject(ThemeManager())
}
