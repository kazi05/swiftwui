// Intentionally empty: SwiftWUIDOM only imports globalThis declarations
// (see bridge-js.global.d.ts). This file's mere presence is required —
// JavaScriptKit's BridgeJSCommandPlugin (still in 0.59.0) only forwards `--project`
// to the tool when `bridge-js.d.ts` exists, even though the tool itself
// requires `--project` whenever *either* .d.ts file is present.
