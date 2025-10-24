//
//  AppErrors.swift
//  Gym_API
//
//  Definición centralizada de errores específicos de la aplicación
//  Created as part of error handling optimization phase
//

import Foundation

// MARK: - Base Error Protocol
protocol AppError: LocalizedError {
    var code: String { get }
    var userMessage: String { get }
    var technicalMessage: String { get }
    var isRecoverable: Bool { get }
    var suggestedAction: ErrorAction? { get }
    var underlyingError: Error? { get }
}

// MARK: - Error Actions
enum ErrorAction {
    case retry
    case login
    case updateApp
    case checkConnection
    case contactSupport
    case clearCache
    case selectGym
    case upgradeSubscription

    var localizedDescription: String {
        switch self {
        case .retry:
            return "Intentar de nuevo"
        case .login:
            return "Iniciar sesión nuevamente"
        case .updateApp:
            return "Actualizar la aplicación"
        case .checkConnection:
            return "Verificar conexión a internet"
        case .contactSupport:
            return "Contactar soporte"
        case .clearCache:
            return "Limpiar caché"
        case .selectGym:
            return "Seleccionar gimnasio"
        case .upgradeSubscription:
            return "Actualizar suscripción"
        }
    }
}

// MARK: - Network Errors
enum NetworkError: AppError {
    case noConnection
    case timeout(TimeInterval)
    case invalidURL(String)
    case httpError(statusCode: Int, response: Data?)
    case decodingError(DecodingError)
    case encodingError(EncodingError)
    case sslError
    case serverError(message: String?)
    case rateLimited(retryAfter: TimeInterval?)
    case cancelled

    var code: String {
        switch self {
        case .noConnection: return "NET_001"
        case .timeout: return "NET_002"
        case .invalidURL: return "NET_003"
        case .httpError: return "NET_004"
        case .decodingError: return "NET_005"
        case .encodingError: return "NET_006"
        case .sslError: return "NET_007"
        case .serverError: return "NET_008"
        case .rateLimited: return "NET_009"
        case .cancelled: return "NET_010"
        }
    }

    var userMessage: String {
        switch self {
        case .noConnection:
            return "No hay conexión a internet disponible"
        case .timeout:
            return "La solicitud tardó demasiado tiempo"
        case .invalidURL:
            return "La dirección solicitada no es válida"
        case .httpError(let statusCode, _):
            return httpErrorMessage(for: statusCode)
        case .decodingError:
            return "Error al procesar la respuesta del servidor"
        case .encodingError:
            return "Error al preparar la solicitud"
        case .sslError:
            return "Error de seguridad en la conexión"
        case .serverError(let message):
            return message ?? "Error en el servidor"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Demasiadas solicitudes. Intenta en \(Int(retryAfter)) segundos"
            }
            return "Demasiadas solicitudes. Intenta más tarde"
        case .cancelled:
            return "Operación cancelada"
        }
    }

    var technicalMessage: String {
        switch self {
        case .noConnection:
            return "No network connection available"
        case .timeout(let interval):
            return "Request timeout after \(interval) seconds"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .httpError(let statusCode, let response):
            var message = "HTTP Error \(statusCode)"
            if let data = response, let body = String(data: data, encoding: .utf8) {
                message += " - Response: \(body.prefix(200))"
            }
            return message
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .sslError:
            return "SSL/TLS connection error"
        case .serverError(let message):
            return "Server error: \(message ?? "Unknown")"
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after: \(retryAfter ?? 0) seconds"
        case .cancelled:
            return "Request cancelled"
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .noConnection, .timeout, .rateLimited, .serverError:
            return true
        case .httpError(let statusCode, _):
            return statusCode >= 500 || statusCode == 429
        case .cancelled:
            return false
        default:
            return false
        }
    }

    var suggestedAction: ErrorAction? {
        switch self {
        case .noConnection:
            return .checkConnection
        case .timeout, .serverError:
            return .retry
        case .httpError(let statusCode, _):
            if statusCode == 401 { return .login }
            if statusCode >= 500 { return .retry }
            if statusCode == 429 { return .retry }
            return nil
        case .rateLimited:
            return .retry
        default:
            return nil
        }
    }

    var underlyingError: Error? {
        switch self {
        case .decodingError(let error):
            return error
        case .encodingError(let error):
            return error
        default:
            return nil
        }
    }

    var errorDescription: String? {
        return userMessage
    }

    private func httpErrorMessage(for statusCode: Int) -> String {
        switch statusCode {
        case 400: return "Solicitud inválida"
        case 401: return "No autorizado. Por favor inicia sesión"
        case 403: return "No tienes permisos para esta acción"
        case 404: return "Recurso no encontrado"
        case 429: return "Demasiadas solicitudes"
        case 500...599: return "Error del servidor. Intenta más tarde"
        default: return "Error de conexión (Código: \(statusCode))"
        }
    }
}

