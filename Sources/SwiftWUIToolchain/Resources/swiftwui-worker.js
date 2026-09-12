// Import from an application-owned module worker. No DOM operations cross this
// boundary. Transfer lists move ArrayBuffer ownership; the sender is detached.
export function workerResult(value, buffers = []) { return { value, buffers }; }

export function serveWorker(handler, scope = globalThis) {
  const active = new Map();
  let compiledModule;
  const listen = async ({ data }) => {
    if (data.type === "initialize") { compiledModule = data.module; return; }
    if (data.type === "cancel") { active.get(data.id)?.abort(); return; }
    if (data.type !== "request" || active.has(data.id)) return;
    const controller = new AbortController();
    active.set(data.id, controller);
    try {
      const result = await handler(JSON.parse(data.json), {
        signal: controller.signal, buffers: data.buffers ?? [], compiledModule,
      });
      if (!controller.signal.aborted) {
        const value = result && Object.hasOwn(result, "buffers") && Object.hasOwn(result, "value")
          ? result : workerResult(result);
        scope.postMessage({ type: "result", id: data.id, json: JSON.stringify(value.value), buffers: value.buffers }, value.buffers);
      }
    } catch (error) {
      if (!controller.signal.aborted) scope.postMessage({ type: "error", id: data.id, error: String(error) });
    } finally { active.delete(data.id); }
  };
  scope.addEventListener("message", listen);
  return () => {
    scope.removeEventListener("message", listen);
    for (const controller of active.values()) controller.abort();
    active.clear();
  };
}
