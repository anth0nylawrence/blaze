# Beta Program Design

> Cogit0 Blaze - Early Access Program Strategy

## Overview

This document outlines the beta testing program for Cogit0 Blaze, designed to gather real-world feedback, identify edge cases, and build community before public launch.

---

## 1. Program Structure

### 1.1 Beta Phases

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          BETA PROGRAM TIMELINE                            │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Alpha          Private Beta       Public Beta        General            │
│  (Internal)     (Invite-Only)      (Open)             Availability       │
│     │               │                  │                   │             │
│     ▼               ▼                  ▼                   ▼             │
│  ┌──────┐       ┌──────┐          ┌──────┐           ┌──────┐           │
│  │ Week │       │ Week │          │ Week │           │ Week │           │
│  │ 1-2  │──────▶│ 3-6  │─────────▶│ 7-10 │──────────▶│ 11+  │           │
│  └──────┘       └──────┘          └──────┘           └──────┘           │
│     │               │                  │                   │             │
│  10 users       100 users          1000 users          Open             │
│  Team only      Power users        Developers          Launch           │
│                 Influencers        Waitlist                             │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Phase Definitions

| Phase | Duration | Users | Focus |
|-------|----------|-------|-------|
| **Alpha** | 2 weeks | 10 (team) | Core stability, critical bugs |
| **Private Beta** | 4 weeks | 100 | Feature validation, UX feedback |
| **Public Beta** | 4 weeks | 1000+ | Scale testing, edge cases |
| **GA** | Ongoing | Unlimited | Production support |

---

## 2. Beta Cohort Selection

### 2.1 Private Beta Criteria

**Must Have (all required):**
- Active Claude Code CLI user (verified by Anthropic or self-reported)
- macOS 14+ device
- Willingness to provide weekly feedback
- Signed beta agreement / NDA

**Nice to Have (weighted scoring):**
- Developer with 5+ years experience (+3)
- Active on developer Twitter/Mastodon (+2)
- Open source contributor (+2)
- Previous beta tester for dev tools (+1)
- Works at notable tech company (+1)

### 2.2 Cohort Composition Targets

| Segment | Private Beta | Public Beta |
|---------|--------------|-------------|
| Power users (10+ hrs/week CLI) | 40% | 30% |
| Regular users (2-10 hrs/week) | 40% | 50% |
| Casual users (< 2 hrs/week) | 20% | 20% |
| macOS 14 users | 50% | 40% |
| macOS 15 users | 50% | 60% |
| M1/M2/M3 chip | 80% | 80% |
| Intel Mac | 20% | 20% |

---

## 3. Onboarding Flow

### 3.1 Beta Welcome Sequence

```
Day 0: Invite Accepted
├── Welcome email with download link
├── Beta agreement acknowledgment
└── Slack/Discord community invite

Day 1: First Launch
├── In-app welcome tutorial
├── Feature highlights tour
└── Feedback widget introduction

Day 3: Check-in
├── "How's it going?" email
├── Quick survey (NPS + 3 questions)
└── Link to known issues

Day 7: Deep Dive
├── Detailed feedback survey
├── Feature request collection
└── Video call invitation (optional)

Day 14: Progress Update
├── "What we fixed" newsletter
├── Upcoming features preview
└── Community highlights
```

### 3.2 In-App Onboarding

```swift
// BetaOnboarding.swift

struct BetaOnboardingView: View {
    @State private var step = 0

    var body: some View {
        VStack {
            switch step {
            case 0:
                WelcomeStep()
            case 1:
                CLIConnectionStep()
            case 2:
                FeatureTourStep()
            case 3:
                FeedbackIntroStep()
            default:
                CompletionStep()
            }

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                Spacer()
                Button(step < 4 ? "Next" : "Get Started") {
                    if step < 4 { step += 1 }
                    else { completeOnboarding() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct FeedbackIntroStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Your Feedback Shapes Blaze")
                .font(.title)

            Text("""
            As a beta tester, you're helping build the future of AI-assisted coding.

            • Shake your Mac or press ⌘⇧F to report issues
            • The feedback button is always in the bottom-right
            • Weekly surveys help us prioritize

            Every bug report and suggestion matters!
            """)
            .multilineTextAlignment(.center)
        }
    }
}
```

---

## 4. Feedback Collection

### 4.1 Feedback Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| **In-App Widget** | Quick feedback, bugs | 24 hours |
| **Shake to Report** | Crash reports, urgent issues | 12 hours |
| **Weekly Survey** | Structured feedback | Weekly digest |
| **Discord/Slack** | Community discussion | 4 hours (business) |
| **Email** | Detailed reports | 48 hours |
| **Video Calls** | Deep-dive sessions | Scheduled |

### 4.2 In-App Feedback Widget

