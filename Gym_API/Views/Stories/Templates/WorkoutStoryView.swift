//
//  WorkoutStoryView.swift
//  Gym_API
//
//  Created on November 2024
//

import SwiftUI

struct WorkoutStoryView: View {
    let workoutData: WorkoutData?

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "1A1A2E") ?? Color.black,
                    (Color(hex: "D93333") ?? Color.red).opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 50))
                        .foregroundColor(.white)

                    Text("WORKOUT COMPLETADO")
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .tracking(2)
                }
                .padding(.top, 50)

                // Main exercise info
                if let data = workoutData {
                    VStack(spacing: 20) {
                        // Exercise name
                        Text(data.exercise.uppercased())
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // Main metrics
                        HStack(spacing: 30) {
                            if let weight = data.weight {
                                WorkoutMetricCard(
                                    value: String(format: "%.0f", weight),
                                    unit: data.weightUnit ?? "kg",
                                    label: "PESO"
                                )
                            }

                            if let reps = data.reps {
                                WorkoutMetricCard(
                                    value: "\(reps)",
                                    unit: "reps",
                                    label: "REPS"
                                )
                            }

                            if let sets = data.sets {
                                WorkoutMetricCard(
                                    value: "\(sets)",
                                    unit: "sets",
                                    label: "SETS"
                                )
                            }
                        }

                        // Additional metrics
                        if let duration = data.durationMinutes {
                            HStack(spacing: 8) {
                                Image(systemName: "timer")
                                    .foregroundColor(.white)
                                Text("\(duration) minutos")
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                        }

                        // Notes if available
                        if let notes = data.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.callout)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.white.opacity(0.1))
                                )
                                .padding(.horizontal, 20)
                        }
                    }
                }

                Spacer()

                // Motivational footer
                VStack(spacing: 8) {
                    Text("💪 BEAST MODE ACTIVATED")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.8))
                        .tracking(1)

                    // Animated fire emojis
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Text("🔥")
                                .font(.title2)
                                .rotationEffect(.degrees(Double.random(in: -10...10)))
                                .animation(
                                    .easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.1),
                                    value: UUID()
                                )
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Metric Card Component
struct WorkoutMetricCard: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.white)

                Text(unit)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }

            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.6))
                .tracking(1)
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.15))
        )
    }
}

// MARK: - Preview
struct WorkoutStoryView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutStoryView(
            workoutData: WorkoutData(
                exercise: "Bench Press",
                weight: 100,
                weightUnit: "kg",
                reps: 10,
                sets: 4,
                durationMinutes: 45,
                caloriesBurned: 300,
                notes: "Felt strong today!"
            )
        )
    }
}