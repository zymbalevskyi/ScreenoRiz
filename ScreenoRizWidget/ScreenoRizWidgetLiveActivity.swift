//
//  ScreenoRizWidgetLiveActivity.swift
//  ScreenoRizWidget
//
//  Created by Yevhen on 11.04.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ScreenoRizWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ScreenoRizWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScreenoRizWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ScreenoRizWidgetAttributes {
    fileprivate static var preview: ScreenoRizWidgetAttributes {
        ScreenoRizWidgetAttributes(name: "World")
    }
}

extension ScreenoRizWidgetAttributes.ContentState {
    fileprivate static var smiley: ScreenoRizWidgetAttributes.ContentState {
        ScreenoRizWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ScreenoRizWidgetAttributes.ContentState {
         ScreenoRizWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ScreenoRizWidgetAttributes.preview) {
   ScreenoRizWidgetLiveActivity()
} contentStates: {
    ScreenoRizWidgetAttributes.ContentState.smiley
    ScreenoRizWidgetAttributes.ContentState.starEyes
}
