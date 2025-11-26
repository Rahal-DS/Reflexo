//
//  ReflexoWidget.swift
//  ReflexoWidgetExtension
//

import WidgetKit
import SwiftUI
import SwiftData

struct ReflexoEntry: TimelineEntry {
    let date: Date
    let scores: [String: Int]
}

struct Provider: TimelineProvider {
    
    func placeholder(in context: Context) -> ReflexoEntry {
        ReflexoEntry(date: .now, scores: [:])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ReflexoEntry) -> Void) {
        let scores = fetchBestScoresFromSwiftData()
        completion(ReflexoEntry(date: .now, scores: scores))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReflexoEntry>) -> Void) {
        let scores = fetchBestScoresFromSwiftData()
        let entry = ReflexoEntry(date: .now, scores: scores)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    
    private func fetchBestScoresFromSwiftData() -> [String: Int] {
        let defaults = UserDefaults(suiteName: "group.com.ReflexoShared")
        var results: [String: Int] = [:]
        for key in ["ReactionTime", "AimTrainer", "PatternRecognition", "VerbalMemory"] {
            results[key] = defaults?.integer(forKey: "\(key)_lastScore") ?? 0
        }
        return results
    }
}

struct ReflexoWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            Color("DarkOlive").ignoresSafeArea()
            VStack(alignment: .leading, spacing: 6) {
                Text("Reflexo High Scores")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                ForEach(["ReactionTime", "AimTrainer", "PatternRecognition", "VerbalMemory"], id: \.self) { key in
                    HStack {
                        Text(label(for: key))
                        Spacer()
                        Text(format(score: entry.scores[key], for: key))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding()
        }
    }

    private func label(for key: String) -> String {
        switch key {
        case "ReactionTime": return "Reaction Time"
        case "AimTrainer": return "Aim Trainer"
        case "PatternRecognition": return "Pattern Recognition"
        case "VerbalMemory": return "Verbal Memory"
        default: return key
        }
    }

    private func format(score: Int?, for key: String) -> String {
        guard let s = score else { return "—" }
        switch key {
        case "ReactionTime": return "\(s) ms"
        case "AimTrainer":
            let seconds = Double(s) / 1000.0
            return String(format: " %.2f seconds", seconds)
        case "PatternRecognition": return "Level \(s)"
        case "VerbalMemory": return "\(s) words"
        default: return "\(s)"
        }
    }
}

@main
struct ReflexoWidget: Widget {
    let kind = "ReflexoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ReflexoWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color("DarkOlive")
                }
        }
        .configurationDisplayName("Reflexo High Scores")
        .description("View your best scores for all games.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    ReflexoWidget()
} timeline: {
    ReflexoEntry(
        date: .now,
        scores: [
            "ReactionTime": 180,
            "AimTrainer": 14000,
            "PatternRecognition": 5,
            "VerbalMemory": 32
        ]
    )
}