// MARK: - Authentication Errors
enum AuthenticationError: AppError {
    case notAuthenticated
    case tokenExpired
    case tokenRefreshFailed(Error?)
    case invalidCredentials
    case userNotFound
    case emailNotVerified
    case accountLocked
    case invalidToken
    case missingToken
    case biometricFailed
    case biometricNotAvailable
    case firstLoginRequired

    var code: String {
        switch self {
        case .notAuthenticated: return "AUTH_001"
        case .tokenExpired: return "AUTH_002"
        case .tokenRefreshFailed: return "AUTH_003"
        case .invalidCredentials: return "AUTH_004"
        case .userNotFound: return "AUTH_005"
        case .emailNotVerified: return "AUTH_006"
        case .accountLocked: return "AUTH_007"
        case .invalidToken: return "AUTH_008"
        case .missingToken: return "AUTH_009"
        case .biometricFailed: return "AUTH_010"
        case .biometricNotAvailable: return "AUTH_011"
        case .firstLoginRequired: return "AUTH_012"
        }
    }

    var userMessage: String {
        switch self {
        case .notAuthenticated:
            return "Debes iniciar sesión para continuar"
        case .tokenExpired:
            return "Tu sesión ha expirado"
        case .tokenRefreshFailed:
            return "Error al renovar la sesión"
        case .invalidCredentials:
            return "Usuario o contraseña incorrectos"
        case .userNotFound:
            return "Usuario no encontrado"
        case .emailNotVerified:
            return "Debes verificar tu correo electrónico"
        case .accountLocked:
            return "Tu cuenta ha sido bloqueada"
        case .invalidToken:
            return "Token de autenticación inválido"
        case .missingToken:
            return "Token de autenticación no encontrado"
        case .biometricFailed:
            return "Autenticación biométrica fallida"
        case .biometricNotAvailable:
            return "Autenticación biométrica no disponible"
        case .firstLoginRequired:
            return "Completa tu primer inicio de sesión"
        }
    }

    var technicalMessage: String {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .tokenExpired:
            return "Access token expired"
        case .tokenRefreshFailed(let error):
            return "Token refresh failed: \(error?.localizedDescription ?? "Unknown")"
        case .invalidCredentials:
            return "Invalid username or password"
        case .userNotFound:
            return "User account not found"
        case .emailNotVerified:
            return "Email verification required"
        case .accountLocked:
            return "Account locked due to security reasons"
        case .invalidToken:
            return "Invalid authentication token"
        case .missingToken:
            return "Missing authentication token"
        case .biometricFailed:
            return "Biometric authentication failed"
        case .biometricNotAvailable:
            return "Biometric authentication not available on device"
        case .firstLoginRequired:
            return "First login flow required"
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .tokenExpired, .tokenRefreshFailed:
            return true
        case .notAuthenticated, .invalidCredentials, .firstLoginRequired:
            return true
        default:
            return false
        }
    }

    var suggestedAction: ErrorAction? {
        switch self {
        case .notAuthenticated, .tokenExpired, .invalidCredentials, .firstLoginRequired:
            return .login
        case .accountLocked, .emailNotVerified:
            return .contactSupport
        default:
            return nil
        }
    }

    var underlyingError: Error? {
        switch self {
        case .tokenRefreshFailed(let error):
            return error
        default:
            return nil
        }
    }

    var errorDescription: String? {
        return userMessage
    }
}

// MARK: - Database Errors
enum DatabaseError: AppError {
    case connectionFailed
    case queryFailed(String)
    case dataCorrupted
    case migrationFailed
    case diskFull
    case cacheExpired
    case notFound(entity: String, id: String?)

    var code: String {
        switch self {
        case .connectionFailed: return "DB_001"
        case .queryFailed: return "DB_002"
        case .dataCorrupted: return "DB_003"
        case .migrationFailed: return "DB_004"
        case .diskFull: return "DB_005"
        case .cacheExpired: return "DB_006"
        case .notFound: return "DB_007"
        }
    }

