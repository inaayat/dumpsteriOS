import WidgetKit
import SwiftUI

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
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "trash.fill")
                    .font(.system(size: 18))
            }
            .widgetURL(URL(string: "dumpster://voice-bullet")!)
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14))
                VStack(alignment: .leading) {
                    Text("Dumpster")
                        .font(.headline)
                    Text("Voice bullet")
                        .font(.caption)
                }
            }
            .widgetURL(URL(string: "dumpster://voice-bullet")!)
        case .systemSmall:
            VStack(spacing: 6) {
                Image("DumpsterIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                HStack(spacing: 3) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 10))
                    Text("Voice Bullet")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "dumpster://voice-bullet")!)
        default:
            VStack(spacing: 6) {
                Image("DumpsterIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                Text("Voice Bullet")
                    .font(.caption.weight(.medium))
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(URL(string: "dumpster://voice-bullet")!)
        }
    }
}

struct DumpsterWidget: Widget {
    let kind: String = "DumpsterVoiceBullet"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VoiceBulletProvider()) { entry in
            DumpsterWidgetView(entry: entry)
        }
        .configurationDisplayName("Voice Bullet")
        .description("Tap to add a voice bullet to your daily dump.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}
