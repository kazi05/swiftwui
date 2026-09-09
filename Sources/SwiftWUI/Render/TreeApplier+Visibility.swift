extension TreeApplier {
    func registerVisibility(_ mounted: MountedNode<Backend.HostNode>) {
        if let id = mounted.elementIdentity {
            elementIndex[id] = mounted
        }
        if !mounted.visibilityRequests.isEmpty || !mounted.visibilityBindings.isEmpty {
            visibilityTargets[ObjectIdentifier(mounted)] = mounted
        }
    }

    func unregisterVisibility(_ mounted: MountedNode<Backend.HostNode>) {
        if let id = mounted.elementIdentity, elementIndex[id] === mounted {
            elementIndex[id] = nil
        }
        visibilityTargets[ObjectIdentifier(mounted)] = nil
        let bindings = Array(mounted.visibilityBindings.values)
        mounted.visibilityBindings.removeAll()
        for binding in bindings {
            binding.cancel?()
        }
    }

    func cancelVisibility() {
        visibilityEnabled = false
        for target in Array(visibilityTargets.values) {
            unregisterVisibility(target)
        }
        elementIndex.removeAll()
    }

    func commitVisibility() {
        guard visibilityEnabled else { return }

        for mounted in Array(visibilityTargets.values) {
            let desired = Set(mounted.visibilityRequests.map(\.id))
            for id in Array(mounted.visibilityBindings.keys) where !desired.contains(id) {
                let old = mounted.visibilityBindings.removeValue(forKey: id)
                old?.cancel?()
            }

            for request in mounted.visibilityRequests {
                let rootMount: MountedNode<Backend.HostNode>?
                let backendRoot: VisibilityObserverRoot<Backend.HostNode>
                switch request.root {
                case .viewport:
                    rootMount = nil
                    backendRoot = .viewport
                case .unavailable:
                    rootMount = nil
                    backendRoot = .unavailable
                case .ancestor(let id):
                    rootMount = elementIndex[id]
                    if let host = rootMount?.host {
                        backendRoot = .ancestor(host)
                    } else {
                        backendRoot = .unavailable
                    }
                }

                let rootGeneration = rootMount.map(ObjectIdentifier.init)
                if let active = mounted.visibilityBindings[request.id],
                   active.request == request,
                   active.rootGeneration == rootGeneration {
                    continue
                }

                let old = mounted.visibilityBindings.removeValue(forKey: request.id)
                old?.cancel?()
                visibilityGeneration += 1
                let generation = visibilityGeneration
                mounted.visibilityBindings[request.id] = .init(
                    generation: generation,
                    request: request,
                    rootGeneration: rootGeneration,
                    rootHost: rootMount?.host,
                    cancel: nil
                )

                let deliver: (Bool) -> Void = { [weak self, weak mounted] value in
                    self?.scheduleVisibility? { [weak self, weak mounted] in
                        guard let self, let mounted, self.visibilityEnabled,
                              mounted.visibilityBindings[request.id]?.generation == generation
                        else { return }
                        self.dispatchVisibility?(request.id, value)
                    }
                }

                let cancel = backend.observeVisibility(
                    mounted.host!, root: backendRoot, threshold: request.threshold,
                    rootMargin: request.margin, onChange: deliver
                )
                mounted.visibilityBindings[request.id]?.cancel = cancel
                if case .unavailable = backendRoot, cancel != nil {
                    deliver(false)
                }
            }

            if mounted.visibilityRequests.isEmpty {
                visibilityTargets[ObjectIdentifier(mounted)] = nil
            }
        }
    }
}