```swift
// FeedbackWidget.swift

struct FeedbackWidget: View {
    @State private var isExpanded = false
    @State private var feedbackType: FeedbackType = .bug
    @State private var description = ""
    @State private var includeScreenshot = true
    @State private var includeLogs = true

    var body: some View {
        VStack {
            if isExpanded {
                FeedbackForm(
                    type: $feedbackType,
                    description: $description,
                    includeScreenshot: $includeScreenshot,
                    includeLogs: $includeLogs,
                    onSubmit: submitFeedback,
                    onCancel: { isExpanded = false }
                )
            } else {
                Button {
                    isExpanded = true
                } label: {
                    Image(systemName: "bubble.left.fill")
                        .font(.title2)
                        .padding(12)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
        }
        .animation(.spring(), value: isExpanded)
    }

    enum FeedbackType: String, CaseIterable {
        case bug = "Bug Report"
        case feature = "Feature Request"
        case usability = "Usability Issue"
        case praise = "Something I Love"
        case other = "Other"
    }

    private func submitFeedback() {
        Task {
            var payload = FeedbackPayload(
                type: feedbackType.rawValue,
                description: description,
                appVersion: Bundle.main.appVersion,
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                timestamp: Date()
            )

            if includeScreenshot {
                payload.screenshot = await captureScreenshot()
            }

            if includeLogs {
                payload.logs = await collectRecentLogs()
            }

            try await FeedbackService.shared.submit(payload)

            isExpanded = false
            description = ""
        }
    }
}
```

### 4.3 Shake to Report

```swift
// ShakeDetector.swift

final class ShakeDetector: NSObject {
    static let shared = ShakeDetector()

    func startMonitoring() {
        NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { event in
            if event.subtype.rawValue == 8 { // System shake event
                self.triggerFeedback()
            }
            return event
        }

        // Also monitor for keyboard shortcut ⌘⇧F
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains([.command, .shift]) &&
               event.charactersIgnoringModifiers == "f" {
                self.triggerFeedback()
                return nil
            }
            return event
        }
    }

    private func triggerFeedback() {
        // Capture current state
        let screenshot = ScreenshotCapture.captureMainWindow()
        let logs = LogCollector.collectRecent(seconds: 60)
        let sessionState = SessionStore.shared.captureState()

        // Show feedback dialog
        FeedbackCoordinator.shared.showQuickReport(
            screenshot: screenshot,
            logs: logs,
            context: sessionState
        )
    }
}
```

### 4.4 Weekly Survey Template

```markdown
## Blaze Beta - Weekly Check-in

### Overall Experience

1. How would you rate your experience with Blaze this week?
   ○ 1 (Frustrating) ○ 2 ○ 3 ○ 4 ○ 5 (Delightful)

2. How likely are you to recommend Blaze to a colleague? (NPS)
   ○ 0 ○ 1 ○ 2 ○ 3 ○ 4 ○ 5 ○ 6 ○ 7 ○ 8 ○ 9 ○ 10

### Feature Feedback

3. Which feature did you use most this week?
   ○ Chat/Conversations
   ○ Diff Viewer
   ○ Tool Cards
   ○ Session Management
   ○ Branching
   ○ Other: ________

4. What's the #1 thing that frustrated you?
   [Free text]

5. What's the #1 thing you loved?
   [Free text]

### Bugs & Issues

6. Did you encounter any bugs this week?
   ○ No bugs
   ○ Minor bugs (cosmetic)
   ○ Moderate bugs (workaround needed)
   ○ Major bugs (blocked my work)

7. If yes, please describe:
   [Free text]

### Feature Requests

8. What feature would make Blaze 10x better for you?
   [Free text]

### Open Feedback

9. Anything else you'd like to share?
   [Free text]
```

---

## 5. Communication Strategy

### 5.1 Release Notes Template

```markdown
# Blaze Beta [version] - Release Notes

**Released:** [date]
**Build:** [build number]

## What's New

### 🎉 New Features
- **Feature Name**: Brief description of what it does and why it's useful

### 🐛 Bug Fixes
- Fixed issue where [specific problem] (Thanks @username!)
- Resolved crash when [action]
- Corrected [behavior]

### ⚡ Improvements
- Improved [area] by [measurable improvement]
- Enhanced [feature] performance

### 🔧 Known Issues
- [Issue description] - workaround: [steps]

## Upgrading

This update will auto-download when you launch Blaze. If you prefer manual:
1. Download from [link]
2. Drag to Applications (replace existing)

## Feedback

Found something? [Report here](link) or shake your Mac!

---
*Thank you for being part of the Blaze beta!*
```

### 5.2 Communication Schedule

| Day | Communication | Channel |
|-----|---------------|---------|
| Monday | Week recap + roadmap update | Email + Discord |
| Wednesday | Mid-week tips & tricks | Discord only |
| Friday | Release notes (if new build) | Email + In-app |
| Ad-hoc | Urgent fixes | Push notification |

---

## 6. Incentive Program

### 6.1 Beta Perks

| Tier | Criteria | Rewards |
|------|----------|---------|
| **Participant** | Joined beta | Beta badge, early access |
| **Contributor** | 5+ feedback submissions | Extended free trial, swag |
| **Champion** | 20+ submissions or bug finds | Lifetime discount, credits |
| **Founding Member** | Private beta + major contribution | Name in credits, exclusive features |

