// swift-tools-version: 5.9
//
//  Package.swift
//  TrainingCore
//
//  Lógica pura del módulo de entrenamiento: modelos del contrato, 1RM, calendario de semanas,
//  máquina de estados de una sesión, cronómetro de descanso y outbox.
//
//  El paquete NO importa UIKit ni SwiftUI a propósito: todo lo que vive aquí se puede probar
//  con `swift test` sin simulador, que es la razón por la que existe (plan §14, decisión 6).
//

import PackageDescription

let package = Package(
    name: "TrainingCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "TrainingCore", targets: ["TrainingCore"])
    ],
    targets: [
        .target(name: "TrainingCore"),
        .testTarget(name: "TrainingCoreTests", dependencies: ["TrainingCore"])
    ]
)
