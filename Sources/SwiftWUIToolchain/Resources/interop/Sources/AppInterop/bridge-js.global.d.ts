// Read from globalThis: public/interop/index.js installs these before boot.
export function interopGreet(name: string): string;
export function interopGreetingAsync(name: string): Promise<string>;
export function interopUnsubscribe(token: number): void;