### 6.2 Recognition System

```swift
// BetaRecognition.swift

enum BetaBadge: String, Codable, CaseIterable {
    case earlyAdopter = "Early Adopter"
    case bugHunter = "Bug Hunter"
    case featureChampion = "Feature Champion"
    case communityHelper = "Community Helper"
    case foundingMember = "Founding Member"

    var icon: String {
        switch self {
        case .earlyAdopter: return "🌟"
        case .bugHunter: return "🐛"
        case .featureChampion: return "💡"
        case .communityHelper: return "🤝"
        case .foundingMember: return "🏆"
        }
    }
}

struct BetaProfile: Codable {
    let userId: String
    var feedbackCount: Int
    var bugsReported: Int
    var featuresRequested: Int
    var badges: Set<BetaBadge>

    mutating func checkBadgeEligibility() {
        if feedbackCount >= 5 {
            badges.insert(.earlyAdopter)
        }
        if bugsReported >= 10 {
            badges.insert(.bugHunter)
        }
        if featuresRequested >= 5 {
            badges.insert(.featureChampion)
        }
    }
}
```

---

## 7. Issue Tracking

### 7.1 Triage Process

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         BETA ISSUE TRIAGE FLOW                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Feedback      ──▶  Triage       ──▶  Categorize   ──▶  Prioritize     │
│  Received           (< 4 hrs)          & Tag             & Assign       │
│      │                  │                 │                  │          │
│      ▼                  ▼                 ▼                  ▼          │
│  ┌──────────┐    ┌──────────┐      ┌──────────┐       ┌──────────┐     │
│  │ In-app   │    │ Is it    │      │ Bug      │       │ P0: Fix  │     │
│  │ Discord  │    │ valid?   │      │ Feature  │       │ today    │     │
│  │ Email    │    │ Dupe?    │      │ UX       │       │ P1: This │     │
│  │ Shake    │    │ Wontfix? │      │ Docs     │       │ week     │     │
│  └──────────┘    └──────────┘      └──────────┘       │ P2: Next │     │
│                                                        │ sprint   │     │
│                                                        └──────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Issue States

| State | Meaning | User Communication |
|-------|---------|-------------------|
| **New** | Just received | Auto-acknowledge email |
| **Triaged** | Reviewed, categorized | None (internal) |
| **Confirmed** | Verified as valid | "We've confirmed your report" |
| **In Progress** | Actively being fixed | "We're working on it" |
| **Fixed** | Complete, in next build | "Fixed in next release" |
| **Released** | Available to user | Release notes mention |
| **Wontfix** | Won't address | Explanation email |

---

## 8. Success Metrics

### 8.1 Beta Health KPIs

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Active Beta Users** | 80% DAU/MAU | Daily active / total enrolled |
| **Feedback Rate** | > 20% weekly | Users submitting feedback / total |
| **NPS Score** | > 40 | Weekly survey |
| **Bug Report Rate** | Decreasing week-over-week | Issues per active user |
| **Response Time** | < 24 hours | Median time to first response |
| **Fix Time (P0/P1)** | < 48 hours | Median time to release fix |

### 8.2 Weekly Dashboard

```swift
// BetaMetrics.swift

struct BetaMetricsDashboard {
    let week: Int
    let dateRange: DateInterval

    // Engagement
    let totalEnrolled: Int
    let activeUsers: Int
    let newSignups: Int
    let churned: Int

    // Feedback
    let totalFeedbackItems: Int
    let bugsReported: Int
    let featuresRequested: Int
    let npsScore: Double

    // Quality
    let crashFreeRate: Double
    let averageSessionLength: TimeInterval
    let eventsProcessed: Int

    // Calculated
    var dauMauRatio: Double {
        Double(activeUsers) / Double(totalEnrolled)
    }

    var feedbackRate: Double {
        Double(totalFeedbackItems) / Double(activeUsers)
    }
}
```

---

## 9. Graduation Criteria

### 9.1 Exit Beta Requirements

| Category | Criteria | Status |
|----------|----------|--------|
| **Stability** | Crash-free rate > 99.5% | ⬜ |
| **Stability** | No P0 bugs open > 24 hours | ⬜ |
| **Quality** | P1 bug backlog < 10 | ⬜ |
| **Quality** | All core features complete | ⬜ |
| **Performance** | All perf budgets met | ⬜ |
| **UX** | NPS > 50 | ⬜ |
| **UX** | User satisfaction > 4/5 | ⬜ |
| **Scale** | Tested with 1000+ users | ⬜ |
| **Scale** | No degradation at scale | ⬜ |

### 9.2 GA Readiness Checklist

- [ ] All P0 and P1 issues resolved
- [ ] Documentation complete
- [ ] Support runbook ready
- [ ] Pricing/licensing finalized
- [ ] Marketing site live
- [ ] App Store / distribution ready
- [ ] Analytics and monitoring in place
- [ ] Onboarding flow polished
- [ ] FAQ and known issues published
