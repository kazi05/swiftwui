# DnD browser acceptance (manual)

Build/run: `cd Examples/DragDrop && swift package --swift-sdk swift-6.3.3-RELEASE_wasm js -c debug` + Vite dev server.

- [ ] Drag an image from Finder over the file zone → zone highlights (targeted), cursor = copy.
- [ ] Drag a .zip over the file zone → NO highlight, cursor = not-allowed (rejected state).
- [ ] Drop image → name+size in log; zone un-highlights.
- [ ] While dragging a file anywhere over the window → overlay banner appears (dragSession); leaves when drag exits window.
- [ ] Drop a file OUTSIDE any zone → page does NOT navigate away (guard).
- [ ] "Pick files…" → dialog opens; multi-select images → names in log; Cancel → no log entries, button re-click works.
- [ ] Drag "Drag me" card → card dims (isDragged); over card target → highlight; drop → log entry.
- [ ] Drag card over FILE zone → not-allowed (type mismatch both ways).
- [ ] Reorder list rows: rows shift smoothly mid-drag, drop commits new order, dragend without drop restores.
- [ ] Cross-tab: drag card into a second tab of the app → drop delivers payload.
- [ ] Mobile touch: expected NOT to work (documented HTML5 limitation).
