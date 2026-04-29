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
                    if (overlay && overlay.dataset.kind === 'connection') {
                        overlay.remove(); overlay = null;
                    }
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
                        showOverlay('build', 'Build error', msg.message);
                    }
                };
                ws.onclose = function() {
                    console.log('[SwiftWUI] Disconnected, reconnecting...');
                    setTimeout(connect, 2000);
                };
            }

            // Capture runtime errors in the WASM client. window.onerror catches
            // synchronous exceptions, including WASM traps that surface as
            // JavaScript Error objects. unhandledrejection catches awaits
            // (and Swift Tasks) that throw without a handler. We surface both
            // through the same overlay infrastructure used for build errors,
            // distinguished by the `kind` parameter.
            window.addEventListener('error', function(ev) {
                var stack = (ev.error && ev.error.stack) ? ev.error.stack : '';
                var msg = (ev.message || 'Unknown error');
                if (ev.filename) {
                    msg += '\\n\\nat ' + ev.filename + ':' + ev.lineno + ':' + ev.colno;
                }
                if (stack) { msg += '\\n\\n' + stack; }
                showOverlay('runtime', 'Runtime error', msg);
            });
            window.addEventListener('unhandledrejection', function(ev) {
                var reason = ev.reason;
                var msg = '';
                if (reason instanceof Error) {
                    msg = reason.message + (reason.stack ? '\\n\\n' + reason.stack : '');
                } else if (typeof reason === 'string') {
                    msg = reason;
                } else {
                    try { msg = JSON.stringify(reason); }
                    catch (_) { msg = String(reason); }
                }
                showOverlay('rejection', 'Unhandled promise rejection', msg);
            });

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
            // Render an error overlay. `kind` is 'build' / 'runtime' /
            // 'rejection' — the colour and header reflect which subsystem
            // surfaced the error. `kind === 'build'` overlays are
            // dismissed automatically on the next successful rebuild;
            // 'runtime' / 'rejection' overlays carry an explicit
            // dismiss button so the developer can keep interacting with
            // the page after acknowledging the error.
            function showOverlay(kind, title, message) {
                if (indicator) { indicator.remove(); indicator = null; }
                if (overlay) { overlay.remove(); overlay = null; }

                overlay = document.createElement('div');
                overlay.dataset.kind = kind;
                var color = (kind === 'build') ? '#ff6b6b'
                    : (kind === 'runtime') ? '#ffa057'
                    : '#ffd166';
                overlay.style.cssText = [
                    'position:fixed;inset:0;background:rgba(0,0,0,0.88);',
                    'color:' + color + ';font:13px/1.5 ui-monospace,SFMono-Regular,monospace;',
                    'padding:32px;overflow:auto;z-index:2147483647;white-space:pre-wrap;'
                ].join('');

                var header = document.createElement('div');
                header.style.cssText = 'font:bold 16px ui-sans-serif,system-ui;color:#fff;margin-bottom:16px;';
                header.textContent = title;
                overlay.appendChild(header);

                var body = document.createElement('pre');
                body.style.cssText = 'margin:0;white-space:pre-wrap;color:' + color + ';';
                body.textContent = message;
                overlay.appendChild(body);

                if (kind !== 'build') {
                    var btn = document.createElement('button');
                    btn.textContent = 'Dismiss';
                    btn.style.cssText = [
                        'position:fixed;top:16px;right:16px;background:#fff;color:#000;',
                        'border:0;border-radius:6px;padding:8px 14px;font:12px ui-sans-serif;',
                        'cursor:pointer;z-index:2147483647;'
                    ].join('');
                    btn.onclick = function() {
                        if (overlay) { overlay.remove(); overlay = null; }
                    };
                    overlay.appendChild(btn);
                }

                document.body.appendChild(overlay);
            }
            connect();
        })();
        </script>
        """
    }
}