    var userMessage: String {
        switch self {
        case .connectionFailed:
            return "Error al acceder a los datos locales"
        case .queryFailed:
            return "Error al buscar información"
        case .dataCorrupted:
            return "Los datos están corruptos"
        case .migrationFailed:
            return "Error al actualizar la base de datos"
        case .diskFull:
            return "Espacio de almacenamiento insuficiente"
        case .cacheExpired:
            return "Los datos han expirado"
        case .notFound(let entity, _):
            return "\(entity) no encontrado"
        }
    }

    var technicalMessage: String {
        switch self {
        case .connectionFailed:
            return "Database connection failed"
        case .queryFailed(let query):
            return "Query failed: \(query)"
        case .dataCorrupted:
            return "Data corruption detected"
        case .migrationFailed:
            return "Database migration failed"
        case .diskFull:
            return "Insufficient disk space"
        case .cacheExpired:
            return "Cache data expired"
        case .notFound(let entity, let id):
            return "\(entity) not found" + (id != nil ? " with id: \(id!)" : "")
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .cacheExpired, .notFound:
            return true
        case .connectionFailed:
            return true
        default:
            return false
        }
    }

    var suggestedAction: ErrorAction? {
        switch self {
        case .diskFull:
            return .clearCache
        case .dataCorrupted, .migrationFailed:
            return .contactSupport
        case .cacheExpired:
            return .retry
        default:
            return nil
        }
    }

    var underlyingError: Error? {
        return nil
    }

    var errorDescription: String? {
        return userMessage
    }
}

// MARK: - Business Logic Errors
enum BusinessError: AppError {
    case gymNotSelected
    case membershipExpired
    case membershipInactive
    case insufficientPermissions
    case quotaExceeded(resource: String)
    case invalidOperation(reason: String)
    case bookingConflict
    case classFullyBooked
    case pastEventModification
    case duplicateEntry(entity: String)

    var code: String {
        switch self {
        case .gymNotSelected: return "BIZ_001"
        case .membershipExpired: return "BIZ_002"
        case .membershipInactive: return "BIZ_003"
        case .insufficientPermissions: return "BIZ_004"
        case .quotaExceeded: return "BIZ_005"
        case .invalidOperation: return "BIZ_006"
        case .bookingConflict: return "BIZ_007"
        case .classFullyBooked: return "BIZ_008"
        case .pastEventModification: return "BIZ_009"
        case .duplicateEntry: return "BIZ_010"
        }
    }

    var userMessage: String {
        switch self {
        case .gymNotSelected:
            return "Por favor selecciona un gimnasio"
        case .membershipExpired:
            return "Tu membresía ha expirado"
        case .membershipInactive:
            return "Tu membresía no está activa"
        case .insufficientPermissions:
            return "No tienes permisos para esta acción"
        case .quotaExceeded(let resource):
            return "Has excedido el límite de \(resource)"
        case .invalidOperation(let reason):
            return reason
        case .bookingConflict:
            return "Ya tienes una reserva en este horario"
        case .classFullyBooked:
            return "Esta clase está completa"
        case .pastEventModification:
            return "No se pueden modificar eventos pasados"
        case .duplicateEntry(let entity):
            return "\(entity) ya existe"
        }
    }

    var technicalMessage: String {
        switch self {
        case .gymNotSelected:
            return "No gym selected in current context"
        case .membershipExpired:
            return "User membership has expired"
        case .membershipInactive:
            return "User membership is inactive"
        case .insufficientPermissions:
            return "Insufficient permissions for operation"
        case .quotaExceeded(let resource):
            return "Quota exceeded for resource: \(resource)"
        case .invalidOperation(let reason):
            return "Invalid operation: \(reason)"
        case .bookingConflict:
            return "Booking conflict detected"
        case .classFullyBooked:
            return "Class has reached maximum capacity"
        case .pastEventModification:
            return "Cannot modify past events"
        case .duplicateEntry(let entity):
            return "Duplicate \(entity) entry"
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .gymNotSelected, .bookingConflict:
            return true
        case .membershipExpired, .membershipInactive:
            return true
        default:
            return false
        }
    }

    var suggestedAction: ErrorAction? {
        switch self {
        case .gymNotSelected:
            return .selectGym
        case .membershipExpired, .membershipInactive:
            return .upgradeSubscription
        case .insufficientPermissions:
            return .contactSupport
        default:
            return nil
        }
    }

