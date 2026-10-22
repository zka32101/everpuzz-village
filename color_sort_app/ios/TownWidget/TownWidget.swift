import SwiftUI
import WidgetKit

// ホーム画面ウィジェット(町の絵)。アプリが App Group に書き出した PNG を見せる。
// App Group 名は Runner / TownWidget の両方の Capabilities に同じ値を入れる(README 参照)。
private let appGroup = "group.com.petitworksapps.colorsortapp"
private let fileName = "town_widget.png"

struct TownEntry: TimelineEntry {
    let date: Date
    let image: UIImage?
}

struct TownProvider: TimelineProvider {
    private func load() -> UIImage? {
        guard let dir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup) else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(fileName).path)
    }

    func placeholder(in context: Context) -> TownEntry { TownEntry(date: Date(), image: nil) }

    func getSnapshot(in context: Context, completion: @escaping (TownEntry) -> Void) {
        completion(TownEntry(date: Date(), image: load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TownEntry>) -> Void) {
        // 更新はアプリ側が WidgetCenter.reloadAllTimelines() で知らせる。
        completion(Timeline(entries: [TownEntry(date: Date(), image: load())], policy: .never))
    }
}

struct TownWidgetView: View {
    let entry: TownEntry
    var body: some View {
        ZStack {
            Color(red: 0.91, green: 0.95, blue: 0.89)
            if let image = entry.image {
                Image(uiImage: image).resizable().scaledToFill()
                    .accessibilityLabel("あなたの町")
            }
        }
    }
}

@main
struct TownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TownWidget", provider: TownProvider()) { entry in
            if #available(iOS 17.0, *) {
                TownWidgetView(entry: entry).containerBackground(.fill, for: .widget)
            } else {
                TownWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("あなたの町")
        .description("町の様子をホーム画面で見られます。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
