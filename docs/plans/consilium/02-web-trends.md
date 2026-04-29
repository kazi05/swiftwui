# Web Framework Trends 2024–2026: What SwiftWUI Should Adopt

> Based on: Svelte 5 (Oct 2024), React 19, Vue 3.5 Vapor, Solid 1.x signals, Qwik 2.x, Astro 4.x, Next.js 15, Tailwind v4, CSS Cascade Layers / Container Queries / Anchor Positioning (all-browser 2023–2025), View Transitions API, HTMX 2.x, Tanstack Form v1, Conform v1, Playwright Component Testing stable.
> SwiftWUI source read: `Reconciler.swift`, `DOMRenderer.swift`, `Application.swift`, `StyleSheetManager.swift`, `ModifiedContent.swift`, `Router.swift`, `Route.swift`, `StateStorage` (`@Observable`-backed), `DOMBridge.swift`, `TagNodeConvertible.swift`.

---

## 1. Fine-Grained Reactivity vs Virtual DOM

**Trend.** Svelte 5 runes (`$state`, `$derived`, `$effect`), Solid signals, Vue Vapor bypass virtual DOM diffing entirely. On state mutation, only DOM nodes that read that specific signal update — no tree traversal, no component re-execution.

**Why it matters.** Every state change runs entire `resolveTagBody` chain plus `Reconciler.diff(old:new:)` over full tree. WASM has non-trivial overhead per JS boundary crossing, so O(n) Swift walk plus O(k) DOM patch calls is main bottleneck as apps grow.

**Recommendation: hybrid opt-in.** Swift's `@Observable` / `withObservationTracking` is already a signal system — `StateStorage<Value>` tracks reads at property granularity. Gap: `onChange` in `Application.mount()` always re-renders whole tree. Add opt-in `SignalNode`:

```swift
final class SignalNode {
    let stableID: String
    let render: () -> TagNode
    var currentNode: TagNode
    weak var domNode: JSObject?

    func update() {
        let newNode = render()
        guard let patch = Reconciler().diff(old: currentNode, new: newNode),
              let dom = domNode else { return }
        applyPatch(patch, to: dom)
        currentNode = newNode
    }
}
```

`onChange` callback targets only `SignalNode` instances whose `StateStorage` was accessed during last read pass, not global `renderCycle()`. Keep reconciler as default; introduce `@SignalState` opt-in for leaf components doing rapid updates.

**Tradeoff.** Per-node identity (`data-swui-id`) overhead. Vue Vapor model — opt-in per component — is right balance.

---

## 2. Resumability / Qwik Model

**Trend.** Qwik 2.x serializes app state + event handler closures into HTML. Client "resumes", not re-hydrates. Zero JS executes until first user event.

**Why it matters.** WASM bundle is large. Resumability defers `.wasm` load until first interaction → faster TTI.

**Recommendation: future, blocked on SSR.** `Application.mount()` needs `mountResumable()` variant that skips `renderer.render()` if DOM is pre-rendered, re-attaches listeners via `data-swiftwui-id` walk. Dependency order: SSR → Islands → Resumability.

---

## 3. Islands Architecture

**Trend.** Astro 4.x: zero JS by default, `client:visible/idle/load` annotations hydrate only interactive islands.

**Recommendation:** `Island<Content>` boundary tag with `HydrationStrategy`. Server emits `<div data-swiftwui-island="id">` with pre-rendered HTML. JS bootstrap watches `IntersectionObserver`, loads sub-bundle on demand. Each island = separate executable target. Blocked on build orchestration in `swiftwui-init`.

---

## 4. React Server Components / Streaming SSR

**Trend.** React 19 RSC stable: `async` server-only components stream HTML chunks. `use server` / `use client` annotations split tree across network.

**Recommendation: isolate in `SwiftWUIVapor` optional product.** Define `ServerTag` Vapor-side protocol bypassing TagNode pipeline:

```swift
protocol ServerTag {
    func renderHTML() async throws -> String
}

struct UserProfileTag: ServerTag {
    let userID: String
    func renderHTML() async throws -> String {
        let user = try await db.find(User.self, id: userID)
        return "<div class='profile'>\(user.name)</div>"
    }
}
```

Vapor streams via `HTTPResponse.body = .stream(...)`. WASM client never imports `ServerTag`.

---

## 5. Server Actions / Form-Driven Mutations

**Trend.** Next.js 14+, Remix 2.x: HTML forms `action` → server functions. Works without JS, enhances with optimistic updates.

**Recommendation:** Expose `action`/`method` on `Form` tag. Infrastructure exists (`ModifiedContent.attribute()` already works). Just first-class init params:

```swift
Form(action: "/api/signup", method: .post) {
    Input(name: "email", type: .email)
    Button(type: .submit) { "Sign Up" }
}
```

Zero new infra. Document as progressive-enhancement baseline.

---

## 6. View Transitions API

**Trend.** `document.startViewTransition()` wraps DOM mutations in cross-fade or custom anim. `view-transition-name` enables matched-element morphing. All major browsers 2025.

**Recommendation:** Wrap in `DOMBridge`:

```swift
public func startViewTransition(_ callback: @escaping () -> Void) {
    guard JSObject.global.document.object!.startViewTransition != nil else {
        callback(); return
    }
    let closure = JSOneshotClosure { _ in callback(); return .undefined }
    _ = JSObject.global.document.object!.startViewTransition!(closure)
}
```

In `Application.mount()`, wrap update path's `renderCycle()` in `bridge.startViewTransition`. Add `.viewTransitionName(String)` modifier.

---

## 7. CSS Innovations

