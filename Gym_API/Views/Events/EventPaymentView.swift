//
//  EventPaymentView.swift
//  Gym_API
//
//  Vista modal para procesar pagos de eventos con Stripe - Diseño moderno
//

import SwiftUI
import UIKit

struct EventPaymentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var stripeService = StripeService.shared

    let paymentIntent: PaymentIntent
    let participationId: Int?
    let event: Event?
    let onPaymentComplete: (Bool) -> Void

    @State private var isProcessing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccessView = false
    @State private var currentViewController: UIViewController?
    @State private var scrollOffset: CGFloat = 0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if showingSuccessView {
                PaymentSuccessView(
                    eventTitle: event?.title ?? "Evento",
                    amount: paymentIntent.amount,
                    currency: paymentIntent.currency,
                    onDone: {
                        onPaymentComplete(true)
                        dismiss()
                    }
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero Section with Event Image
                        EventHeroSection(event: event)

                        // Main Content
                        VStack(spacing: 20) {
                            // Event Title and Date
                            EventInfoCard(event: event)

                            // Price Card - Prominent
                            PriceCard(
                                amount: paymentIntent.amount,
                                currency: paymentIntent.currency
                            )

                            // Payment Methods Preview
                            PaymentMethodsPreview()

                            // Additional Info
                            VStack(spacing: 12) {
                                // Payment deadline
                                if let deadline = paymentIntent.paymentDeadline {
                                    PaymentDeadlineCard(deadline: deadline)
                                }

                                // Refund policy
                                if let refundPolicy = event?.refundPolicy {
                                    RefundPolicyCard(
                                        policy: refundPolicy,
                                        deadlineHours: event?.refundDeadlineHours,
                                        percentage: event?.partialRefundPercentage
                                    )
                                }
                            }

                            // Security Badge
                            SecurityBadge()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, -30) // Overlap hero section
                        .padding(.bottom, 120) // Space for fixed button
                    }
                }

                // Fixed Bottom Section with Actions
                VStack(spacing: 0) {
                    Spacer()

                    // Gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.8),
                            Color.dynamicBackground(theme: themeManager.currentTheme)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)

                    // Action Buttons
                    VStack(spacing: 12) {
                        // Primary Pay Button
                        Button(action: presentPaymentSheet) {
                            HStack(spacing: 12) {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "lock.shield.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Pagar de forma segura")
                                        .font(.system(size: 17, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.dynamicAccent(theme: themeManager.currentTheme),
                                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(
                                color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                        }
                        .disabled(isProcessing)
                        .scaleEffect(isProcessing ? 0.98 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isProcessing)

                        // Cancel Button
                        Button(action: {
                            onPaymentComplete(false)
                            dismiss()
                        }) {
                            Text("Cancelar")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .background(Color.dynamicBackground(theme: themeManager.currentTheme))
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .alert("Error de Pago", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            setupPaymentSheet()
        }
        .background(ViewControllerHolder { vc in
            currentViewController = vc
        })
    }

    // MARK: - Payment Methods

    private func setupPaymentSheet() {
        isProcessing = true

        Task {
            do {
                try await Task.sleep(nanoseconds: 500_000_000)

                try await stripeService.configurePaymentSheet(
                    clientSecret: paymentIntent.clientSecret,
                    merchantDisplayName: "Gym App",
                    stripeAccountId: paymentIntent.stripeAccountId,
                    applePay: true
                )

                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error configurando el pago: \(error.localizedDescription)"
                    showingError = true
                    isProcessing = false
                }
            }
        }
    }

    private func presentPaymentSheet() {
        isProcessing = true

        stripeService.presentPaymentSheet(from: currentViewController) { result in
            switch result {
            case .completed:
                self.confirmPaymentWithBackend()
            case .canceled:
                self.isProcessing = false
            case .failed(let error):
                self.errorMessage = "Error en el pago: \(error.localizedDescription)"
                self.showingError = true
                self.isProcessing = false
            }
        }
    }

    private func confirmPaymentWithBackend() {
        Task {
            if let participationId = participationId {
                // Check if payment was already confirmed by webhook
                let success = await EventPaymentService.shared.confirmPayment(
                    participationId: participationId,
                    paymentIntentId: paymentIntent.paymentIntentId
                )

                if success {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showingSuccessView = true
                        }
                    }
                } else {
                    // If webhook already confirmed, treat as success
                    let errorMsg = EventPaymentService.shared.paymentError ?? ""
                    if errorMsg.contains("ya fue confirmado") || errorMsg.contains("already confirmed") {
                        await MainActor.run {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showingSuccessView = true
                            }
                        }
                    } else {
                        await MainActor.run {
                            errorMessage = errorMsg
                            showingError = true
                            isProcessing = false
                        }
                    }
                }
            } else {
                await MainActor.run {
                    errorMessage = "No se encontró el ID de participación"
                    showingError = true
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct EventHeroSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    let event: Event?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)

            // Pattern overlay
            GeometryReader { geometry in
                ForEach(0..<6) { i in
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 80, height: 80)
                        .offset(
                            x: CGFloat(i % 3) * geometry.size.width / 3,
                            y: CGFloat(i / 3) * 100
                        )
                }
            }
            .frame(height: 200)

            // Event Icon
            VStack {
                Spacer()
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                Spacer()
            }
            .frame(height: 200)
        }
    }
}

