import SwiftUI

struct SocialEmptyStateView: View {
    enum FeedType { case timeline, explore, location }

    let feedType: FeedType
    let theme: ThemeManager.AppTheme
    let onCreatePost: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 56, weight: .regular))
                .foregroundColor(.gray.opacity(0.6))

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: theme))

            Text(message)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal, 24)

            Button(action: onCreatePost) {
                Text("Crear Post")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.dynamicAccent(theme: theme))
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        switch feedType {
        case .timeline: return "Aún no hay publicaciones"
        case .explore: return "Nada para explorar aún"
        case .location: return "No hay posts en esta ubicación"
        }
    }

    private var message: String {
        switch feedType {
        case .timeline: return "Comparte el primer post con tu comunidad del gym."
        case .explore: return "Cuando haya contenido popular aparecerá aquí."
        case .location: return "Sé el primero en compartir algo desde esta zona."
        }
    }

    private var iconName: String {
        switch feedType {
        case .timeline: return "photo.on.rectangle.angled"
        case .explore: return "sparkles"
        case .location: return "mappin.and.ellipse"
        }
    }
}

