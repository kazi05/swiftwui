import { readFile } from "node:fs/promises";
import { WASI } from "node:wasi";

const wasm = process.argv[2];
if (!wasm) throw new Error("usage: node smoke.mjs <counter.wasm>");
const wasi = new WASI({ version: "preview1", args: [], env: {}, preopens: {} });
const module = await WebAssembly.compile(await readFile(wasm));
const instance = await WebAssembly.instantiate(module, { wasi_snapshot_preview1: wasi.wasiImport });
const { counterIncrement, counterReset, counterValue } = instance.exports;
if (![counterIncrement, counterReset, counterValue].every((value) => typeof value === "function")) {
  throw new Error("counter exports are missing");
}
counterReset();
if (counterValue() !== 0 || counterIncrement(7) !== 7 || counterIncrement(-2) !== 5) {
  throw new Error("counter state ABI failed");
}
console.log("counter smoke passed");
