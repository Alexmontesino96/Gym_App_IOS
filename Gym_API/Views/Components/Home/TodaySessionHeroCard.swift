import SwiftUI

// MARK: - Today Session Hero Card
/// Large accent-gradient card showing the user's next reserved class
struct TodaySessionHeroCard: View {
    let gymClass: GymClass
    /// Asistencia por QR. Opcional a proposito: solo tiene sentido el dia de la sesion, y en la
    /// home del gimnasio no habia nada detras (su cuerpo era un haptico y un TODO).
    var onCheckInTap: (() -> Void)? = nil
    let onCardTap: () -> Void

    // MARK: - Contexto opcional (cliente de entrenador personal)
    //
    // El diseño de entrenador personal pide en este héroe el sitio, una línea de contexto del
    // programa y la identidad del coach. Todo eso entra por aquí y por defecto está vacío, así
    // que la home del gimnasio sigue pintando exactamente lo mismo que antes.

    /// Sala o sitio de la sesión. Sale de `ClassSession.room`, que ya viajaba y no se pintaba.
    var place: String? = nil
    /// Línea libre bajo la hora. Sale de `ClassSession.notes`: es donde el entrenador puede
    /// escribir hoy lo que el diseño llama «Bloque 2 · Semana 3».
    var contextNote: String? = nil
    /// Etiqueta bajo el nombre. «Instructor» en un gimnasio, «Your coach» en un espacio 1:1.
    var roleLabel: String = "Instructor"
    /// Nombre y siglas de quien imparte, si se conocen por otra vía que el propio `gymClass`.
    var personName: String? = nil
    var personInitials: String? = nil
    /// Foto de quien imparte, si se conoce. `CoachSummary.pictureURL` ya la trae cargada y aqui
    /// solo se pintaban las iniciales, asi que la misma persona salia con dos caras distintas en
    /// la misma pantalla: siglas en el heroe y foto en la tarjeta de justo debajo.
    var personPictureURL: String? = nil

    /// Accion secundaria del heroe. La usa el modulo de entrenamiento para «View plan» (UX §2);
    /// por defecto no existe, asi que la home del gimnasio sigue pintando exactamente lo mismo.
    var secondaryActionTitle: String? = nil
    var onSecondaryAction: (() -> Void)? = nil

    private var displayedPersonName: String { personName ?? gymClass.instructor }

    @EnvironmentObject var themeManager: ThemeManager

    // El acento del TEMA, no dos hex cableados. Esta tarjeta declaraba `themeManager` y no lo
    // leia nunca, asi que era el unico bloque grande de la home que ignoraba el color que el
    // usuario habia elegido: la app pintaba rojo por todas partes y el heroe seguia lima.
    private var accentColor: Color { Color.dynamicAccent(theme: themeManager.currentTheme) }

    /// Segunda parada del degradado, derivada del acento en vez de un verde fijo que no pegaba
    /// con ningun acento salvo el lima.
    private var accentSecondary: Color { accentColor.opacity(0.72) }

    /// Casi negro o blanco, la que mas contraste da sobre el acento elegido. Con `accentInk`
    /// fijo, un acento oscuro como el teal `#00827E` dejaba el heroe ilegible.
    private var inkOnAccent: Color {
        ThemeManager.accentInkForCurrentAccent(theme: themeManager.currentTheme)
    }

    private var durationMinutes: Int {
        let interval = gymClass.endTime.timeIntervalSince(gymClass.startTime)
        return max(Int(interval / 60), 1)
    }

    // MARK: - El dia y la hora, en la zona del espacio
    //
    // La hora que vale es la que dijo el entrenador al crear la sesion, no la del telefono de
    // quien mira. `GymClass.gymTimezone` viaja desde `time_info.gym_timezone` y hasta ahora no
    // lo usaba nadie aqui: un cliente en otra zona veia una hora distinta a la de su coach.

    private var gymTimeZone: TimeZone {
        gymClass.gymTimezone.flatMap(TimeZone.init(identifier:)) ?? .current
    }

