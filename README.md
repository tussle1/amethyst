# amethyst / prison life private

A self-contained, black-and-violet Luau hub for the **official Prison Life client in a private/VIP server**. The deliverable is **[`executor/AmethystPrivate.lua`](executor/AmethystPrivate.lua)**: one script to paste and execute. It does not fetch code over HTTP or install server scripts.

> **Runtime status:** The source and bundle have been statically checked here, **not executed in Roblox, Delta, or Xeno**. Game remotes, executor APIs, physics, and server acceptance need testing in your own private server. A private server is still controlled by the game's server scripts; client execution cannot grant server authority.

## run

1. Join the **official Prison Life** place in a private/VIP server and wait until your character spawns. This build recognizes place ID `155615604` and requires both a nonempty `game.PrivateServerId` and `game.PrivateServerOwnerId > 0`. It will not start in a public or reserved server or another place.
2. Open [`executor/AmethystPrivate.lua`](executor/AmethystPrivate.lua), copy the **entire file**, paste it into an executor script editor (such as Delta or Xeno), and execute it once. There is no loader URL, install step, or additional file to execute.
3. On phones/tablets, use the **top-right violet button** to open or hide the menu. Drag the header, tap `−` to collapse, scroll the category strip, and search page titles/features. On desktop, `RightShift` toggles the menu, `E` holds aim, `G` activates the equipped tool, and `Z` stops modes by default. All keyboard bindings, including emergency stop, can be changed in **settings**.
4. **Stop all** turns off active modes and restores the script's local gun/vehicle changes. **Restore defaults** also resets settings and keybinds. **Unload hub** removes the UI, ESP, movement controllers, and active shot handler. Re-executing the file replaces the previous instance when the executor supplies a persistent `getgenv`/`shared` table.

The window adapts to portrait phones, landscape phones, tablets, and desktops. Mobile fly has touch ascent/descent buttons when the menu is hidden or collapsed; horizontal movement uses the game's standard PlayerModule joystick when accessible, with humanoid movement as a fallback. This behavior still needs device testing.

## feature scope and feedback

| Controls | What this client attempts | What is **not** guaranteed |
| --- | --- | --- |
| Aim assist/aimlock, FOV, team/visibility checks | Adjust the **local camera** toward eligible on-screen players; touch/manual aim is available. | Server hits or targeting through streamed-out objects. |
| Player/vehicle ESP | Local `Highlight` and distance `BillboardGui` objects; no Drawing API needed. | Visibility of unstreamed players/vehicles or a server-side effect. |
| Speed, fly, noclip, infinite jump, anti-stun | Local humanoid/character control; anti-stun only clears local `PlatformStand`. | Server replication or immunity from other game stun systems. |
| Teleport/bookmarks/player travel | Move the local character to a detected spawn, saved spot, or nearby player; bookmarks last until reinjection. | The game may correct movement. Destinations not found in the current map cannot be offered. |
| Weapon pickups | Request up to five **candidate** free items from visible `Prison_ITEMS` pickups using a compatible `workspace.Remote.ItemHandler` RemoteFunction. | A successful call is **not** proof the server granted the item. Team, pass, proximity, and other game rules still apply; check the Backpack. |
| Gun stats | Change a compatible equipped `GunStates` module's local Damage/FireRate/Spread table and restore it on stop/unload. | The game/server may ignore or replace local values. No unknown module is modified. |
| Silent aim | If the executor provides a namecall hook and the game provides a compatible `ShootEvent`, rewrite only recognized, equipped-gun shot packets; unrecognized packets pass through unchanged. Combat displays packets seen/changed and a status; **changed is not a confirmed hit**. | Current packet shape, hook support in a given Delta/Xeno version, and server acceptance. Off/unload disables the handler; a previously installed executor hook remains inert. |
| Rage bot, taze/arrest | Rate-limited camera aim + equipped-gun activation; taze attempts with an equipped Taser, arrest requests only for nearby criminal targets if the expected `arrest` RemoteFunction exists. | A tool activation is not a hit; arrest is reported as confirmed **only** when the remote returns `true`. |
| Vehicle controls | Try a nearby unoccupied seat, a nearby vehicle-labeled prompt/click detector if supported, and local speed/handling/teleport for a seat whose physics ownership `isnetworkowner` can confirm. | There is **no verified arbitrary vehicle-spawn remote**. An interaction attempt does not prove a vehicle spawned; the server may reject or correct tuning/teleport. |

Game-facing references (`ShootEvent`, `ItemHandler`, `arrest`, `GunStates`) come from older public examples, **not a current live-game inspection**. Features fail with a notification or remain off when a required API/object is missing. Pickup controls are limited to known free-item candidates; they do not spoof passes or bypass server-side access decisions.

Configuration is sanitized, bounded, and saved to `amethyst_private_settings.json` through executor `writefile`/`readfile` when available; otherwise it is in memory only and its lifetime depends on the executor. Bookmark positions are intentionally not written to disk. The hub uses native Roblox UI, no external assets or HTTP loader, and no continuous polling outside enabled movement, combat, and ESP modes.

## source and checks

- `executor/Source/` contains the Maid, theme, window, page definitions, and feature controllers as separate build-time modules.
- `tools/build_private.py` bundles them in dependency order into the **single executable** `executor/AmethystPrivate.lua`. Run `python3 tools/build_private.py` after edits; Python 3 is the only build requirement.
- `npm ci && npm run check` performs a Luau parser/scope check plus bundle integrity checks. The generated file was also compiled with the official Luau CLI (0.747) and smoke-tested in a minimal mock for startup gates and menu rendering. These are **static/mock** validations, not evidence of actual Roblox/executor behavior.

If the official game changes its place ID or remotes, the game-dependent controls should be updated **after private-server verification**, not treated as automatically supported.
