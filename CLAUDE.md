# Plyne — guide for AI-assisted development

This file is loaded into every assistant session in this repo. Read it before doing anything else.

## What Plyne is

Plyne is a free, open-source, native menu-bar application for **macOS 26 (Tahoe) and newer**. It helps knowledge workers hold focus through a hybrid Pomodoro/Flowmodoro timer, a silent activity tracker, and gentle, non-judgmental analytics. **No streaks, no leaderboards, no subscriptions, no telemetry.**

The full product concept is in [.scratch/PLYNE_CONCEPT.md](.scratch/PLYNE_CONCEPT.md). **Read it before making product decisions.** It is the source of truth for what we build, what we refuse to build, and the tone of every line of UI copy.

The active implementation roadmap is in [.scratch/IMPLEMENTATION_PLAN.md](.scratch/IMPLEMENTATION_PLAN.md). Keep it in sync with reality.

### Using `.scratch/` as session-handoff memory

`.scratch/` is gitignored on purpose — it is the local **knowledge base for this project**, owned by the human + assistant working pair, not the public repo. **Use it actively.** Anything that would otherwise be lost between sessions belongs here:

- product concept, implementation plan, open questions
- research notes (e.g. "what we learned about EventKit access on Tahoe")
- API/framework cheat-sheets we accumulated while debugging
- decisions and their *why* (so we don't re-litigate them next session)
- design sketches, copy drafts, UX considerations
- vendor docs, screenshots, icon variants we are evaluating

Conventions:

1. **Read `.scratch/` at the start of every session.** At minimum: `ls .scratch/` and skim the implementation plan. Pick up unread research files relevant to the task.
2. **Before writing a non-trivial answer or starting a step, check whether prior notes already cover it.** Don't re-derive.
3. **Write findings down** — if you learned something this session that future-you would want, drop a Markdown file in `.scratch/research/`, `.scratch/decisions/`, or `.scratch/notes/`. Subfolders are flexible; just keep filenames descriptive (`eventkit-permissions-tahoe.md`, not `notes.md`).
4. **Decisions in `.scratch/decisions/`** are append-only, ADR-style: title, date, context, decision, consequences. Don't rewrite history — supersede with a new file.
5. **`.scratch/` is never pushed.** If something matures into public-facing documentation, move it to `docs/` and commit deliberately.
6. **Update the implementation plan in place** when steps complete or scope shifts.

## Operating rules (non-negotiable)

1. **No AI attribution anywhere in the repo.** No mentions of Claude, Claude Code, AI authorship, "Co-Authored-By: Claude", "Generated with Claude Code", or similar in commits, PR titles/bodies, comments, READMEs, or release notes. Commits and PRs go out under the human author's git identity only.
2. **Branching:** all work lands on `dev` first. `main` only receives merges for tagged releases. Never push directly to `main`.
3. **Step-by-step delivery:** each implementation step is small enough to review on its own. After every step, run a code-review sub-agent (see "Code review loop" below) before opening a PR.
4. **CI economy:** documentation-only changes (Markdown, `.scratch/`, `LICENSE`) must not trigger macOS builds. Anything that doesn't need Mac runs on Linux. See `.github/workflows/ci.yml` for the path filters.
5. **Tone of voice.** Every user-facing string — UI labels, errors, notifications, release notes, even commit messages we cite to users — follows the tone rules in the concept doc (section "Тон коммуникации"). Observer, never judge. No streaks-as-pressure copy. No "champion", "great job", emoji confetti, productivity-bro vocabulary.
6. **Privacy posture.** No outbound network calls by default. No telemetry. Any data egress (sync, integrations, analytics) requires explicit opt-in and a transparent explanation of what leaves the device.

## Target platform

| Item | Value |
|---|---|
| Minimum macOS | 26.0 (Tahoe) |
| Languages | Swift 6.x, SwiftUI-first, AppKit where needed (`NSStatusItem` interop, accessibility APIs) |
| Architectures | arm64 + x86_64 universal binary for releases |
| Bundle ID | `app.plyne.Plyne` (placeholder — confirm before first release) |
| Code signing | Ad-hoc for now (no Apple Developer ID yet). Release notes must include the `xattr -dr com.apple.quarantine /Applications/Plyne.app` instruction until notarization is set up. |
| Distribution | GitHub Releases (zip + later DMG). Homebrew Cask post-1.0. **No App Store** (we need accessibility/scripting APIs the sandbox forbids). |

## Repository layout

```
Plyne/
├── Plyne.xcodeproj/             # primary build target (will be created in Step 1.1)
├── App/                         # SwiftUI app shell, menu bar, dashboard windows
│   ├── PlyneApp.swift
│   ├── Info.plist               # LSUIElement = YES (menu-bar-only, no Dock)
│   ├── Plyne.entitlements
│   ├── Resources/
│   ├── Assets.xcassets/
│   └── Localizable.xcstrings    # single String Catalog for RU + EN
├── Packages/                    # local Swift Packages (cleanly separated layers)
│   ├── PlyneCore/               # pure Swift, runs on Linux — domain types, timer FSM, math
│   ├── PlyneAnalytics/          # pure Swift — heatmap aggregation, trends, insight rules
│   ├── PlyneStorage/            # macOS-only — SwiftData schema and repositories
│   ├── PlyneTracker/            # macOS-only — NSWorkspace, AXObserver, AFK detection
│   ├── PlyneCalendar/           # macOS-only — EventKit access
│   └── PlyneFocus/              # macOS-only — Focus Filters, App Intents
├── .github/
│   └── workflows/
│       ├── ci.yml               # PR + push to dev/main
│       └── release.yml          # tagged release builds
├── .scratch/                    # gitignored — knowledge base (concept, plan, research, decisions, sketches)
├── CLAUDE.md                    # this file
├── README.md
└── LICENSE                      # MIT
```

The split between **pure Swift** packages (`PlyneCore`, `PlyneAnalytics`) and **macOS-only** packages is deliberate: the pure ones build and test on Linux in CI, which keeps most logic-level iterations off the macOS runner minutes.

When adding a new module, ask: *does it need AppKit, EventKit, accessibility, SwiftData, or any Apple framework?* If yes → macOS-only package. If no → pure Swift package, testable on Linux.

## Build & test commands

```bash
# Pure-Swift package tests (run anywhere, including Linux CI)
swift test --package-path Packages/PlyneCore
swift test --package-path Packages/PlyneAnalytics

# Full app build (macOS only)
xcodebuild -project Plyne.xcodeproj \
  -scheme Plyne \
  -configuration Debug \
  -destination 'platform=macOS' \
  build

# Run all macOS tests
xcodebuild -project Plyne.xcodeproj \
  -scheme Plyne \
  -destination 'platform=macOS' \
  test

# Release archive (used by .github/workflows/release.yml)
xcodebuild -project Plyne.xcodeproj \
  -scheme Plyne \
  -configuration Release \
  -archivePath build/Plyne.xcarchive \
  archive
```

Lint runs on Linux via SwiftLint (`.swiftlint.yml` at repo root once added).

## Code style

- **SwiftUI-first.** Reach for AppKit only where SwiftUI cannot do it (status item interop, low-level event taps). Wrap AppKit pieces in `NSViewRepresentable` / `NSViewControllerRepresentable` so the surface stays SwiftUI.
- **Strict concurrency.** Compile with Swift 6 strict concurrency. Domain types in `PlyneCore` are `Sendable` value types. Side effects live behind protocols and are injected.
- **No singletons in domain code.** UI may use `@Environment` / `@Observable` stores; domain packages should be pure.
- **Localized strings only.** Never hardcode a user-facing string. Use the String Catalog and `String(localized:)`. Every key has both RU and EN copy that follows the tone rules.
- **No comments that restate code.** Add a comment only when the *why* is non-obvious (a HIG quirk, an accessibility-API workaround, a research-backed magic number from the concept doc).
- **No emoji in source, commits, or UI** unless the concept explicitly calls for one (e.g. the optional post-session reflection chooser). The product personality is calm, not "fun".

## Liquid Glass / UI principles (macOS 26)

- Use `MenuBarExtra` for the menu-bar surface, `.window` style for the popover.
- Apply `glassEffect(_:in:)` and the system materials (`.regularMaterial`, `.thinMaterial`, `.ultraThinMaterial`) on **navigation/control layers only** — never as the background of long-form content.
- Respect Reduce Transparency, Increase Contrast, Reduce Motion. Test with each enabled.
- Animations: 180–250 ms, easeOut. No bounce, no parallax, no decorative motion.
- One accent color from the system palette; everything else neutral.

## Git workflow

```
main  ←── tagged release merges only (v0.1.0, v0.2.0, …)
 ↑
dev   ←── all feature branches PR into here
 ↑
feat/short-slug  ←── one logical step per branch
```

- Branch names: `feat/...`, `fix/...`, `chore/...`, `docs/...`.
- Conventional-ish commit subjects: imperative mood, ≤ 72 chars, no trailing period. Body explains *why*.
- **Commit author must always be `molodykh_vitaliy <molodykh@realx.tech>`** (current `git config`). Confirm with the user before changing.
- PR template: short summary, screenshots/screencast for any UI change, manual test plan, link to the relevant step in the implementation plan.
- Release process: merge `dev` → `main`, tag `vX.Y.Z` on `main`, the `release.yml` workflow builds + uploads the artifact.

## Code review loop

After every implementation step:

1. Run pure-package tests locally (`swift test`).
2. Build the app once in Xcode and exercise the changed surface manually.
3. Launch a code-review sub-agent against the diff (use the `/review` skill or spawn an agent with subagent_type=general-purpose). The reviewer checks: correctness, concept-doc alignment (tone, anti-features), Swift 6 concurrency, accessibility, leaks/retain cycles in `@Observable` stores, missing localizations, and dead code from the just-completed step.
4. Address findings. Re-review only the changed parts.
5. Open the PR into `dev`.

Do not skip this loop "because the change is small." The concept doc enforcement (anti-features, tone) is the most common thing that slips and the cheapest to catch in review.

## Things that look reasonable but are explicitly forbidden by the concept

These come up often when implementing features. Reject them at the design step, not at review:

- Streak counters as a primary motivator (opt-in only, with 2 freeze-days/month if enabled).
- Per-user leaderboards or social comparison of any kind.
- A single "productivity score" number.
- Red/green badges marking "bad" days.
- Push notifications that nag ("you haven't opened Plyne in 3 days").
- Hardcore-mode app/site blocking that can't be turned off.
- Background telemetry of any sort.
- Electron, web views, or non-native UI shells.
- Marketing-speak in copy ("productivity", "achieve more", "mindfulness", "transform your day").

If a feature request looks like one of these, push back and quote the relevant concept section in the discussion.

## When in doubt

- For product decisions → re-read the relevant section in [.scratch/PLYNE_CONCEPT.md](.scratch/PLYNE_CONCEPT.md).
- For sequencing → check [.scratch/IMPLEMENTATION_PLAN.md](.scratch/IMPLEMENTATION_PLAN.md).
- For copy → write it as if you were describing the user's day to them, factually, without adjectives.
