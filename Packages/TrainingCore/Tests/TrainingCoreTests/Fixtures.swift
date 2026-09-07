//
//  Fixtures.swift
//  TrainingCoreTests
//
//  Carga los fixtures JSON del contrato.
//
//  Los ficheros viven en `Gym_API/Gym_API/Resources/TrainingFixtures/` (recursos del target de
//  la app) y NO se duplican aquí: son los mismos que usarán las previews de WP4, así que si el
//  contrato cambia, cambia en un solo sitio y estos tests se enteran. Se localizan subiendo
//  desde `#filePath`, que el compilador resuelve a la ruta real de este fichero.
//

import Foundation
import TrainingCore

enum Fixtures {

    /// `<repo>/Gym_API/Resources/TrainingFixtures`
    static let directory: URL = {
        // Este fichero está en <repo>/Packages/TrainingCore/Tests/TrainingCoreTests/Fixtures.swift
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }  // -> <repo>
        return url
            .appendingPathComponent("Gym_API")
            .appendingPathComponent("Resources")
            .appendingPathComponent("TrainingFixtures")
    }()

    static func data(_ name: String) throws -> Data {
        let url = directory.appendingPathComponent("\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FixtureError.missing(url.path)
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try TrainingJSON.decoder().decode(type, from: data(name))
    }

    enum FixtureError: Error, CustomStringConvertible {
        case missing(String)

        var description: String {
            switch self {
            case .missing(let path): return "Fixture no encontrado: \(path)"
            }
        }
    }
}
