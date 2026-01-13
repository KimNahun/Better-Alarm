//
//  BetterAlarmWidgetLiveActivity.swift
//  BetterAlarmWidget
//
//  Created by kimnahun on 1/13/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct BetterAlarmWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct BetterAlarmWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BetterAlarmWidgetAttributes.self) { context in
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

extension BetterAlarmWidgetAttributes {
    fileprivate static var preview: BetterAlarmWidgetAttributes {
        BetterAlarmWidgetAttributes(name: "World")
    }
}

extension BetterAlarmWidgetAttributes.ContentState {
    fileprivate static var smiley: BetterAlarmWidgetAttributes.ContentState {
        BetterAlarmWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: BetterAlarmWidgetAttributes.ContentState {
         BetterAlarmWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: BetterAlarmWidgetAttributes.preview) {
   BetterAlarmWidgetLiveActivity()
} contentStates: {
    BetterAlarmWidgetAttributes.ContentState.smiley
    BetterAlarmWidgetAttributes.ContentState.starEyes
}
