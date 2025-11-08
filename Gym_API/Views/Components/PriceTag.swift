//
//  PriceTag.swift
//  Gym_API
//
//  Componente reutilizable para mostrar precios de eventos
//

import SwiftUI

struct PriceTag: View {
    let price: String?
    let isPaid: Bool
    let size: PriceTagSize
    @EnvironmentObject var themeManager: ThemeManager

    enum PriceTagSize {
        case small, medium, large

        var fontSize: Font {
            switch self {
            case .small: return .system(size: 12, weight: .semibold)
            case .medium: return .system(size: 14, weight: .bold)
            case .large: return .system(size: 16, weight: .bold)
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .medium: return EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            case .large: return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
            }
        }
    }

    init(price: String?, isPaid: Bool = true, size: PriceTagSize = .medium) {
        self.price = price
        self.isPaid = isPaid
        self.size = size
    }

    var body: some View {
        if isPaid, let price = price {
            Text(price)
                .font(size.fontSize)
                .foregroundColor(.white)
                .padding(size.padding)
                .background(
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(LinearGradient(
                            colors: [
                                Color.dynamicAccent(theme: themeManager.currentTheme),
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )
                .shadow(color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), radius: 4, x: 0, y: 2)
        } else if !isPaid {
            Text("GRATIS")
                .font(size.fontSize)
                .foregroundColor(.green)
                .padding(size.padding)
                .background(
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .fill(Color.green.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: size.cornerRadius)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Payment Status Badge
struct PaymentStatusBadge: View {
    let status: PaymentStatus?
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        if let status = status {
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.system(size: 10, weight: .semibold))

                Text(status.displayName)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(colorForStatus(status))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorForStatus(status).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(colorForStatus(status).opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    private func colorForStatus(_ status: PaymentStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .paid: return .green
        case .refunded: return .blue
        case .credited: return .purple
        case .expired: return .red
        }
    }
}

// MARK: - Refund Info Card
struct RefundInfoCard: View {
    let policy: RefundPolicyType
    let deadlineHours: Int?
    let percentage: Int?
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: policy.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                Text("Política de reembolso")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()
            }

            Text(policy.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            if let hours = deadlineHours, policy != .noRefund {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))

                    Text("Hasta \(hours) horas antes del evento")
                        .font(.system(size: 11))
                }
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            if policy == .partialRefund, let percentage = percentage {
                HStack(spacing: 4) {
                    Image(systemName: "percent")
                        .font(.system(size: 10))

                    Text("\(percentage)% de reembolso")
                        .font(.system(size: 11))
                }
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - Price Breakdown View
struct PriceBreakdownView: View {
    let amount: Int
    let currency: String
    @EnvironmentObject var themeManager: ThemeManager

    private var formattedAmount: String {
        let value = Double(amount) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(currency) \(value)"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Total a pagar")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                Spacer()

                Text(formattedAmount)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }

            Divider()

            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)

                    Text("Pago seguro con Stripe")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                    Spacer()
                }

                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)

                    Text("Tus datos están protegidos")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        // Price tags
        HStack(spacing: 12) {
            PriceTag(price: "€49.99", size: .small)
            PriceTag(price: "€29.99", size: .medium)
            PriceTag(price: "€99.99", size: .large)
            PriceTag(price: nil, isPaid: false, size: .medium)
        }

        // Payment status badges
        // TODO: Fix PaymentStatus ambiguity
        /*
        VStack(spacing: 8) {
            PaymentStatusBadge(status: .pending)
            PaymentStatusBadge(status: .paid)
            PaymentStatusBadge(status: .refunded)
        }
        */

        // Refund info card
        RefundInfoCard(
            policy: .partialRefund,
            deadlineHours: 48,
            percentage: 75
        )

        // Price breakdown
        PriceBreakdownView(amount: 4999, currency: "EUR")
    }
    .padding()
    .environmentObject(ThemeManager())
}