    var underlyingError: Error? {
        return nil
    }

    var errorDescription: String? {
        return userMessage
    }
}

// MARK: - Validation Errors
enum ValidationError: AppError {
    case missingRequiredField(field: String)
    case invalidFormat(field: String, expectedFormat: String)
    case valueTooShort(field: String, minLength: Int)
    case valueTooLong(field: String, maxLength: Int)
    case invalidEmail
    case invalidPhoneNumber
    case invalidDate
    case outOfRange(field: String, min: Any, max: Any)
    case patternMismatch(field: String, pattern: String)

    var code: String {
        switch self {
        case .missingRequiredField: return "VAL_001"
        case .invalidFormat: return "VAL_002"
        case .valueTooShort: return "VAL_003"
        case .valueTooLong: return "VAL_004"
        case .invalidEmail: return "VAL_005"
        case .invalidPhoneNumber: return "VAL_006"
        case .invalidDate: return "VAL_007"
        case .outOfRange: return "VAL_008"
        case .patternMismatch: return "VAL_009"
        }
    }

    var userMessage: String {
        switch self {
        case .missingRequiredField(let field):
            return "\(field) es requerido"
        case .invalidFormat(let field, let format):
            return "\(field) debe tener el formato: \(format)"
        case .valueTooShort(let field, let minLength):
            return "\(field) debe tener al menos \(minLength) caracteres"
        case .valueTooLong(let field, let maxLength):
            return "\(field) no puede exceder \(maxLength) caracteres"
        case .invalidEmail:
            return "Correo electrónico inválido"
        case .invalidPhoneNumber:
            return "Número de teléfono inválido"
        case .invalidDate:
            return "Fecha inválida"
        case .outOfRange(let field, let min, let max):
            return "\(field) debe estar entre \(min) y \(max)"
        case .patternMismatch(let field, _):
            return "\(field) tiene un formato inválido"
        }
    }

    var technicalMessage: String {
        switch self {
        case .missingRequiredField(let field):
            return "Required field missing: \(field)"
        case .invalidFormat(let field, let format):
            return "Invalid format for \(field). Expected: \(format)"
        case .valueTooShort(let field, let minLength):
            return "\(field) length < \(minLength)"
        case .valueTooLong(let field, let maxLength):
            return "\(field) length > \(maxLength)"
        case .invalidEmail:
            return "Invalid email format"
        case .invalidPhoneNumber:
            return "Invalid phone number format"
        case .invalidDate:
            return "Invalid date format"
        case .outOfRange(let field, let min, let max):
            return "\(field) out of range [\(min), \(max)]"
        case .patternMismatch(let field, let pattern):
            return "\(field) doesn't match pattern: \(pattern)"
        }
    }

    var isRecoverable: Bool {
        return true // All validation errors are recoverable by fixing input
    }

    var suggestedAction: ErrorAction? {
        return nil // User needs to fix input
    }

    var underlyingError: Error? {
        return nil
    }

    var errorDescription: String? {
        return userMessage
    }
}

// MARK: - Error Handler
class ErrorHandler {
    static let shared = ErrorHandler()

    private init() {}

    func handle(_ error: Error, context: String? = nil) -> (title: String, message: String, action: ErrorAction?) {
        // Log the error
        Task { @MainActor in
            Logger.shared.logError(error, context: context, category: .general)
        }

        // Convert to AppError if possible
        if let appError = error as? AppError {
            return (
                title: "Error",
                message: appError.userMessage,
                action: appError.suggestedAction
            )
        }

        // Handle system errors
        if let urlError = error as? URLError {
            return handleURLError(urlError)
        }

        // Default error
        return (
            title: "Error",
            message: "Ha ocurrido un error inesperado",
            action: .retry
        )
    }

    private func handleURLError(_ error: URLError) -> (title: String, message: String, action: ErrorAction?) {
        switch error.code {
        case .notConnectedToInternet:
            return ("Sin Conexión", "No hay conexión a internet", .checkConnection)
        case .timedOut:
            return ("Tiempo Agotado", "La solicitud tardó demasiado", .retry)
        case .cancelled:
            return ("Cancelado", "La operación fue cancelada", nil)
        case .cannotFindHost, .cannotConnectToHost:
            return ("Error de Conexión", "No se puede conectar al servidor", .retry)
        default:
            return ("Error de Red", "Error de conexión: \(error.code.rawValue)", .retry)
        }
    }
}