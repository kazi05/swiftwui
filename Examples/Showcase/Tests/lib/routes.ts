export const ROUTES = [
  { path: "/",                  name: "home" },
  { path: "/learn/hello",       name: "hello" },
  { path: "/learn/state",       name: "state" },
  { path: "/learn/modifiers",   name: "modifiers" },
  { path: "/learn/lists",       name: "lists" },
  { path: "/learn/forms",       name: "forms" },
  { path: "/learn/routing",     name: "routing" },
  { path: "/learn/async",       name: "async" },
  { path: "/learn/theming",     name: "theming" },
  { path: "/learn/a11y",        name: "a11y" },
  { path: "/learn/errors",      name: "errors" },
  { path: "/learn/ssr",         name: "ssr" },
  { path: "/learn/pwa",         name: "pwa" },
] as const;

export type Route = (typeof ROUTES)[number];
