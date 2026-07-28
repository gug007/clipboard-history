import Foundation
import Observation

@Observable
final class PanelState {
    var isPaused: Bool = false
    var pauseUntil: Date?
}
