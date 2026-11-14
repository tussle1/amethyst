# amethyst

A black-and-violet Luau developer hub for Roblox experiences you own or are authorized to test.

## setup

1. Open your Roblox Studio experience.
2. Create a folder named `AmethystRemotes` in ReplicatedStorage (the server script also creates it).
3. Place `AmethystServer.server.lua` in ServerScriptService.
4. Place `AmethystClient.client.lua` in StarterPlayer > StarterPlayerScripts.
5. Set your Roblox user id in the server script's `AUTHORIZED_USER_IDS` table.
6. Run the experience.

All movement, teleport, vehicle, and training actions are server-validated and restricted to authorized users. Combat training targets tagged training dummies only. This project does not inject into or manipulate Prison Life or other third-party live experiences.

## included

- responsive draggable and collapsible interface
- searchable feature navigation and touch-friendly controls
- saved local configurations
- server-authorized movement test settings
- teleport bookmarks and authorized test locations
- vehicle controls for vehicles spawned by this system
- training-dummy targeting and visual markers
- player and server diagnostics
