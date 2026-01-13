//
//  BetterAlarmWidgetBundle.swift
//  BetterAlarmWidget
//
//  Created by kimnahun on 1/13/26.
//

import WidgetKit
import SwiftUI

@main
struct BetterAlarmWidgetBundle: WidgetBundle {
    var body: some Widget {
        BetterAlarmWidget()
        BetterAlarmWidgetLiveActivity()
    }
}
