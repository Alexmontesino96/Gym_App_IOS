import Foundation

// MARK: - Paged Response

/// Respuesta paginada genérica de la API
/// Maneja diferentes tipos de contenido (posts, comentarios, likes) con paginación consistente
struct PagedResponse<T: Codable>: Codable {
    // Información de paginación (opcionales porque no todos los endpoints los devuelven)
    let limit: Int?
    let offset: Int?
    let hasMore: Bool?
    let nextOffset: Int?

    // Total de items (puede variar el nombre según el endpoint)
    let total: Int?
    let totalPosts: Int? // Usado en feeds

    // Contenido (varía según el endpoint)
    let posts: [T]?
    let comments: [T]?
    let likes: [T]?

    // Metadatos adicionales para feeds
    let feedType: String?
    let lastUpdate: String?

    enum CodingKeys: String, CodingKey {
        case limit, offset
        case hasMore = "has_more"
        case nextOffset = "next_offset"
        case total
        case totalPosts = "total_posts"
        case posts, comments, likes
        case feedType = "feed_type"
        case lastUpdate = "last_update"
    }

    /// Total efectivo de items considerando diferentes nombres de campo
    var effectiveTotal: Int {
        totalPosts ?? total ?? 0
    }

    /// Items extraídos según el tipo de contenido
    var items: [T] {
        posts ?? comments ?? likes ?? []
    }

    /// Indica si hay más páginas disponibles
    var hasMorePages: Bool {
        hasMore ?? false
    }

    /// Offset para la siguiente página
    var effectiveNextOffset: Int {
        nextOffset ?? ((offset ?? 0) + items.count)
    }
}

// MARK: - Feed Metadata

/// Metadatos adicionales para feeds timeline/explore
struct FeedMetadata: Codable {
    let feedType: String
    let lastUpdate: String?

    enum CodingKeys: String, CodingKey {
        case feedType = "feed_type"
        case lastUpdate = "last_update"
    }
}

// MARK: - Pagination State

/// Estado de paginación para ViewModels
struct PaginationState {
    var limit: Int = 20
    var offset: Int = 0
    var hasMore: Bool = true
    var isLoading: Bool = false

    /// Indica si se puede cargar más contenido
    var canLoadMore: Bool {
        hasMore && !isLoading
    }

    /// Resetea el estado de paginación
    mutating func reset() {
        offset = 0
        hasMore = true
        isLoading = false
    }

    /// Actualiza el estado con una respuesta paginada
    mutating func update<T>(with response: PagedResponse<T>) {
        hasMore = response.hasMore ?? false
        offset = response.effectiveNextOffset
        isLoading = false
    }

    /// Marca como cargando
    mutating func startLoading() {
        isLoading = true
    }

    /// Marca como no cargando (por error u otra razón)
    mutating func stopLoading() {
        isLoading = false
    }
}
