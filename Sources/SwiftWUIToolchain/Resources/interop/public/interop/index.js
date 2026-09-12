import { formatGreeting } from './format.js';

const listeners = new Map();
let nextToken = 1;

function checkedName(name) {
  if (typeof name !== 'string' || name.trim() === '') throw new TypeError('name must not be empty');
  return name;
}

globalThis.interopGreet = (name) => formatGreeting(checkedName(name));
globalThis.interopGreetingAsync = async (name) => formatGreeting(checkedName(name));
globalThis.interopSubscribe = (callback) => {
  if (typeof callback !== 'function') throw new TypeError('callback must be a function');
  const token = nextToken++;
  listeners.set(token, callback);
  return token;
};
globalThis.interopUnsubscribe = (token) => listeners.delete(token);
globalThis.__swiftwuiInteropEmit = (message) => {
  for (const callback of listeners.values()) callback(message);
};
