// ScrollyStepRegistry.swift — bridges ScrollyTeller's current step
// state to the TutorialTopBar's section picker. Updated by
// ScrollyTeller's mount-side JS in Phase 5.

public enum ScrollyStepRegistry {
    nonisolated(unsafe) public static var titles: [String] = []
    nonisolated(unsafe) public static var currentStep: Int = 1
}
