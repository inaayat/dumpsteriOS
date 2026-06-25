import WidgetKit
import SwiftUI
import AppIntents

struct VoiceBulletEntry: TimelineEntry {
    let date: Date
}

struct VoiceBulletProvider: TimelineProvider {
    func placeholder(in context: Context) -> VoiceBulletEntry {
        VoiceBulletEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (VoiceBulletEntry) -> Void) {
        completion(VoiceBulletEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VoiceBulletEntry>) -> Void) {
        let entry = VoiceBulletEntry(date: .now)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct DumpsterWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: VoiceBulletEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Lock Screen circular widget
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
            }
        case .accessoryRectangular:
            // Lock Screen rectangular widget
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                VStack(alignment: .leading) {
                    Text("Dumpster")
                        .font(.headline)
                    Text("Voice bullet")
                        .font(.caption)
                }
            }
        case .systemSmall:
            // Home Screen small widget
            VStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.teal)
                HStack(spacing: 4) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11))
                    Text("Voice")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(.fill.tertiary, for: .widget)
        default:
            // Fallback
            VStack(spacing: 6) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.teal)
                Text("Voice Bullet")
                    .font(.caption.weight(.medium))
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

struct DumpsterWidget: Widget {
    let kind: String = "DumpsterVoiceBullet"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VoiceBulletProvider()) { entry in
            DumpsterWidgetView(entry: entry)
                .widgetURL(URL(string: "dumpster://voice-add"))
        }
        .configurationDisplayName("Voice Bullet")
        .description("Tap to add a voice bullet to your daily dump.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}
