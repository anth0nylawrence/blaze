# Cogit0 Blaze - Localization Strategy

**Version:** 1.0.0
**Last Updated:** 2025-12-25
**Status:** Draft

---

## Executive Summary

This document outlines the localization strategy for Cogit0 Blaze, from English-only launch through full internationalization (i18n) supporting 9+ languages. We prioritize developer-friendly implementation, maintainable translation workflows, and high-quality localized experiences.

---

## Table of Contents

1. [Localization Roadmap](#1-localization-roadmap)
2. [Target Languages](#2-target-languages)
3. [Technical Architecture](#3-technical-architecture)
4. [String Management](#4-string-management)
5. [Translation Workflow](#5-translation-workflow)
6. [Special Considerations](#6-special-considerations)
7. [Quality Assurance](#7-quality-assurance)
8. [Implementation Guide](#8-implementation-guide)

---

## 1. Localization Roadmap

### 1.1 Phase Overview

| Phase | Timeline | Languages | Focus |
|-------|----------|-----------|-------|
| **1. Foundation** | Launch | English (en) | Infrastructure, string extraction |
| **2. Western European** | +3 months | Spanish, French, German | Romance/Germanic languages |
| **3. Asian Markets** | +6 months | Chinese (Simplified), Japanese, Korean | CJK support |
| **4. Expansion** | +9 months | Italian, Portuguese (BR), Russian | Broad coverage |
| **5. Maintenance** | Ongoing | All | Continuous updates |

### 1.2 Phase 1: Foundation (Launch)

**Objectives:**
- All UI strings externalized to .strings files
- No hardcoded text in code
- String keys follow consistent naming convention
- Plural rules implemented correctly
- Date/time/number formatting localized
- RTL layout infrastructure (for future Arabic/Hebrew)

**Deliverables:**
- `en.lproj/Localizable.strings`
- `en.lproj/Localizable.stringsdict` (plurals)
- String extraction automation
- Localization testing framework

### 1.3 Phase 2: Western European (+3 months)

**Target Languages:**
- **Spanish (es)** - 559M speakers, Latin America + Spain
- **French (fr)** - 321M speakers, France + Canada + Africa
- **German (de)** - 135M speakers, DACH region

**Considerations:**
- Gendered nouns (der/die/das in German)
- Formal/informal address (tu/vous, du/Sie)
- Date formats vary by country
- Number formatting (1,000.00 vs 1.000,00)

### 1.4 Phase 3: Asian Markets (+6 months)

**Target Languages:**
- **Chinese Simplified (zh-Hans)** - 1.1B speakers, mainland China
- **Japanese (ja)** - 125M speakers, Japan
- **Korean (ko)** - 82M speakers, Korea

**Considerations:**
- CJK text rendering and fonts
- Vertical text support (optional)
- Input method compatibility
- Character-based languages have different text expansion
- Honorifics and politeness levels

### 1.5 Phase 4: Expansion (+9 months)

**Target Languages:**
- **Italian (it)** - 85M speakers
- **Portuguese Brazilian (pt-BR)** - 215M speakers
- **Russian (ru)** - 255M speakers (Cyrillic)

**Future Consideration:**
- Arabic (ar) - RTL layout required
- Hindi (hi) - Devanagari script
- Turkish (tr) - Agglutinative language

---

## 2. Target Languages

### 2.1 Language Priority Matrix

| Language | Code | Priority | Developer Population | Market Size |
|----------|------|----------|---------------------|-------------|
| English | en | P0 | 5.5M | Baseline |
| Spanish | es | P1 | 1.3M | High |
| French | fr | P1 | 0.9M | High |
| German | de | P1 | 0.8M | High |
| Chinese (Simplified) | zh-Hans | P2 | 3.5M | Very High |
| Japanese | ja | P2 | 0.7M | Medium |
| Korean | ko | P2 | 0.6M | Medium |
| Italian | it | P3 | 0.3M | Low |
| Portuguese (BR) | pt-BR | P3 | 0.5M | Medium |
| Russian | ru | P3 | 0.4M | Medium |

### 2.2 Locale Variants

| Language | Primary Locale | Variants |
|----------|---------------|----------|
| English | en-US | en-GB, en-AU |
| Spanish | es | es-MX, es-AR |
| French | fr | fr-CA |
| Portuguese | pt-BR | pt-PT |
| Chinese | zh-Hans | zh-Hant (Traditional) |

---

## 3. Technical Architecture

### 3.1 File Structure

```
Blaze/
├── Resources/
│   ├── en.lproj/
│   │   ├── Localizable.strings          # Main UI strings
│   │   ├── Localizable.stringsdict      # Plurals
│   │   ├── InfoPlist.strings            # App name, permissions
│   │   ├── Errors.strings               # Error messages
│   │   └── Accessibility.strings        # VoiceOver labels
│   ├── es.lproj/
│   │   ├── Localizable.strings
│   │   └── ...
│   ├── fr.lproj/
│   └── ...
├── Sources/
│   └── Localization/
│       ├── L10n.swift                   # Generated string accessors
│       ├── LocalizationManager.swift    # Language selection
│       └── Formatters.swift             # Date/number formatters
└── Scripts/
    ├── extract-strings.sh               # String extraction
    ├── validate-strings.sh              # Validation
    └── sync-translations.sh             # Crowdin sync
```

### 3.2 String Key Naming Convention

```
<feature>.<component>.<element>.<variant>

Examples:
session.list.title
session.list.empty.message
session.detail.header.name
chat.input.placeholder
chat.input.send.button
chat.message.user.label
chat.message.assistant.label
tool.bash.title
tool.bash.status.running
tool.bash.status.completed
tool.bash.status.failed
error.network.offline.title
error.network.offline.message
error.network.offline.action.retry
```

### 3.3 Generated String Accessors

```swift
// Generated by SwiftGen or custom script
// L10n.swift

enum L10n {
    enum Session {
        enum List {
            /// Sessions
            static var title: String {
                NSLocalizedString("session.list.title", comment: "")
            }
            /// No sessions yet
            static var emptyMessage: String {
                NSLocalizedString("session.list.empty.message", comment: "")
            }
        }
    }

    enum Chat {
        enum Input {
            /// Type your message...
            static var placeholder: String {
                NSLocalizedString("chat.input.placeholder", comment: "")
            }

            /// Send
            static var sendButton: String {
                NSLocalizedString("chat.input.send.button", comment: "")
            }
        }

        enum Message {
            /// You said:
            static var userLabel: String {
                NSLocalizedString("chat.message.user.label", comment: "")
            }

            /// Claude said:
            static var assistantLabel: String {
                NSLocalizedString("chat.message.assistant.label", comment: "")
            }
        }
    }

    enum Tool {
        enum Bash {
            /// Bash
            static var title: String {
                NSLocalizedString("tool.bash.title", comment: "")
            }

            /// Running...
            static var statusRunning: String {
                NSLocalizedString("tool.bash.status.running", comment: "")
            }

            /// Completed in %@
            static func statusCompleted(_ duration: String) -> String {
                String(format: NSLocalizedString("tool.bash.status.completed", comment: ""), duration)
            }
        }
    }
}
```

### 3.4 Pluralization

```xml
<!-- Localizable.stringsdict -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>session.turns.count</key>
    <dict>
        <key>NSStringLocalizedFormatKey</key>
        <string>%#@turns@</string>
        <key>turns</key>
        <dict>
            <key>NSStringFormatSpecTypeKey</key>
            <string>NSStringPluralRuleType</string>
            <key>NSStringFormatValueTypeKey</key>
            <string>d</string>
            <key>zero</key>
            <string>No turns</string>
            <key>one</key>
            <string>1 turn</string>
            <key>other</key>
            <string>%d turns</string>
        </dict>
    </dict>

    <key>diff.lines.added</key>
    <dict>
        <key>NSStringLocalizedFormatKey</key>
        <string>%#@lines@</string>
        <key>lines</key>
        <dict>
            <key>NSStringFormatSpecTypeKey</key>
            <string>NSStringPluralRuleType</string>
            <key>NSStringFormatValueTypeKey</key>
            <string>d</string>
            <key>zero</key>
            <string>No lines added</string>
            <key>one</key>
            <string>1 line added</string>
            <key>other</key>
            <string>%d lines added</string>
        </dict>
    </dict>
</dict>
</plist>
```

**Swift Usage:**

```swift
// Plural-aware string
let turnsText = String(localized: "session.turns.count", defaultValue: "%d turns")
    .formatted(turnCount)

// Or with SwiftGen
let turnsText = L10n.Session.Turns.count(turnCount)
```

---

## 4. String Management

### 4.1 String Categories

| Category | File | Description |
|----------|------|-------------|
| UI Strings | Localizable.strings | Buttons, labels, placeholders |
| Plurals | Localizable.stringsdict | Count-dependent strings |
| Errors | Errors.strings | Error titles and messages |
| Accessibility | Accessibility.strings | VoiceOver labels/hints |
| System | InfoPlist.strings | App name, permission prompts |

### 4.2 String Extraction

```bash
#!/bin/bash
# extract-strings.sh

# Extract from Swift files
find Sources -name "*.swift" -exec grep -E 'NSLocalizedString|String\(localized:' {} \; \
  | sort -u \
  > extracted_strings.txt

# Generate missing keys
python3 scripts/generate_missing_keys.py \
  --source extracted_strings.txt \
  --target Resources/en.lproj/Localizable.strings

# Validate no hardcoded strings
python3 scripts/detect_hardcoded_strings.py Sources/
```

### 4.3 Translation Memory

Maintain a glossary of technical terms that should be consistent across translations:

| English | Spanish | French | German | Chinese | Japanese |
|---------|---------|--------|--------|---------|----------|
| Session | Sesión | Session | Sitzung | 会话 | セッション |
| Turn | Turno | Tour | Runde | 轮次 | ターン |
| Prompt | Prompt | Invite | Prompt | 提示 | プロンプト |
| Token | Token | Jeton | Token | 令牌 | トークン |
| Diff | Diff | Diff | Diff | 差异 | 差分 |
| Policy | Política | Politique | Richtlinie | 策略 | ポリシー |
| Hook | Hook | Hook | Hook | 钩子 | フック |

---

## 5. Translation Workflow

### 5.1 Crowdin Integration

```yaml
# crowdin.yml
project_id: "cogit0-blaze"
api_token_env: "CROWDIN_TOKEN"
base_path: "."
preserve_hierarchy: true

files:
  - source: "/Resources/en.lproj/Localizable.strings"
    translation: "/Resources/%locale%.lproj/Localizable.strings"

  - source: "/Resources/en.lproj/Localizable.stringsdict"
    translation: "/Resources/%locale%.lproj/Localizable.stringsdict"

  - source: "/Resources/en.lproj/Errors.strings"
    translation: "/Resources/%locale%.lproj/Errors.strings"

  - source: "/Resources/en.lproj/Accessibility.strings"
    translation: "/Resources/%locale%.lproj/Accessibility.strings"
```

### 5.2 Translation Process

```
1. Developer adds new strings
        │
        ▼
2. CI extracts and validates strings
        │
        ▼
3. Strings synced to Crowdin
        │
        ▼
4. Translators translate in Crowdin
        │
        ▼
5. Translations reviewed by language leads
        │
        ▼
6. Approved translations synced to repo
        │
        ▼
7. CI validates translations
        │
        ▼
8. Merged to main branch
```

### 5.3 Translation Context

Provide context for translators:

```
/* Localizable.strings with context comments */

/* Title for the sessions list in the sidebar */
"session.list.title" = "Sessions";

/* Placeholder text shown when no sessions exist yet */
"session.list.empty.message" = "No sessions yet";

/* Button label to send a message. Keep it short (max 10 chars) */
"chat.input.send.button" = "Send";

/* Format: Completed in {duration}. Example: "Completed in 1.2s" */
"tool.bash.status.completed" = "Completed in %@";
```

### 5.4 String Change Management

| Change Type | Impact | Process |
|-------------|--------|---------|
| Add new string | Low | Auto-sync to Crowdin |
| Modify existing string | Medium | Mark for re-translation |
| Delete string | Low | Remove from all locales |
| Rename key | Medium | Migrate all translations |

```swift
// Deprecation pattern
enum L10n {
    @available(*, deprecated, message: "Use sendMessage instead")
    static var send: String { sendMessage }

    static var sendMessage: String {
        NSLocalizedString("chat.input.sendMessage", comment: "")
    }
}
```

---

## 6. Special Considerations

### 6.1 Text Expansion

Languages expand/contract differently from English:

| Language | Typical Expansion | UI Impact |
|----------|-------------------|-----------|
| German | +30% | Longer buttons, labels |
| French | +20% | Moderate expansion |
| Spanish | +15% | Moderate expansion |
| Chinese | -30% | Shorter text |
| Japanese | -20% | Shorter text |

**Mitigation:**
```swift
// Use flexible layouts
HStack {
    Text(L10n.Chat.Input.sendButton)
        .lineLimit(1)
        .minimumScaleFactor(0.8)  // Shrink if needed
}
.frame(minWidth: 60)  // Minimum, not fixed
```

### 6.2 Date and Time Formatting

```swift
class LocalizationManager {
    static let shared = LocalizationManager()

    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()

    lazy var relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale.current
        return formatter
    }()

    func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds < 60 ? [.second] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "\(Int(seconds))s"
    }
}

// Usage
Text(LocalizationManager.shared.dateFormatter.string(from: session.createdAt))
Text(LocalizationManager.shared.relativeDateFormatter.localizedString(for: session.lastUsedAt, relativeTo: Date()))
```

### 6.3 Number Formatting

```swift
extension Int {
    var localizedTokenCount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Double {
    var localizedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    var localizedPercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: self)) ?? "\(self * 100)%"
    }
}

// Usage
Text("\(session.totalTokens.localizedTokenCount) tokens")
// en-US: "1,234,567 tokens"
// de-DE: "1.234.567 tokens"
// fr-FR: "1 234 567 tokens"
```

### 6.4 CJK Considerations

```swift
// Font fallback for CJK
extension Font {
    static var blazeBody: Font {
        .system(.body)
    }

    static var blazeMonospace: Font {
        if Locale.current.language.languageCode == "ja" ||
           Locale.current.language.languageCode == "zh" ||
           Locale.current.language.languageCode == "ko" {
            // Use system monospace which includes CJK glyphs
            return .system(.body, design: .monospaced)
        }
        return .custom("JetBrains Mono", size: 13)
    }
}

// Line height adjustment for CJK
extension View {
    func cjkAdjustedLineSpacing() -> some View {
        let isCJK = Locale.current.language.languageCode?.identifier
            .hasPrefix(contentsOf: ["zh", "ja", "ko"]) ?? false
        return lineSpacing(isCJK ? 4 : 2)
    }
}
```

### 6.5 RTL Preparation

Even without RTL languages yet, prepare the codebase:

```swift
// Use leading/trailing, not left/right
HStack {
    icon
    Text(label)
    Spacer()
    chevron
}
.padding(.leading, 16)  // ✓ Correct
// .padding(.left, 16)  // ✗ Avoid

// Test RTL layout
#if DEBUG
struct RTLPreview: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.layoutDirection, .rightToLeft)
            .previewDisplayName("RTL Layout")
    }
}
#endif
```

### 6.6 Cultural References

Our error messages include pop culture references. Provide alternatives:

```swift
// Errors.strings (en)
"error.E1001.title.starwars" = "These Aren't the Droids You're Looking For";
"error.E1001.title.generic" = "CLI Not Found";

// Errors.strings (zh-Hans) - Use local reference or generic
"error.E1001.title.starwars" = "找不到命令行工具";  // Generic version
"error.E1001.title.generic" = "找不到命令行工具";

// Logic to select appropriate variant
func localizedErrorTitle(code: ErrorCode) -> String {
    let starWarsKey = "error.\(code).title.starwars"
    let genericKey = "error.\(code).title.generic"

    // Check if localized version differs from English (was actually translated)
    let starWarsLocalized = NSLocalizedString(starWarsKey, comment: "")
    let starWarsEnglish = NSLocalizedString(starWarsKey, tableName: nil, bundle: .main, value: "", comment: "")

    if starWarsLocalized != starWarsEnglish {
        return starWarsLocalized
    }
    return NSLocalizedString(genericKey, comment: "")
}
```

---

## 7. Quality Assurance

### 7.1 Automated Validation

```bash
#!/bin/bash
# validate-strings.sh

# Check for missing translations
for locale in es fr de zh-Hans ja ko it pt-BR ru; do
    missing=$(diff \
        <(grep "^\"" Resources/en.lproj/Localizable.strings | cut -d'"' -f2 | sort) \
        <(grep "^\"" Resources/$locale.lproj/Localizable.strings | cut -d'"' -f2 | sort) \
        | grep "^<" | wc -l)

    if [ $missing -gt 0 ]; then
        echo "WARNING: $locale is missing $missing strings"
    fi
done

# Check for format specifier mismatches
python3 scripts/validate_format_specifiers.py

# Check for truncated translations
python3 scripts/check_translation_length.py --max-expansion 1.5

# Check for untranslated strings (still English)
python3 scripts/detect_untranslated.py
```

### 7.2 Pseudo-Localization Testing

```swift
#if DEBUG
struct PseudoLocalization {
    static func pseudoLocalize(_ string: String) -> String {
        // Add accents to Latin characters
        let accented = string.map { char -> Character in
            switch char {
            case "a": return "à"
            case "e": return "ë"
            case "i": return "ì"
            case "o": return "ô"
            case "u": return "ü"
            default: return char
            }
        }

        // Add expansion padding
        let expanded = String(accented) + " [ṃṃṃ]"

        // Add markers to detect unlocalized strings
        return "⟦" + expanded + "⟧"
    }
}

// Enable pseudo-localization
class DebugLocalizationManager {
    static var pseudoEnabled = false

    static func localizedString(_ key: String) -> String {
        let base = NSLocalizedString(key, comment: "")
        return pseudoEnabled ? PseudoLocalization.pseudoLocalize(base) : base
    }
}
#endif
```

### 7.3 Manual QA Checklist

For each language release:

- [ ] All screens reviewed by native speaker
- [ ] No truncated text
- [ ] No overlapping UI elements
- [ ] Correct date/time/number formats
- [ ] Correct pluralization
- [ ] Culturally appropriate content
- [ ] No offensive translations
- [ ] Consistent terminology with glossary
- [ ] VoiceOver labels translated
- [ ] Error messages clear and helpful

### 7.4 Native Speaker Review

Each language should have a designated reviewer who is:
- Native speaker
- Developer or technical user
- Familiar with AI/coding terminology

---

## 8. Implementation Guide

### 8.1 Adding a New String

```swift
// 1. Add to en.lproj/Localizable.strings
/* Button to approve changes in the diff viewer */
"diff.action.approve" = "Approve";

// 2. Add accessor to L10n.swift (or regenerate with SwiftGen)
enum L10n {
    enum Diff {
        enum Action {
            static var approve: String {
                NSLocalizedString("diff.action.approve", comment: "")
            }
        }
    }
}

// 3. Use in code
Button(L10n.Diff.Action.approve) { approveChanges() }

// 4. Run string sync to push to Crowdin
./scripts/sync-translations.sh upload
```

### 8.2 Adding a New Language

```bash
# 1. Create new locale folder
mkdir Resources/it.lproj

# 2. Copy base strings
cp Resources/en.lproj/Localizable.strings Resources/it.lproj/
cp Resources/en.lproj/Localizable.stringsdict Resources/it.lproj/
cp Resources/en.lproj/Errors.strings Resources/it.lproj/
cp Resources/en.lproj/Accessibility.strings Resources/it.lproj/
cp Resources/en.lproj/InfoPlist.strings Resources/it.lproj/

# 3. Add to Xcode project (automatic with folder reference)

# 4. Add to Crowdin config
# Edit crowdin.yml to include new locale

# 5. Upload to Crowdin
./scripts/sync-translations.sh upload

# 6. Request translations

# 7. Download when complete
./scripts/sync-translations.sh download

# 8. Test
xcodebuild test -scheme BlazeTests -testLanguage it
```

### 8.3 Language Selection UI

```swift
struct LanguageSettingsView: View {
    @AppStorage("app.language") var selectedLanguage: String?

    let supportedLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Español"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("zh-Hans", "简体中文"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("it", "Italiano"),
        ("pt-BR", "Português (Brasil)"),
        ("ru", "Русский")
    ]

    var body: some View {
        Form {
            Section("Language") {
                Picker("Display Language", selection: $selectedLanguage) {
                    Text("System Default").tag(nil as String?)
                    ForEach(supportedLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code as String?)
                    }
                }

                if selectedLanguage != nil {
                    Text("Restart Blaze to apply language change")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

---

## Appendix A: Translation Style Guide

### A.1 Tone

| Aspect | Guideline |
|--------|-----------|
| Formality | Professional but friendly (avoid overly formal) |
| Technical terms | Keep English for widely-understood terms (e.g., "token", "API") |
| Humor | Adapt cultural references; use generic if no equivalent |
| Length | Match English length where possible |

### A.2 Glossary Enforcement

| Term | Translation Note |
|------|------------------|
| Claude | Never translate (proper noun) |
| Blaze | Never translate (product name) |
| Token | Translate or keep based on local convention |
| Session | Use local software terminology |
| Prompt | Use established AI/ML terminology in target language |

---

## Appendix B: Locale Support Matrix

| Language | Code | Status | Translator | Reviewer |
|----------|------|--------|------------|----------|
| English | en | Complete | N/A | N/A |
| Spanish | es | Planned | TBD | TBD |
| French | fr | Planned | TBD | TBD |
| German | de | Planned | TBD | TBD |
| Chinese (Simp) | zh-Hans | Planned | TBD | TBD |
| Japanese | ja | Planned | TBD | TBD |
| Korean | ko | Planned | TBD | TBD |
| Italian | it | Future | TBD | TBD |
| Portuguese (BR) | pt-BR | Future | TBD | TBD |
| Russian | ru | Future | TBD | TBD |

---

**End of Document**
