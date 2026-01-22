import SwiftUI

// MARK: - Form Row

/// A styled form field row with label, content, and optional help text.
public struct FormRow<Content: View>: View {
    let label: String
    let helpText: String?
    let isRequired: Bool
    let errorMessage: String?
    @ViewBuilder let content: () -> Content

    public init(
        label: String,
        helpText: String? = nil,
        isRequired: Bool = false,
        errorMessage: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.helpText = helpText
        self.isRequired = isRequired
        self.errorMessage = errorMessage
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            // Label
            HStack(spacing: DSSpacing.xxs) {
                Text(label)
                    .dsTextStyle(.body)

                if isRequired {
                    Text("*")
                        .foregroundStyle(Color.ds.negative)
                }
            }

            // Content
            content()

            // Help text or error
            if let errorMessage = errorMessage {
                HStack(spacing: DSSpacing.xxs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                    Text(errorMessage)
                }
                .dsTextStyle(.caption, color: .ds.negative)
            } else if let helpText = helpText {
                Text(helpText)
                    .dsTextStyle(.caption, color: .ds.tertiary)
            }
        }
    }
}

// MARK: - Form Section

/// A styled section container for grouping form rows.
public struct FormSection<Content: View>: View {
    let title: String?
    let description: String?
    @ViewBuilder let content: () -> Content

    public init(
        title: String? = nil,
        description: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.description = description
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            // Header
            if title != nil || description != nil {
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    if let title = title {
                        Text(title)
                            .dsTextStyle(.subtitle)
                    }

                    if let description = description {
                        Text(description)
                            .dsTextStyle(.caption, color: .ds.secondary)
                    }
                }
            }

            // Content
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                content()
            }
            .padding(DSSpacing.md)
            .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.lg, elevation: .low)
        }
    }
}

// MARK: - Glass Text Field

/// A styled text field with glass aesthetic.
public struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let isSecure: Bool

    @FocusState private var isFocused: Bool

    public init(
        _ placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
    }

    public var body: some View {
        HStack(spacing: DSSpacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: DSSize.sm))
                    .foregroundStyle(Color.ds.secondary)
            }

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .dsGlassPanel(
            level: .subtle,
            cornerRadius: DSRadius.md,
            elevation: .none,
            border: isFocused ? .layered : .subtle
        )
        .dsFocusRing(isFocused: isFocused, cornerRadius: DSRadius.md)
    }
}

// MARK: - Glass Toggle

/// A styled toggle with glass aesthetic.
public struct GlassToggle: View {
    let label: String
    @Binding var isOn: Bool
    let description: String?

    public init(
        _ label: String,
        isOn: Binding<Bool>,
        description: String? = nil
    ) {
        self.label = label
        self._isOn = isOn
        self.description = description
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .dsTextStyle(.body)

                if let description = description {
                    Text(description)
                        .dsTextStyle(.caption, color: .ds.tertiary)
                }
            }
        }
        .toggleStyle(.switch)
    }
}

// MARK: - Glass Picker

/// A styled picker with glass aesthetic.
public struct GlassPicker<SelectionValue: Hashable, Content: View>: View {
    let label: String
    @Binding var selection: SelectionValue
    @ViewBuilder let content: () -> Content

    public init(
        _ label: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self._selection = selection
        self.content = content
    }

    public var body: some View {
        Picker(label, selection: $selection) {
            content()
        }
        .pickerStyle(.menu)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Form Components") {
    ScrollView {
        VStack(spacing: DSSpacing.xl) {
            FormSection(
                title: "Account Settings",
                description: "Manage your account preferences"
            ) {
                FormRow(label: "Username", isRequired: true) {
                    GlassTextField("Enter username", text: .constant("john_doe"), icon: "person")
                }

                FormRow(label: "Email", helpText: "We'll never share your email") {
                    GlassTextField("Enter email", text: .constant(""), icon: "envelope")
                }

                FormRow(
                    label: "Password",
                    errorMessage: "Password must be at least 8 characters"
                ) {
                    GlassTextField("Enter password", text: .constant(""), icon: "lock", isSecure: true)
                }
            }

            FormSection(title: "Preferences") {
                GlassToggle(
                    "Enable notifications",
                    isOn: .constant(true),
                    description: "Receive updates about your sessions"
                )

                GlassToggle(
                    "Dark mode",
                    isOn: .constant(false)
                )
            }
        }
        .padding(DSSpacing.lg)
    }
    .background(Color.ds.bg0)
}
#endif