**Trends.** Tailwind v4 (CSS-native, zero runtime). Container Queries (`@container`, all browsers 2023+). Cascade Layers (`@layer`, all browsers 2022+). Anchor Positioning (`anchor()`, Chrome 125+, Safari 18+). `@scope` (Chrome 118+).

**Recommendation:**
1. Extend `MediaQuery` with container/layer cases — `StyleSheetManager.ensureClass(mediaQuery:styles:)` accepts arbitrary CSS strings already.
2. Replace `!important` in `cssRuleText` with `@layer utilities` wrapping. Prevents specificity wars.
3. Expose CSS custom properties as theme tokens (see §15).

---

## 8. HTMX / Hypermedia

**Recommendation: attribute convenience wrappers only.** `.attribute(name:value:)` already handles. Add typed `HTMX` namespace as syntactic sugar for discoverability. No new infra.

```swift
Button { "Load More" }
    .attribute("hx-get", "/api/items?page=2")
    .attribute("hx-target", "#item-list")
```

---

## 9. Accessibility-First

**Recommendation:**
- Typed ARIA modifier extension over `.attribute()`:

```swift
extension Tag {
    public func aria(label: String) -> ModifiedContent<Self> { attribute("aria-label", label) }
    public func aria(role: ARIARole) -> ModifiedContent<Self> { attribute("role", role.rawValue) }
    public func aria(live: ARIALive) -> ModifiedContent<Self> { attribute("aria-live", live.rawValue) }
}
enum ARIARole: String { case button, dialog, navigation, main, region, status }
enum ARIALive: String { case off, polite, assertive }
```

- Enforce `alt` at type level on `Image`: `Image(src: String, alt: String)` — required param, not modifier.

---

## 10. Routing

**Recommendation — three additions:**
1. **Nested layouts.** `Route` gains `layout` wrapper. Renderer preserves layout tree, only diffs inner slot.
2. **`Link` tag.** Semantic `<a>` calling `router.navigate(to:)` + `DOMBridge.pushState(path:)`.
3. **`@QueryParam` property wrapper.** Backed by `URLSearchParams`, observable like `StateStorage`.

```swift
@QueryParam("page") var page: Int = 1
```

---

## 11. Forms

**Recommendation:** `FormState<Schema>` backed by `@Observable`:

```swift
@Observable
final class FormState<Schema> {
    var values: Schema
    var errors: [String: String] = [:]
    var isSubmitting = false
}

@State var form = FormState(values: SignupValues())
Input(value: Binding(get: { form.values.email }, set: { form.values.email = $0 }), type: .email)
    .aria(invalid: form.errors["email"] != nil)
```

Field mutations only trigger re-renders for observing inputs.

---

## 12. Testing

**Two tiers.** Tier 1 (exists): native Swift tests on `TagNode` output. Tier 2 (add): `swiftwui test` CLI builds WASM, starts Vite, runs Playwright. Add `TagNode` HTML serialization helper:

```swift
func assertSnapshot<T: Tag>(_ tag: T, name: String) {
    let nodes = resolveTagBody(tag)
    let html = nodes.map(\.htmlString).joined()
    // compare against Tests/__Snapshots__/name.html
}
```

---

## 13. DevTools

**Recommendation:** `window.__swiftwui_devtools` global populated by `DOMRenderer` in debug builds. Browser extension reads it, renders component tree, state inspector, time-travel via stored `TagNode` snapshots.

```swift
#if DEBUG
JSObject.global.__swiftwui_devtools = .object(devToolsPayload(currentTree, lastPatch))
#endif
```

---

## 14. i18n

**Recommendation:** `@Observable Localization` singleton + build plugin. `LocalizedText("key")` reads JSON string table. Locale change = single `@Observable` mutation triggers full re-render. Build plugin scans sources, emits `.lproj`-style JSON tables.

---

## 15. Dark Mode / Theming

**Why it matters.** `MediaQuery.colorScheme(.dark)` already in `MediaQuery.swift`. Gap: token abstraction.

**Recommendation:**

```swift
public protocol Theme {
    var background: CSSColor { get }
    var foreground: CSSColor { get }
    var accent: CSSColor { get }
}

func applyTheme(_ light: Theme, dark: Theme) {
    appendCSSRule(styleElement!, rule: ":root { \(light.cssVars) }")
    appendCSSRule(styleElement!, rule:
        "@media (prefers-color-scheme: dark) { :root { \(dark.cssVars) } }"
    )
}
```

Style modifiers reference tokens: `.backgroundColor(.token("background"))` → `var(--background)`.

---

## Priority Matrix

| Area | Effort | Impact | Phase |
|---|---|---|---|
| View Transitions §6 | Low | High | Now — `DOMBridge` hooks exist |
| ARIA modifiers §9 | Low | High | Now — pure `.attribute()` wrappers |
| `Link` tag + `@QueryParam` §10 | Low | High | Now — Router exists |
| CSS Container/Layers §7 | Low | Medium | Now — `StyleSheetManager` accepts raw |
| Theme tokens §15 | Low | High | Now — `StyleSheetManager` + `MediaQuery` ready |
| Progressive forms §5 | Low | Medium | Now |
| `FormState<Schema>` §11 | Medium | High | Next quarter |
| Nested layouts §10 | Medium | Medium | Next quarter |
| Signal-based reactivity §1 | High | High | After stable base |
| SSR + Vapor §4 | High | High | Long term |
| Islands §3 | High | High | After SSR |
| Resumability §2 | Very High | High | After Islands |
| DevTools extension §13 | Medium | Medium | After stable base |
| i18n §14 | Low | Medium | On demand |
| HTMX wrappers §8 | Low | Low | On demand |

Top six rows extend existing infrastructure with zero new modules — recommended immediate scope.
