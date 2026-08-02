import WidgetKit
import SwiftUI

// ── Constants ─────────────────────────────────────────────────────────────

private let appGroupSuite = "group.com.mode.app"
private let promptKey     = "mode_widget_prompt"
private let streakKey     = "mode_widget_streak"

private let fallbackPrompts = [
    "What happened today worth naming?",
    "Was there a moment today when you felt small or unsafe?",
    "What did you avoid today — and what were you protecting?",
    "Did anything today feel familiar, in a hard way?",
    "Was there a moment you wanted to shrink or disappear?",
    "What felt hard today, even if it seemed unreasonable?",
    "Did you find yourself working to earn something that should be freely given?",
    "What's one thing from today you don't want to forget?",
]

// ── Timeline Model ────────────────────────────────────────────────────────

struct ModeEntry: TimelineEntry {
    let date: Date
    let prompt: String
    let streak: Int
}

// ── Provider ──────────────────────────────────────────────────────────────

struct ModeProvider: TimelineProvider {

    func placeholder(in context: Context) -> ModeEntry {
        ModeEntry(date: Date(), prompt: "What happened today worth naming?", streak: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (ModeEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ModeEntry>) -> Void) {
        // Refresh once a day at midnight so the prompt can rotate
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        completion(Timeline(entries: [loadEntry()], policy: .after(midnight)))
    }

    private func loadEntry() -> ModeEntry {
        let defaults  = UserDefaults(suiteName: appGroupSuite)
        let dayIndex  = Calendar.current.component(.weekday, from: Date()) % fallbackPrompts.count
        let prompt    = defaults?.string(forKey: promptKey) ?? fallbackPrompts[dayIndex]
        let streak    = defaults?.integer(forKey: streakKey) ?? 0
        return ModeEntry(date: Date(), prompt: prompt, streak: streak)
    }
}

// ── Widget View ───────────────────────────────────────────────────────────

struct ModeWidgetView: View {
    var entry: ModeProvider.Entry
    @Environment(\.widgetFamily) var family

    // Design tokens mirroring the RN app's theme.ts
    let bg       = Color(red: 15/255,  green: 15/255,  blue: 20/255)
    let surface  = Color(red: 24/255,  green: 24/255,  blue: 31/255)
    let accent   = Color(red: 139/255, green: 127/255, blue: 212/255)
    let primary  = Color(red: 240/255, green: 238/255, blue: 248/255)
    let muted    = Color(red: 90/255,  green: 88/255,  blue: 104/255)
    let border   = Color(red: 42/255,  green: 42/255,  blue: 56/255)

    var body: some View {
        ZStack(alignment: .topLeading) {
            bg

            // Left accent bar
            Rectangle()
                .fill(accent.opacity(0.6))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 0) {
                // Top row: branding + streak
                HStack(alignment: .center, spacing: 4) {
                    Text("MODE")
                        .font(.system(size: 9, weight: .bold, design: .default))
                        .tracking(1.5)
                        .foregroundColor(accent)
                    Spacer()
                    if entry.streak > 0 {
                        HStack(spacing: 3) {
                            Text("↑")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(accent)
                            Text("\(entry.streak)d")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(accent)
                        }
                    }
                }
                .padding(.bottom, 10)

                // Prompt
                Text(entry.prompt)
                    .font(.system(
                        size: family == .systemSmall ? 13 : 15,
                        weight: .medium,
                        design: .default
                    ))
                    .foregroundColor(primary)
                    .lineSpacing(3.5)
                    .lineLimit(family == .systemSmall ? 5 : 4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                // CTA
                Text("Tap to reflect  →")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(muted)
            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .padding(.vertical, 14)
        }
    }
}

// ── Widget Configuration ──────────────────────────────────────────────────

@main
struct ModeWidget: Widget {
    let kind = "ModeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ModeProvider()) { entry in
            if #available(iOS 17.0, *) {
                ModeWidgetView(entry: entry)
                    .containerBackground(
                        Color(red: 15/255, green: 15/255, blue: 20/255),
                        for: .widget
                    )
            } else {
                ModeWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Mode")
        .description("Your daily reflection prompt.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ── Preview ───────────────────────────────────────────────────────────────

#Preview(as: .systemSmall) {
    ModeWidget()
} timeline: {
    ModeEntry(date: .now, prompt: "What happened today worth naming?", streak: 4)
}

#Preview(as: .systemMedium) {
    ModeWidget()
} timeline: {
    ModeEntry(date: .now, prompt: "Was there a moment today when you felt small, unsafe, or defensive?", streak: 12)
}
