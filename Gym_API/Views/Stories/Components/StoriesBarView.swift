import SwiftUI

/// Minimal Stories bar that matches FeedTabsView expected API
struct StoriesBarView: View {
    let userStories: [UserStoryGroup]
    let currentUserId: Int
    let currentUserAvatar: String?
    let onStoryTap: (UserStoryGroup) -> Void
    let onYourStoryTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                yourStoryButton

                ForEach(userStories, id: \.id) { group in
                    StoryAvatarCell(group: group, theme: themeManager.currentTheme)
                        .onTapGesture { onStoryTap(group) }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 100)
    }

    private var yourStoryButton: some View {
        let hasOwnStory = userStories.contains(where: { $0.userId == currentUserId && !$0.stories.isEmpty })

        return VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                // Ring
                if hasOwnStory {
                    Circle()
                        .stroke(StoryDesignTokens.instagramUnseenGradient, lineWidth: 3)
                        .frame(width: 68, height: 68)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 68, height: 68)
                }

                // Avatar
                Group {
                    if let urlStr = currentUserAvatar, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(Image(systemName: "person.fill").foregroundColor(.white))
                    }
                }

                if !hasOwnStory {
                    Circle()
                        .fill(StoryDesignTokens.instagramBlue)
                        .frame(width: 20, height: 20)
                        .overlay(Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundColor(.white))
                        .offset(x: 2, y: 2)
                }
            }

            Text(hasOwnStory ? "Tu historia" : "Agregar")
                .font(.caption)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
        .frame(width: 72)
        .onTapGesture { onYourStoryTap() }
    }
}

private struct StoryAvatarCell: View {
    let group: UserStoryGroup
    let theme: ThemeManager.AppTheme

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if group.hasUnseen {
                    Circle()
                        .stroke(StoryDesignTokens.instagramUnseenGradient, lineWidth: 3)
                        .frame(width: 68, height: 68)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 68, height: 68)
                }

                if let urlStr = group.userAvatar, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Circle().fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(Image(systemName: "person.fill").foregroundColor(.white))
                }
            }
            Text(group.userName)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(Color.dynamicText(theme: theme))
        }
        .frame(width: 72)
    }
}

