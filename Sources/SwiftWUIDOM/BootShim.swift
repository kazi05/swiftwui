import SwiftWUI
#if arch(wasm32)
import JavaScriptKit

/// Swift's half of the boot hand-off (spec §7). The JS half is
/// `swiftwui-boot.js`, which owns `<html data-swui-boot>` and the shell's
/// state machine; this side only clears the markup before the renderer looks
/// at the DOM.
@MainActor
enum BootShim {
    /// Removes every boot-only node and drops every veil attribute.
    ///
    /// MUST run before `AdoptingBackend` is constructed: it snapshots the
    /// container's subtree at init, and boot nodes do not exist in the tree
    /// Swift builds, so a single extra sibling diverges the adoption stream and
    /// the whole page cold-boots. It must also run before the cold-boot
    /// fallback, whose container wipe would leave head-level boot markup
    /// standing.
    ///
    /// Two things are deliberately left alone:
    ///
    /// - `<style data-swui-boot>` — the page can still enter `failed` after
    ///   mount (a trap during the first render), and the shim re-instantiates
    ///   the boot templates from retained references (spec §6.4). Without the
    ///   stylesheet that failure UI would be unstyled.
    /// - `<html data-swui-boot>` — the shim's own state flag, dropped by the
    ///   shim once `init()` resolves. While it is up the veil rule still
    ///   applies, which is why dropping the veil ATTRIBUTES here reveals the
    ///   real content in this same paintless turn.
    ///
    /// Both boot markup and a boot config are independent: a build with no wasm
    /// stamp ships the shell markup with the legacy inline boot and no shim at
    /// all, so nothing here may assume the shim ran.
    static func stripBootNodes() {
        let document = JSObject.global.document
        // `[data-swui-boot-ui]`, NOT `[data-swui-boot]`: the latter also matches
        // `<html>` (the shim's state flag) and `<style>` (the boot stylesheet),
        // and would try to remove the document element. The `-ui` marker is
        // carried by the `<template>` elements AND by the clones the shim
        // inserts beside them, which is exactly the set that must go.
        // Chained `.whileBooting` yields a template carrying both markers; it
        // matches here and is gone before the veil pass runs.
        let ui = document.querySelectorAll("[data-swui-boot-ui]").object
        for i in (0..<Int(ui?.length.number ?? 0)).reversed() {
            _ = ui?[i].object?.remove?()
        }
        // The veil is stamped on real adopted elements in the BUILD render only,
        // so it appears in neither VDOM and the applier never diffs it. What
        // makes it load-bearing to drop is the FAILED path: the shim re-sets
        // `<html data-swui-boot>` on a trap after mount, and a leftover veil
        // attribute would then hide every veiled element of the live page
        // underneath the failure UI. Do not delete this loop.
        let veiled = document.querySelectorAll("[data-swui-boot-veil]").object
        for i in (0..<Int(veiled?.length.number ?? 0)).reversed() {
            _ = veiled?[i].object?.removeAttribute?("data-swui-boot-veil")
        }
    }
}
#endif