    private var gymCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = gymTimeZone
        return calendar
    }

    /// Cabecera. Antes era el literal «YOUR SESSION TODAY» para cualquier sesion futura, asi que
    /// una del miercoles se anunciaba como de hoy.
    private var dayHeadline: String {
        if gymCalendar.isDateInToday(gymClass.startTime) { return "YOUR SESSION TODAY" }
        if gymCalendar.isDateInTomorrow(gymClass.startTime) { return "YOUR SESSION TOMORROW" }
        let formatter = DateFormatter.localized(template: "EEEE")
        formatter.timeZone = gymTimeZone
        return "YOUR SESSION \(formatter.string(from: gymClass.startTime).uppercased())"
    }

    /// El QR de asistencia solo tiene sentido el dia de la sesion.
    private var isToday: Bool {
        gymCalendar.isDateInToday(gymClass.startTime)
    }

    /// Reloj de 12 o de 24 horas según el país, no "HH:mm" fijo: es la hora más visible
    /// de toda la app y en Estados Unidos "18:30" se lee mal.
    private var timeRange: String {
        let formatter = DateFormatter.localized(template: "jmm")
        formatter.timeZone = gymTimeZone
        return "\(formatter.string(from: gymClass.startTime))–\(formatter.string(from: gymClass.endTime))"
    }

    private var initialsBadge: some View {
        Text(instructorInitials)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(accentColor)
            .frame(width: 32, height: 32)
            .background(Color.black.opacity(0.85))
            .clipShape(Circle())
    }

    private var instructorInitials: String {
        if let personInitials, !personInitials.isEmpty { return personInitials }
        let parts = displayedPersonName.components(separatedBy: " ")
        let initials = parts.prefix(2).compactMap { $0.first }.map { String($0) }
        return initials.joined().uppercased()
    }

    var body: some View {
        Button(action: onCardTap) {
            ZStack(alignment: .topTrailing) {
                // Decorative arc
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.black.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(x: 60, y: -60)

                // Content
                VStack(spacing: 16) {
                    // Top row: class info + duration badge
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dayHeadline)
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.1)
                                .opacity(0.7)

                            Text(gymClass.name)
                                .font(.system(size: 28, weight: .bold))
                                .tracking(-0.8)
                                .lineLimit(2)

                            // Time, and place when the session has one
                            HStack(spacing: 10) {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 14))
                                    Text(timeRange)
                                }

                                if let place, !place.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.system(size: 13))
                                        Text(place)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .font(.system(size: 13, weight: .medium))
                            .opacity(0.85)
                            .padding(.top, 4)

                            if let contextNote, !contextNote.isEmpty {
                                Text(contextNote)
                                    .font(.system(size: 12, weight: .medium))
                                    .opacity(0.72)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        // Duration badge
                        VStack(spacing: 0) {
                            Text("\(durationMinutes)")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                            Text("MIN")
                                .font(.system(size: 9, weight: .semibold))
                                .opacity(0.7)
                        }
                        .foregroundColor(accentColor)
                        .frame(width: 56, height: 56)
                        .background(Color.black.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Bottom row: instructor + check-in
                    HStack {
                        // Instructor
                        HStack(spacing: 8) {
                            if let personPictureURL, !personPictureURL.isEmpty {
                                CustomImageView(url: personPictureURL, cacheKey: personPictureURL, size: 32) {
                                    AnyView(initialsBadge)
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                            } else {
                                initialsBadge
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(displayedPersonName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineHeight(1.1)
                                    .lineLimit(1)
                                Text(roleLabel)
                                    .font(.system(size: 11))
                                    .opacity(0.65)
                            }
                        }

                        Spacer()

                        // Accion secundaria («View plan» del modulo de entrenamiento)
                        if let secondaryActionTitle, let onSecondaryAction {
                            Button(action: onSecondaryAction) {
                                HStack(spacing: 4) {
                                    Text(secondaryActionTitle)
                                        .font(.system(size: 13, weight: .semibold))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(accentColor)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(Color.black.opacity(0.85))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(secondaryActionTitle)
                        }

                        // Check-in pill
                        // Solo el dia de la sesion, y solo si hay algo detras. Antes salia
                        // siempre: en la home del gimnasio no hacia nada, y en la del cliente
                        // ofrecia registrar asistencia a una sesion de dos dias despues.
                        if isToday, let onCheckInTap {
                        Button(action: onCheckInTap) {
                            HStack(spacing: 6) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 16))
                                // «I'M HERE» y no «CHECK-IN»: a un dedo de distancia estaba la
                                // accion rapida de check-in semanal, que es otra cosa (el peso y
                                // las tres escalas). Una palabra para dos funciones distintas en
                                // la misma pantalla.
                                Text("I'M HERE")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.85))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .foregroundColor(inkOnAccent)
            .background(
                LinearGradient(
                    colors: [accentColor, accentSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Line Height Modifier
private extension View {
    func lineHeight(_ multiplier: CGFloat) -> some View {
        self.lineSpacing((multiplier - 1) * 12)
    }
}