struct EventInfoCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let event: Event?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event?.title ?? "Evento")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(2)

            HStack(spacing: 16) {
                Label {
                    Text(event?.formattedStartTime ?? "")
                        .font(.system(size: 14, weight: .medium))
                } icon: {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                }
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                Label {
                    Text(event?.location ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                }
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(
                    color: .black.opacity(0.05),
                    radius: 10,
                    x: 0,
                    y: 4
                )
        )
    }
}

struct PriceCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let amount: Int
    let currency: String

    private var formattedPrice: String {
        let price = Double(amount) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total a pagar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                    Text(formattedPrice)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }

                Spacer()

                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3))
            }

            Divider()
                .background(Color.dynamicBorder(theme: themeManager.currentTheme))

            HStack {
                Text("Registro del evento")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                Spacer()
                Text(formattedPrice)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 2)
                )
                .shadow(
                    color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1),
                    radius: 15,
                    x: 0,
                    y: 8
                )
        )
    }
}

struct PaymentMethodsPreview: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Métodos de pago")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            HStack(spacing: 12) {
                PaymentMethodIcon(icon: "applelogo", name: "Apple Pay")
                PaymentMethodIcon(icon: "creditcard.fill", name: "Tarjeta")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5))
        )
    }
}

struct PaymentMethodIcon: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let name: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    Capsule()
                        .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                )
        )
    }
}

struct PaymentDeadlineCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let deadline: Date

    private var timeRemaining: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: deadline, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 16))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Plazo de pago")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                Text(timeRemaining)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.orange)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct RefundPolicyCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let policy: RefundPolicyType
    let deadlineHours: Int?
    let percentage: Int?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.counterclockwise.circle")
                .font(.system(size: 16))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Política de reembolso")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                Text(policyDescription)
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.08))
        )
    }

    private var policyDescription: String {
        switch policy {
        case .fullRefund:
            if let hours = deadlineHours {
                return "Reembolso completo hasta \(hours)h antes"
            }
            return "Reembolso completo disponible"
        case .partialRefund:
            if let percentage = percentage, let hours = deadlineHours {
                return "Reembolso del \(percentage)% hasta \(hours)h antes"
            }
            return "Reembolso parcial disponible"
        case .credit:
            return "Crédito para futuros eventos"
        case .noRefund:
            return "No se permiten reembolsos"
        }
    }
}

struct SecurityBadge: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 14))
                .foregroundColor(.green)

            Text("Pago seguro con Stripe")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct PaymentSuccessView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let eventTitle: String
    let amount: Int
    let currency: String
    let onDone: () -> Void

    @State private var showCheckmark = false
    @State private var showConfetti = false
    @State private var showContent = false

    private var formattedPrice: String {
        let price = Double(amount) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Success Animation
            ZStack {
                // Background circles
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.green.opacity(0.1 - Double(i) * 0.03))
                        .frame(width: 140 + CGFloat(i) * 20, height: 140 + CGFloat(i) * 20)
                        .scaleEffect(showCheckmark ? 1 : 0)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7)
                            .delay(Double(i) * 0.1),
                            value: showCheckmark
                        )
                }

                // Checkmark
                Circle()
                    .fill(Color.green)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .scaleEffect(showCheckmark ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: showCheckmark)
            }
            .padding(.bottom, 40)

            // Success Content
            VStack(spacing: 16) {
                Text("¡Pago Exitoso!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text("Has pagado")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                Text(formattedPrice)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.green)

                Text("por el evento")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                Text(eventTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: showContent)

            Spacer()

            // Done Button
            Button(action: onDone) {
                Text("Continuar")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.green.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.7), value: showContent)
        }
        .onAppear {
            withAnimation {
                showCheckmark = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showContent = true
            }
        }
    }
}

// MARK: - ViewControllerHolder Helper
struct ViewControllerHolder: UIViewControllerRepresentable {
    let callback: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        DispatchQueue.main.async {
            if let parent = vc.parent {
                self.callback(parent)
            }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

#Preview {
    EventPaymentView(
        paymentIntent: PaymentIntent(
            clientSecret: "test_secret",
            paymentIntentId: "pi_test",
            stripeAccountId: nil,
            amount: 2999,
            currency: "USD",
            paymentDeadline: Date().addingTimeInterval(86400)
        ),
        participationId: 1,
        event: nil,
        onPaymentComplete: { _ in }
    )
    .environmentObject(ThemeManager())
}
