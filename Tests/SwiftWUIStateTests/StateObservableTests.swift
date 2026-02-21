import Testing
import Observation
@testable import SwiftWUIState

@Observable
final class TestModel {
    var count = 0
    var name = "test"
}

@Suite("State with Observable Models")
struct StateObservableTests {
    @Test("State wraps Observable model")
    func stateWrapsObservable() {
        let state = State(wrappedValue: TestModel())
        #expect(state.wrappedValue.count == 0)
        state.wrappedValue.count = 5
        #expect(state.wrappedValue.count == 5)
    }

    @Test("State projected value returns Binding to model")
    func stateProjectedValueBinding() {
        let state = State(wrappedValue: TestModel())
        let binding = state.projectedValue
        binding.wrappedValue.count = 10
        #expect(state.wrappedValue.count == 10)
    }

    @Test("Binding dynamic member lookup on AnyObject")
    func bindingDynamicMemberLookup() {
        let model = TestModel()
        let binding = Binding<TestModel>(
            get: { model },
            set: { _ in }
        )
        let countBinding: Binding<Int> = binding.count
        #expect(countBinding.wrappedValue == 0)
        countBinding.wrappedValue = 42
        #expect(model.count == 42)
    }

    @Test("Binding dynamic member lookup for String property")
    func bindingDynamicMemberLookupString() {
        let model = TestModel()
        let binding = Binding<TestModel>(
            get: { model },
            set: { _ in }
        )
        let nameBinding: Binding<String> = binding.name
        #expect(nameBinding.wrappedValue == "test")
        nameBinding.wrappedValue = "updated"
        #expect(model.name == "updated")
    }

    @Test("StateStorage preserves identity across struct copies")
    func stateStorageIdentity() {
        let state1 = State(wrappedValue: TestModel())
        var state2 = state1  // Copy the struct
        state2.wrappedValue.count = 99
        // Both should see the change because StateStorage is a reference type
        #expect(state1.wrappedValue.count == 99)
    }
}
