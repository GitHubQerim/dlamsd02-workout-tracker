import WidgetKit
import SwiftUI

@main
struct WorkoutTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextWorkoutWidget()
        HeatmapWidget()
        WorkoutSessionLiveActivity()
    }
}
