import SwiftUI

// MARK: - GitHub Logo

/// GitHub's Octocat mark as a SwiftUI Shape
struct GitHubLogo: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 16

        return Path { path in
            // GitHub logo path (simplified mark)
            path.move(to: CGPoint(x: 8 * scale, y: 0))
            path.addCurve(
                to: CGPoint(x: 0, y: 8 * scale),
                control1: CGPoint(x: 3.58 * scale, y: 0),
                control2: CGPoint(x: 0, y: 3.58 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 5.47 * scale, y: 15.9 * scale),
                control1: CGPoint(x: 0, y: 11.54 * scale),
                control2: CGPoint(x: 2.29 * scale, y: 14.73 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 6 * scale, y: 14.69 * scale),
                control1: CGPoint(x: 5.87 * scale, y: 15.97 * scale),
                control2: CGPoint(x: 6 * scale, y: 15.33 * scale)
            )
            path.addLine(to: CGPoint(x: 6 * scale, y: 13.39 * scale))
            path.addCurve(
                to: CGPoint(x: 2.34 * scale, y: 11.72 * scale),
                control1: CGPoint(x: 3.73 * scale, y: 13.87 * scale),
                control2: CGPoint(x: 2.34 * scale, y: 13.44 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 3.15 * scale, y: 9.86 * scale),
                control1: CGPoint(x: 2.34 * scale, y: 10.96 * scale),
                control2: CGPoint(x: 2.63 * scale, y: 10.31 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 3.22 * scale, y: 7.38 * scale),
                control1: CGPoint(x: 2.65 * scale, y: 9.1 * scale),
                control2: CGPoint(x: 2.68 * scale, y: 8.11 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 5.59 * scale, y: 8.16 * scale),
                control1: CGPoint(x: 4.15 * scale, y: 7.14 * scale),
                control2: CGPoint(x: 5.2 * scale, y: 7.42 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 8 * scale, y: 7.75 * scale),
                control1: CGPoint(x: 6.32 * scale, y: 7.89 * scale),
                control2: CGPoint(x: 7.15 * scale, y: 7.75 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 10.41 * scale, y: 8.16 * scale),
                control1: CGPoint(x: 8.85 * scale, y: 7.75 * scale),
                control2: CGPoint(x: 9.68 * scale, y: 7.89 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 12.78 * scale, y: 7.38 * scale),
                control1: CGPoint(x: 10.8 * scale, y: 7.42 * scale),
                control2: CGPoint(x: 11.85 * scale, y: 7.14 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 12.85 * scale, y: 9.86 * scale),
                control1: CGPoint(x: 13.32 * scale, y: 8.11 * scale),
                control2: CGPoint(x: 13.35 * scale, y: 9.1 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 13.66 * scale, y: 11.72 * scale),
                control1: CGPoint(x: 13.37 * scale, y: 10.31 * scale),
                control2: CGPoint(x: 13.66 * scale, y: 10.96 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 10 * scale, y: 13.39 * scale),
                control1: CGPoint(x: 13.66 * scale, y: 13.44 * scale),
                control2: CGPoint(x: 12.27 * scale, y: 13.87 * scale)
            )
            path.addLine(to: CGPoint(x: 10 * scale, y: 15.31 * scale))
            path.addCurve(
                to: CGPoint(x: 10.53 * scale, y: 15.9 * scale),
                control1: CGPoint(x: 10 * scale, y: 15.75 * scale),
                control2: CGPoint(x: 10.22 * scale, y: 15.98 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 16 * scale, y: 8 * scale),
                control1: CGPoint(x: 13.71 * scale, y: 14.73 * scale),
                control2: CGPoint(x: 16 * scale, y: 11.54 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 8 * scale, y: 0),
                control1: CGPoint(x: 16 * scale, y: 3.58 * scale),
                control2: CGPoint(x: 12.42 * scale, y: 0)
            )
            path.closeSubpath()
        }
    }
}

// MARK: - Discord Logo

/// Discord's Clyde mark as a SwiftUI Shape
struct DiscordLogo: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24

        return Path { path in
            // Discord logo path (simplified clyde mark)
            // Main body outline
            path.move(to: CGPoint(x: 19.27 * scale, y: 5.33 * scale))
            path.addCurve(
                to: CGPoint(x: 14.53 * scale, y: 3.6 * scale),
                control1: CGPoint(x: 17.94 * scale, y: 4.71 * scale),
                control2: CGPoint(x: 16.29 * scale, y: 4.04 * scale)
            )
            path.addLine(to: CGPoint(x: 14.13 * scale, y: 4.27 * scale))
            path.addCurve(
                to: CGPoint(x: 9.87 * scale, y: 4.27 * scale),
                control1: CGPoint(x: 12.73 * scale, y: 4.06 * scale),
                control2: CGPoint(x: 11.27 * scale, y: 4.06 * scale)
            )
            path.addLine(to: CGPoint(x: 9.47 * scale, y: 3.6 * scale))
            path.addCurve(
                to: CGPoint(x: 4.73 * scale, y: 5.33 * scale),
                control1: CGPoint(x: 7.71 * scale, y: 4.04 * scale),
                control2: CGPoint(x: 6.06 * scale, y: 4.71 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 2.4 * scale, y: 18.27 * scale),
                control1: CGPoint(x: 1.87 * scale, y: 8.8 * scale),
                control2: CGPoint(x: 1.13 * scale, y: 14.47 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 7.87 * scale, y: 20.4 * scale),
                control1: CGPoint(x: 4.27 * scale, y: 19.67 * scale),
                control2: CGPoint(x: 6.13 * scale, y: 20.4 * scale)
            )
            path.addLine(to: CGPoint(x: 8.8 * scale, y: 19.07 * scale))
            path.addCurve(
                to: CGPoint(x: 12 * scale, y: 19.33 * scale),
                control1: CGPoint(x: 9.87 * scale, y: 19.27 * scale),
                control2: CGPoint(x: 10.93 * scale, y: 19.33 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 15.2 * scale, y: 19.07 * scale),
                control1: CGPoint(x: 13.07 * scale, y: 19.33 * scale),
                control2: CGPoint(x: 14.13 * scale, y: 19.27 * scale)
            )
            path.addLine(to: CGPoint(x: 16.13 * scale, y: 20.4 * scale))
            path.addCurve(
                to: CGPoint(x: 21.6 * scale, y: 18.27 * scale),
                control1: CGPoint(x: 17.87 * scale, y: 20.4 * scale),
                control2: CGPoint(x: 19.73 * scale, y: 19.67 * scale)
            )
            path.addCurve(
                to: CGPoint(x: 19.27 * scale, y: 5.33 * scale),
                control1: CGPoint(x: 22.87 * scale, y: 14.47 * scale),
                control2: CGPoint(x: 22.13 * scale, y: 8.8 * scale)
            )
            path.closeSubpath()

            // Left eye
            path.move(to: CGPoint(x: 8.8 * scale, y: 10.4 * scale))
            path.addEllipse(in: CGRect(
                x: 7.3 * scale,
                y: 10.4 * scale,
                width: 3 * scale,
                height: 3.2 * scale
            ))

            // Right eye
            path.move(to: CGPoint(x: 15.2 * scale, y: 10.4 * scale))
            path.addEllipse(in: CGRect(
                x: 13.7 * scale,
                y: 10.4 * scale,
                width: 3 * scale,
                height: 3.2 * scale
            ))
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BrandLogos_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            GitHubLogo()
                .fill(.white)
                .frame(width: 16, height: 16)

            DiscordLogo()
                .fill(.white)
                .frame(width: 16, height: 16)
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
#endif
