import WidgetKit
import SwiftUI

@main
struct DumpsterWidgetBundle: WidgetBundle {
    var body: some Widget {
        DumpsterWidget()
        VoiceBulletControl()
    }
}
