import Foundation

struct HTMLTemplate {
    let target: String

    func devHTML(port: Int) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(target) — SwiftWUI Dev</title>
            <script type="module">
                import { init } from "./\(target).js";
                init();
            </script>
        </head>
        <body>
            <div id="app"></div>
            \(devClientScript(port: port))
        </body>
        </html>
        """
    }

    func productionHTML() -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(target)</title>
            <script type="module">
                import { init } from "./\(target).js";
                init();
            </script>
        </head>
        <body>
            <div id="app"></div>
        </body>
        </html>
        """
    }

    private func devClientScript(port: Int) -> String {
        """
        <script>
        (function() {
            var overlay = null;
            var indicator = null;
            // Track the manifest from the previous successful rebuild. The
            // server sends `{type:'reload', manifest:{file:sha256}}` on
            // every rebuild; we only call `location.reload()` if at least
            // one artefact's hash actually differs. fswatch routinely fires
            // multiple events for a single save, so this collapses bursts.
            var lastManifest = null;

            function connect() {
                var ws = new WebSocket('ws://localhost:\(port)/_dev');
                ws.onopen = function() {
                    console.log('[SwiftWUI] Dev server connected');
                    if (overlay) { overlay.remove(); overlay = null; }
                    if (indicator) { indicator.remove(); indicator = null; }
                };
                ws.onmessage = function(e) {
                    var msg = JSON.parse(e.data);
                    if (msg.type === 'reload') {
                        if (overlay) { overlay.remove(); overlay = null; }
                        if (indicator) { indicator.remove(); indicator = null; }
                        if (msg.manifest && lastManifest && manifestsEqual(msg.manifest, lastManifest)) {
                            console.log('[SwiftWUI] Rebuild produced identical artefacts — skipping reload.');
                            lastManifest = msg.manifest;
                            return;
                        }
                        lastManifest = msg.manifest || null;
                        location.reload();
                    } else if (msg.type === 'building') {
                        showIndicator('Rebuilding...');
                    } else if (msg.type === 'error') {
                        showErrorOverlay(msg.message);
                    }
                };
                ws.onclose = function() {
                    console.log('[SwiftWUI] Disconnected, reconnecting...');
                    setTimeout(connect, 2000);
                };
            }

            function manifestsEqual(a, b) {
                var ak = Object.keys(a), bk = Object.keys(b);
                if (ak.length !== bk.length) return false;
                for (var i = 0; i < ak.length; i++) {
                    if (a[ak[i]] !== b[ak[i]]) return false;
                }
                return true;
            }

            function showIndicator(text) {
                if (!indicator) {
                    indicator = document.createElement('div');
                    indicator.style.cssText = 'position:fixed;top:8px;right:8px;background:#333;color:#fff;padding:6px 12px;border-radius:6px;font:12px system-ui;z-index:99999;opacity:0.9';
                    document.body.appendChild(indicator);
                }
                indicator.textContent = text;
            }
            function showErrorOverlay(message) {
                if (indicator) { indicator.remove(); indicator = null; }
                if (!overlay) {
                    overlay = document.createElement('div');
                    overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.85);color:#ff6b6b;font:14px/1.6 monospace;padding:32px;overflow:auto;z-index:99999;white-space:pre-wrap';
                    document.body.appendChild(overlay);
                }
                overlay.textContent = 'Build Error:\\n\\n' + message;
            }
            connect();
        })();
        </script>
        """
    }
}
