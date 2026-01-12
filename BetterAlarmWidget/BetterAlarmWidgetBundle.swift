import WidgetKit
import SwiftUI

@main
struct BetterAlarmWidgetBundle: WidgetBundle {
    var body: some Widget {
        BetterAlarmWidget()
        BetterAlarmLiveActivity()
    }
}
