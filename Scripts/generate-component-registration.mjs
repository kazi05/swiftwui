#!/usr/bin/env node
// Explicit code generation keeps wrapper discovery out of the render path.
// The extension is written into the component's source file so it can access
// private property-wrapper storage without weakening the component API.
import fs from 'node:fs/promises';
import path from 'node:path';

const configFile = process.argv[2];
if (!configFile) {
  throw new Error('Usage: node Scripts/generate-component-registration.mjs components.json');
}

function swiftStringLiteral(value) {
  let result = '"';
  for (const scalar of String(value)) {
    const codePoint = scalar.codePointAt(0);
    switch (scalar) {
    case '"': result += '\\"'; break;
    case '\\': result += '\\\\'; break;
    case '\0': result += '\\0'; break;
    case '\n': result += '\\n'; break;
    case '\r': result += '\\r'; break;
    case '\t': result += '\\t'; break;
    default:
      if (codePoint < 0x20 || codePoint === 0x7f || codePoint === 0x2028 || codePoint === 0x2029) {
        result += `\\u{${codePoint.toString(16).toUpperCase()}}`;
      } else {
        result += scalar;
      }
    }
  }
  return result + '"';
}

function requireObject(value, label) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
  return value;
}

const configPath = path.resolve(configFile);
const root = await fs.realpath(path.dirname(configPath));
const config = requireObject(JSON.parse(await fs.readFile(configPath, 'utf8')), 'Configuration');
if (!Array.isArray(config.components)) throw new Error('Configuration components must be an array');

const swiftTypeName = /^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$/;
const swiftPropertyName = /^[A-Za-z_][A-Za-z0-9_]*$/;
const seenTypes = new Set();
const seenIdentifiers = new Set();
const normalized = [];

for (const rawComponent of config.components) {
  const component = requireObject(rawComponent, 'Component');
  if (typeof component.type !== 'string' || !swiftTypeName.test(component.type)) {
    throw new Error(`Invalid component type: ${String(component.type)}`);
  }
  if (seenTypes.has(component.type)) throw new Error(`Duplicate component type: ${component.type}`);
  seenTypes.add(component.type);

  if (typeof component.identifier !== 'string' || component.identifier.length === 0) {
    throw new Error(`Component ${component.type} needs a non-empty identifier`);
  }
  if (seenIdentifiers.has(component.identifier)) {
    throw new Error(`Duplicate component identifier: ${component.identifier}`);
  }
  seenIdentifiers.add(component.identifier);

  const access = component.access ?? 'internal';
  if (access !== 'internal' && access !== 'public') {
    throw new Error(`Component ${component.type} access must be "internal" or "public"`);
  }
  if (typeof component.file !== 'string' || component.file.length === 0) {
    throw new Error(`Component ${component.type} needs a source file`);
  }
  const file = await fs.realpath(path.resolve(root, component.file));
  if (!file.startsWith(root + path.sep)) {
    throw new Error(`Component ${component.type} file must be inside the configuration directory`);
  }
  if (!(await fs.stat(file)).isFile()) {
    throw new Error(`Component ${component.type} source is not a file`);
  }

  const rawStates = component.state ?? [];
  const environment = component.environment ?? [];
  if (!Array.isArray(rawStates) || !Array.isArray(environment)) {
    throw new Error(`Component ${component.type} state and environment must be arrays`);
  }
  const states = rawStates.map((value) => typeof value === 'string'
    ? { property: value, id: value }
    : requireObject(value, `State entry for ${component.type}`));
  for (const value of states) {
    if (typeof value.property !== 'string' || !swiftPropertyName.test(value.property)
        || typeof value.id !== 'string' || value.id.length === 0) {
      throw new Error(`Invalid state property or stable ID for ${component.type}`);
    }
  }
  if (environment.some((value) => typeof value !== 'string' || !swiftPropertyName.test(value))) {
    throw new Error(`Invalid environment property for ${component.type}`);
  }
  if (new Set(states.map((value) => value.id)).size !== states.length) {
    throw new Error(`Duplicate state identifier in ${component.type}`);
  }
  const properties = [...states.map((value) => value.property), ...environment];
  if (new Set(properties).size !== properties.length) {
    throw new Error(`Duplicate registered property in ${component.type}`);
  }
  normalized.push({ ...component, access, file, states, environment });
}

// Build every replacement before touching disk. A malformed later component
// therefore cannot leave earlier source files partially regenerated.
const replacements = new Map();
for (const component of normalized) {
  const start = `// swiftwui-registration:${component.type}:begin`;
  const end = `// swiftwui-registration:${component.type}:end`;
  const memberAccess = component.access === 'public' ? 'public ' : '';
  const registrations = [
    ...component.states.map((value) =>
      `        properties.state(_${value.property}, stableID: ${swiftStringLiteral(value.id)})`),
    ...component.environment.map((value) => `        properties.environment(_${value})`),
  ];
  const block = [
    start,
    `extension ${component.type}: ExplicitComponentRegistration {`,
    `    ${memberAccess}static var componentIdentifier: String { ${swiftStringLiteral(component.identifier)} }`,
    `    ${memberAccess}func registerProperties(_ properties: inout ComponentProperties) {`,
    ...registrations,
    '    }',
    '}',
    end,
  ].join('\n');

  let source = replacements.get(component.file) ?? await fs.readFile(component.file, 'utf8');
  const first = source.indexOf(start);
  const last = source.indexOf(end);
  if ((first < 0) !== (last < 0) || (first >= 0 && last < first)) {
    throw new Error(`Unpaired registration markers for ${component.type}`);
  }
  if ((first >= 0 && source.indexOf(start, first + start.length) >= 0)
      || (last >= 0 && source.indexOf(end, last + end.length) >= 0)) {
    throw new Error(`Duplicate registration markers for ${component.type}`);
  }
  source = first >= 0
    ? source.slice(0, first) + block + source.slice(last + end.length)
    : source.trimEnd() + '\n\n' + block + '\n';
  replacements.set(component.file, source);
}

for (const [file, source] of replacements) {
  const temporary = `${file}.swiftwui-generated.${process.pid}.tmp`;
  await fs.writeFile(temporary, source);
  await fs.rename(temporary, file);
  process.stdout.write(`Registered ${path.relative(root, file)}\n`);
}
