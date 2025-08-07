import SwiftUI

struct MembershipStatusWidget: View {
    @ObservedObject var membershipService: MembershipService
    let themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(alignment: .leading, spacing: dynamicTypeSize.adjustedSpacing(12)) {
            // Header
            HStack {
                HStack(spacing: dynamicTypeSize.adjustedSpacing(8)) {
                    Image(systemName: membershipIconName)
                        .font(.cappedDynamicSystem(size: 18, weight: .semibold, maxSize: 24))
                        .foregroundColor(membershipColor)
                        .accessibilityHidden(true) // Hide decorative icon
                    
                    Text("Membership Status")
                        .font(.cappedDynamicSystem(size: 17, weight: .semibold, maxSize: 22))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .dynamicTypeSupport(maxLines: 2)
                }
                
                Spacer()
                
                // Status badge
                HStack(spacing: dynamicTypeSize.adjustedSpacing(4)) {
                    Circle()
                        .fill(membershipColor)
                        .frame(
                            width: min(8 * dynamicTypeSize.scalingFactor, 12),
                            height: min(8 * dynamicTypeSize.scalingFactor, 12)
                        )
                        .accessibilityHidden(true) // Hide decorative indicator
                    
                    Text(membershipStatusText)
                        .font(.cappedDynamicSystem(size: 12, weight: .medium, maxSize: 16))
                        .foregroundColor(membershipColor)
                        .dynamicTypeSupport(maxLines: 1)
                }
                .padding(.horizontal, dynamicTypeSize.adjustedPadding(8))
                .padding(.vertical, dynamicTypeSize.adjustedPadding(4))
                .background(membershipColor.opacity(0.1))
                .cornerRadius(12)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Status: \(membershipStatusText)")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Membership Status section. Status: \(membershipStatusText)")
            
            // Content based on membership status
            if membershipService.isLoading {
                MembershipSkeletonContent(themeManager: themeManager)
            } else if let membership = membershipService.membershipStatus {
                MembershipContent(
                    membership: membership,
                    membershipService: membershipService,
                    themeManager: themeManager
                )
            } else {
                MembershipErrorContent(
                    membershipService: membershipService,
                    themeManager: themeManager
                )
            }
        }
        .padding(dynamicTypeSize.adjustedPadding(16))
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(
                    color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal, dynamicTypeSize.adjustedPadding(20))
        // Accessibility: Group entire widget as one semantic unit
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Membership Status Widget")
        .accessibilityAddTraits(.isStaticText)
    }
    
    // MARK: - Computed Properties
    
    private var membershipIconName: String {
        if membershipService.isLoading {
            return "hourglass"
        }
        
        guard let membership = membershipService.membershipStatus else {
            return "exclamationmark.triangle"
        }
        
        if membership.isActive {
            if let days = membership.daysRemaining {
                if days <= 7 {
                    return "clock.badge.exclamationmark"
                } else {
                    return "checkmark.shield"
                }
            } else {
                return "checkmark.shield"
            }
        } else {
            return "xmark.shield"
        }
    }
    
    private var membershipColor: Color {
        if membershipService.isLoading {
            return .gray
        }
        
        guard let membership = membershipService.membershipStatus else {
            return .red
        }
        
        if membership.isActive {
            if let days = membership.daysRemaining {
                if days <= 7 {
                    return .orange
                } else if days <= 30 {
                    return .yellow
                } else {
                    return .green
                }
            } else {
                return .green
            }
        } else {
            return .red
        }
    }
    
    private var membershipStatusText: String {
        if membershipService.isLoading {
            return "Loading..."
        }
        
        guard let membership = membershipService.membershipStatus else {
            return "Error"
        }
        
        return membership.statusText
    }
}

// MARK: - Supporting Views

struct MembershipContent: View {
    let membership: MembershipStatus
    @ObservedObject var membershipService: MembershipService
    let themeManager: ThemeManager
    
    private var accessibilityMembershipInfo: String {
        var info = "Membership: \(membership.membershipDisplayName)."
        
        if membership.isActive {
            if let days = membership.daysRemaining {
                if days > 0 {
                    info += " \(days) days remaining."
                } else {
                    info += " Expires today."
                }
            } else {
                info += " No expiration date."
            }
        } else {
            info += " Membership expired."
        }
        
        return info
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Membership info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(membership.membershipDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    if membership.isActive {
                        if let days = membership.daysRemaining {
                            if days > 0 {
                                Text("\(days) days remaining")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            } else {
                                Text("Expires today")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                            }
                        } else {
                            Text("No expiration")
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                    } else {
                        Text("Membership expired")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityMembershipInfo)
                
                Spacer()
                
                // Action button
                if !membership.isActive || (membership.daysRemaining != nil && membership.daysRemaining! <= 30) {
                    Button(action: {
                        // TODO: Navigate to renewal/purchase
                        print("Navigate to membership renewal")
                    }) {
                        Text(membership.isActive ? "Renew" : "Activate")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .cornerRadius(8)
                    }
                    .accessibilityLabel(membership.isActive ? "Renew membership" : "Activate membership")
                    .accessibilityHint("Double tap to \(membership.isActive ? "renew" : "activate") your membership")
                    .accessibilityAddTraits(.isButton)
                }
            }
            
            // Progress bar for active memberships with expiration
            if membership.isActive && membership.daysRemaining != nil {
                MembershipProgressBar(
                    daysRemaining: membership.daysRemaining!,
                    totalDays: calculateTotalDays(from: membership),
                    color: progressBarColor
                )
            }
        }
    }
    
    private var progressBarColor: Color {
        guard let days = membership.daysRemaining else { return .green }
        if days <= 7 {
            return .red
        } else if days <= 30 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func calculateTotalDays(from membership: MembershipStatus) -> Int {
        // Si tenemos información de días restantes, asumimos un período típico
        // Esto es una aproximación, en un caso real vendría del backend
        guard let daysRemaining = membership.daysRemaining else { return 0 }
        
        // Aproximación basada en tipos comunes de membresía
        switch membership.membershipType.lowercased() {
        case "monthly", "basic":
            return max(30, daysRemaining)
        case "quarterly":
            return max(90, daysRemaining)
        case "yearly", "annual", "premium", "vip":
            return max(365, daysRemaining)
        default:
            // Fallback: asumir que está a mitad del período
            return daysRemaining * 2
        }
    }
}

struct MembershipProgressBar: View {
    let daysRemaining: Int
    let totalDays: Int
    let color: Color
    
    private var progress: Double {
        guard totalDays > 0 else { return 0 }
        return max(0, min(1, Double(daysRemaining) / Double(totalDays)))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Days Remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(daysRemaining)/\(totalDays)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    // Progress
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 4)
        }
    }
}

struct MembershipSkeletonContent: View {
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 120, height: 16)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 80, height: 14)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 60, height: 28)
                    .cornerRadius(8)
            }
            
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 4)
                .cornerRadius(2)
        }
        .redacted(reason: .placeholder)
    }
}

struct MembershipErrorContent: View {
    @ObservedObject var membershipService: MembershipService
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                
                Text("Unable to load membership status")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                
                Spacer()
                
                Button("Retry") {
                    Task {
                        await membershipService.getMyMembershipStatus()
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
        }
    }
}

#Preview {
    MembershipStatusWidget(
        membershipService: MembershipService.shared,
        themeManager: ThemeManager()
    )
}