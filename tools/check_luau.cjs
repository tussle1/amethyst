// Syntax and lexical-binding validation only: this cannot simulate Roblox or an executor.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { parse, analyzeScopes } = require('luau-parser');

const root = path.resolve(__dirname, '..');
const source = path.join(root, 'executor/Source');
const files = fs.readdirSync(source).filter(name => name.endsWith('.lua'))
  .map(name => path.join(source, name));
files.push(path.join(root, 'executor/AmethystPrivate.lua'));

const globals = new Set([
  // Luau standard library and Roblox globals used in this client.
  'CFrame', 'Color3', 'ColorSequence', 'ColorSequenceKeypoint', 'Enum', 'Instance',
  'Ray', 'RaycastParams', 'TweenInfo', 'UDim', 'UDim2', 'Vector2', 'Vector3',
  'debug', 'error', 'game', 'ipairs', 'math', 'os', 'pairs', 'pcall', 'require',
  'setmetatable', 'string', 'table', 'task', 'tostring', 'type', 'typeof', 'warn',
  'workspace', 'xpcall',
  // Each nonstandard API is optional and checked before use in the Luau source.
  'checkcaller', 'fireclickdetector', 'fireproximityprompt', 'getgenv',
  'getnamecallmethod', 'getthreadidentity', 'hookmetamethod', 'isnetworkowner',
  'newcclosure', 'readfile', 'setthreadidentity', 'shared', 'writefile',
]);
const injections = {
  'Library.lua': new Set(['MaidModule', 'ThemeModule']),
  'Targeting.lua': new Set(['PrivateContextModule']),
  'Movement.lua': new Set(['PrivateContextModule', 'MaidModule']),
  'Visuals.lua': new Set(['PrivateContextModule', 'MaidModule', 'ThemeModule']),
  'Combat.lua': new Set(['PrivateContextModule', 'MaidModule']),
  'Travel.lua': new Set(['PrivateContextModule']),
  'Inventory.lua': new Set(['PrivateContextModule']),
  'Vehicles.lua': new Set(['PrivateContextModule']),
  'PrivateCore.lua': new Set(['PrivateContextModule', 'MaidModule', 'LibraryModule',
    'PrivateMenuModule', 'TargetingModule', 'MovementModule', 'VisualsModule',
    'CombatModule', 'TravelModule', 'InventoryModule', 'VehiclesModule']),
};

for (const file of files) {
  const text = fs.readFileSync(file, 'utf8');
  const ast = parse(text, { locations: true, comments: false });
  const scope = analyzeScopes(ast);
  const extra = injections[path.basename(file)] || new Set();
  const unexpected = [...scope.globalsByName.keys()].filter(name => !globals.has(name) && !extra.has(name));
  assert.deepEqual(unexpected, [], `unexpected free globals in ${path.relative(root, file)}`);
  console.log(`parsed ${path.relative(root, file)} (${text.split('\n').length - 1} lines)`);
}

const core = fs.readFileSync(path.join(source, 'PrivateCore.lua'), 'utf8');
const context = fs.readFileSync(path.join(source, 'PrivateContext.lua'), 'utf8');
const menu = fs.readFileSync(path.join(source, 'PrivateMenu.lua'), 'utf8');
const library = fs.readFileSync(path.join(source, 'Library.lua'), 'utf8');
for (const text of ['game.PlaceId ~= PRISON_LIFE_PLACE_ID', 'if not inPrivateServer() then return warn']) {
  assert.ok(core.includes(text), `missing private-server gate: ${text}`);
}
for (const text of ['game.PrivateServerId', 'game.PrivateServerOwnerId', 'ownerId > 0']) {
  assert.ok(context.includes(text), `missing private/VIP check: ${text}`);
}
for (const id of ['home', 'combat', 'visuals', 'movement', 'teleport', 'vehicles', 'tools', 'settings']) {
  assert.ok(menu.includes(`id = "${id}"`), `missing page: ${id}`);
}
for (const fn of ['setVisible', 'setPages', 'filterPages', 'setFlightControls', 'notify', 'destroy']) {
  assert.ok(library.includes(`function Library:${fn}(`), `missing UI method: ${fn}`);
}
const defaults = context.match(/local DEFAULTS = \{([\s\S]*?)\n\}/);
assert.ok(defaults, 'missing config defaults');
const configKeys = new Set([...defaults[1].matchAll(/\b(\w+)\s*=/g)].map(match => match[1]));
for (const match of menu.matchAll(/^\s*(?:slider|toggle)\("(\w+)"/gm)) {
  assert.ok(configKeys.has(match[1]), `menu references unknown setting: ${match[1]}`);
}
assert.ok(configKeys.has('stopKey'), 'emergency stop key must be configurable');
console.log('private-server gate, eight pages, menu settings, and UI methods are present (static checks)');
