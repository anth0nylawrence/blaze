import SwiftUI

// MARK: - Error Severity

/// Severity levels for error states.
public enum ErrorSeverity {
    case info       // Informational, not blocking
    case success    // Success, operation completed
    case warning    // Caution, may affect operation
    case error      // Error, operation failed
    case critical   // Critical, requires immediate attention

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .info: return Color.ds.info
        case .success: return Color.ds.positive
        case .warning: return Color.ds.warning
        case .error: return Color.ds.negative
        case .critical: return Color.ds.negative
        }
    }

    var backgroundColor: Color {
        color.opacity(0.1)
    }

    var borderColor: Color {
        color.opacity(0.3)
    }
}

// MARK: - Error State

/// A full error state view with icon, message, and retry action.
public struct ErrorState: View {
    let severity: ErrorSeverity
    let title: String
    let message: String?
    let retryTitle: String?
    let retryAction: (() -> Void)?
    let dismissAction: (() -> Void)?

    public init(
        severity: ErrorSeverity = .error,
        title: String,
        message: String? = nil,
        retryTitle: String? = "Try Again",
        retryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.severity = severity
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.retryAction = retryAction
        self.dismissAction = dismissAction
    }

    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            // Icon
            Image(systemName: severity.icon)
                .font(.system(size: DSSize.xxl))
                .foregroundStyle(severity.color)
                .frame(width: DSSize.huge, height: DSSize.huge)
                .background(
                    Circle()
                        .fill(severity.backgroundColor)
                )

            // Text content
            VStack(spacing: DSSpacing.xs) {
                Text(title)
                    .dsTextStyle(.subtitle)
                    .multilineTextAlignment(.center)

                if let message = message {
                    Text(message)
                        .dsTextStyle(.body, color: .ds.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            }

            // Actions
            HStack(spacing: DSSpacing.sm) {
                if let dismissAction = dismissAction {
                    GlassButton("Dismiss", style: .ghost, size: .medium, action: dismissAction)
                }

                if let retryTitle = retryTitle, let retryAction = retryAction {
                    GlassButton(retryTitle, icon: "arrow.clockwise", style: .primary, size: .medium, action: retryAction)
                }
            }
            .padding(.top, DSSpacing.xs)
        }
        .padding(DSSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Inline Error Banner

/// A compact error banner for inline display.
public struct DSErrorBanner: View {
    let severity: ErrorSeverity
    let message: String
    let dismissAction: (() -> Void)?

    @State private var isVisible = true

    public init(
        severity: ErrorSeverity = .error,
        message: String,
        dismissAction: (() -> Void)? = nil
    ) {
        self.severity = severity
        self.message = message
        self.dismissAction = dismissAction
    }

    public var body: some View {
        if isVisible {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: severity.icon)
                    .font(.system(size: DSSize.sm))
                    .foregroundStyle(severity.color)

                Text(message)
                    .dsTextStyle(.caption)
                    .lineLimit(2)

                Spacer()

                if dismissAction != nil {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isVisible = false
                        }
                        dismissAction?()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.ds.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .background(severity.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                    .stroke(severity.borderColor, lineWidth: 1)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Toast Notification

/// A temporary toast notification that auto-dismisses.
public struct Toast: View {
    let severity: ErrorSeverity
    let message: String
    let duration: TimeInterval

    @State private var isVisible = true

    public init(
        severity: ErrorSeverity = .info,
        message: String,
        duration: TimeInterval = 3.0
    ) {
        self.severity = severity
        self.message = message
        self.duration = duration
    }

    public var body: some View {
        if isVisible {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: severity.icon)
                    .font(.system(size: DSSize.sm))
                    .foregroundStyle(severity.color)

                Text(message)
                    .dsTextStyle(.body)
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .dsGlassPanel(level: .prominent, cornerRadius: DSRadius.lg, elevation: .high)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isVisible = false
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Error States") {
    VStack(spacing: DSSpacing.xl) {
        ErrorState(
            severity: .error,
            title: "Connection Failed",
            message: "Unable to connect to the server. Please check your network and try again.",
            retryAction: { print("Retry") },
            dismissAction: { print("Dismiss") }
        )
        .frame(height: 300)
        .dsGlassPanel(level: .subtle)

        VStack(spacing: DSSpacing.sm) {
            DSErrorBanner(severity: .info, message: "Your session will expire in 5 minutes", dismissAction: {})
            DSErrorBanner(severity: .warning, message: "API rate limit approaching", dismissAction: {})
            DSErrorBanner(severity: .error, message: "Failed to save changes", dismissAction: {})
        }

        Toast(severity: .success, message: "Changes saved successfully")
    }
    .padding(DSSpacing.lg)
    .background(Color.ds.bg0)
}
#endif
