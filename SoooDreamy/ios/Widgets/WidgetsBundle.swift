import WidgetKit
import SwiftUI

@main
struct SoooDreamyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DaysTogetherWidget()
        MoodWidget()
        CountdownWidget()
        DailyQuestionWidget()
        StreakWidget()
        PhotoWidget()
        CanvasWidget()
        SendLoveWidget()
        #if canImport(ActivityKit)
        CountdownLiveActivity()
        CouplePulseLiveActivity()
        DateNightLiveActivity()   // v3.0 date night (Agent C)
        #endif
        HeartbeatControlWidget()
        OpenNeedButtonControlWidget()
    }
}
