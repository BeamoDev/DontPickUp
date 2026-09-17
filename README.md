# Don't Pick Up

Code is organized into flat game systems; the six Game/Lobby roots are unchanged. There are no runtime Prototype folders. Read [the current system tree](docs/CURRENT_ARCHITECTURE.md) and [deployment instructions](docs/SOURCE_CHANGES.md) before syncing this reorganization. Keep the authored Workspace.Prototype map and both HUD screens.

The active Game runtime now binds `HUD.Frames.Briefing` for the introductory single-button briefing, `HUD.Frames.ClockIn` at the timeclock, `HUD.Frames.TonightsRules` after clock-in `HUD.Frames.ShiftComplete` after a survived shift, and `HUD.Frames.GameLost` on death. ClockIn shows the account username and a permanent four-digit employee number saved by the shared Lobby/Game profile system. Panels animate to their authored layout; loss totals come from the server. See [HUD setup and Studio checks](docs/HUD_PANELS.md).

The authored Settings frame works in both places with saved Music, SFX and CameraShake toggles and a downward Close animation. Opening remains yours to wire. See [settings setup](docs/SETTINGS.md).

The active shop now follows the surveillance repair direction: one faulty component, optional private records, physical contact calls, one nightly directive and customer consequences across nights. `GameConfig.ShopDirection = true` is the default. See [current gameplay and verification](docs/SHOP_DIRECTION.md) and the exact [Workspace cleanup list](docs/WORKSPACE_CLEANUP.md).

A Roblox cooperative psychological horror game for 1-4 players, set in a government-controlled electronics repair shop in the 1980s. The full prototype has been restored from GitHub history and is enabled by default, using the saved Studio map and UI. It includes the shop, customers, repair tasks, stock, dialogue, threats, Story/Endless nights and results. The newer authored systems are retained as the alternate startup mode.

The alternate authored mode includes Lobby parties and queues, profiles and settings, first-person controls, containers with paired labels, drinks, click-to-carry throwing, a local fax keypad with easter-egg calls, TV viewing, authored phone disassembly/wire repair/reassembly, dialogue, and a shared customer/order/payment loop with a temporary Studio test bench. Authored models, UI, lighting and media remain in Studio.

## Load the restored prototype

Sync the three Game roots below and restart Play in the Game place. `GServer/Session/GameConfig.Enabled = true` binds the saved shop and prototype HUD. Keep the exact [authored prototype asset hierarchy](docs/PROTOTYPE_ASSETS.md). You spawn at the shop; enter, clock in, read the rules and finish the guided repair to open the night. At 6 AM, existing accepted phones get up to 60 seconds before results.

The top-left display binds `HUD.Clock.Night/Time` (legacy DPU placement remains supported). Customers clone randomly from every valid model in `ReplicatedStorage.Assets.Characters.Female` and `.Male`, with names shown in subtitles and the same appearance kept for pickup. Both rigs use the [shared customer animation catalog](docs/CUSTOMER_ANIMATIONS.md). Customer ticket calls use the physical `Workspace.Prototype.DPU_Prototype.Fax` keypad and screen.

Set `Enabled = false` and restart to return to the newer authored interaction/order systems. Only one mode runs. [Restoration, controls and deployment](docs/PROTOTYPE_RESTORATION.md).

All current customers bring the authored `ReplicatedStorage.Assets.Devices.Phone`. Remove screws, cover and battery before diagnosis; collect the faulty replacement from Storage, repair and reassemble, then use the existing software/test/pickup flow. Keep both bench and counter phone objects as placement anchors. [Device setup](docs/PROTOTYPE_ASSETS.md#customer-phone-device).

## Source and deployment

Keep these six names exactly; **G means Game and L means Lobby**. Every root contains system folders, and each system contains only scripts/modules. There are no scripts at a root and no nested system folders.

| Source root | Studio destination in its own place |
| --- | --- |
| `src/GClient` | Game `StarterPlayer.StarterPlayerScripts.GClient` |
| `src/GServer` | Game `ServerScriptService.GServer` |
| `src/GShared` | Game `ReplicatedStorage.GShared` |
| `src/LClient` | Lobby `StarterPlayer.StarterPlayerScripts.LClient` |
| `src/LServer` | Lobby `ServerScriptService.LServer` |
| `src/LShared` | Lobby `ReplicatedStorage.LShared` |

These are the required deployment mappings; the live Studio hierarchy has not been inspected. Use Roblox Script Sync, not a new Rojo/dependency setup. Preserve the existing place split: Lobby `110554757455252`, Game `111652489432168`.

- `.local.luau` creates a LocalScript: `GClient/Startup/Bootstrap` and `LClient/Startup/Bootstrap`.
- `.server.luau` creates a Script: each server's `Startup/Bootstrap`.
- All other `.luau` files create ModuleScripts.
- Sync all three roots together **within each place**, remove old script copies using [the move manifest](docs/SOURCE_CHANGES.md), then restart Play. Leaving old controllers/bootstrap Scripts can run the same system twice.
- Shared contains only public definitions/query rules consumed by both runtimes. Client-only views, requests and camera math are in Client; Lobby billboard/geometry helpers are in Server. Private profiles, admission and gameplay validation stay in Server.
- Maintain shared infrastructure once in `common/CommonServer` and settings in `common/CommonClient/Interface`. `project.sources.json` maps it into both places. Run `tools/SyncCommon.ps1` after common edits; `tests/Run.ps1` checks all generated copies. Do not edit these deployment copies in src. Save/admission safeguards and the DataStore namespace are preserved.

## Authored-mode interactions and cameras

Tag whole authored Models with `Container`, `Fax` or lowercase `tv`. `Drink` and lowercase `throw` accept either a Model or a BasePart. Keep intended hit surfaces queryable. Reuse `ReplicatedStorage.Assets.SelectionHighlight` (root `ReplicatedStorage.SelectionHighlight` is a fallback).

The central controller owns world and fax input, shares one highlight, and performs one active hover query after the camera update. Raw mouse/touch coordinates use viewport rays, removing the former inset offset. Nested model parts resolve to their owner; drawer descendants and matching labels resolve to their Box. Non-collidable decoration can be skipped, while collidable walls, terrain, other interactables, distance limits and interactive UI block selection. Queries stop after 12 hits rather than scanning the scene. Details and authoring boundaries: [TAGGED_INTERACTIONS](docs/TAGGED_INTERACTIONS.md).

Mouse activates on press. Touch requires a short stationary tap; movement beyond 18 pixels at any point cancels it, even if the finger moves back. A second touch also cancels. Click/tap a `throw`-tagged brick to carry it in front of the view; click/tap again to throw it at a consistent server-set speed with a small white trail. Q/B cancels. The server owns reservations, range, occlusion and physics. Changed aim directions update at most 20 times per second while carrying; no client positions or per-frame requests are sent.

Containers, fax and TV reuse `GClient/Camera/InspectionCamera`. Camera position, focus and FOV ease in and back to first person over 0.35 seconds. The character is locally anchored before entry and remains anchored through the return. Closing hides the inspection UI and immediately relocks the mouse, unless a menu or text field needs it. The saved camera pose/FOV and previous anchoring/rotation state are restored on completion. External character displacement still translates the return path. Reduced motion skips camera animation; death, respawn, camera replacement and teardown release ownership immediately. Framing retweens for model/viewport changes. Q/B or the close button exits. See [containers](docs/CONTAINERS.md), [fax](docs/TELEPHONE.md), and [throwing](docs/THROWING.md).

## Checks

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Run.ps1
```

The runner uses `.tools/lune/lune.exe`, or pass `-Lune` with your installed executable. It runs 30 active suites, verifies common deployment parity, checks every static import and the folder-depth rule, and compiles runtime/test Luau. The original prototype suites are restored alongside the authored-system, startup and closing-phase checks.

Local checks use mocked Roblox services and actual vector/CFrame math. They do not verify Studio rendering, imported mesh/query geometry, mobile camera gestures, multiplayer physics/replication, published saving or Lobby teleports. Follow the [Studio checklist](docs/CURRENT_ARCHITECTURE.md#studio-verification). No place has been published by this refactor.

The complete owner-supplied game direction remains in [AGENTS.md](AGENTS.md). Older generated-game notes are [historical](docs/IMPLEMENTATION_HISTORY.md).

## Fax easter eggs

Dial `67`, `1984`, or `404` to connect to a local easter-egg route. The fax displays DIALING, then CONNECTED. `Telephone.Phone` (BasePart or Model) animates up out of the inspection view; End hangs up and lowers it. Physical KeyClose, Q/B and the UI close button all exit and hang up. Receiver visuals are local copies so authored welds/parts remain intact.

`GClient/Effects/TelephoneCalls` holds the number routes. `PlayerGui.DPU_GameInteractions.TelephoneCallChanged` is a local BindableEvent for the future subtitle renderer: payload `{Phase, Number, Id, SubtitleKey, SessionId}`; phases are Dialing/Connected/Ended. No subtitle UI/audio is implemented yet. Only a Connected event should start dialogue; Ended cancels that SessionId.

Lobby queues, parties and outbound teleports remain intact. The authored mode does not use MemoryStore tickets, arrival state or ReturnLobby; the restored prototype uses its own admission and Lobby-return lifecycle. DataStore namespace/schema, profile data and save locking are unchanged. See the move manifest for obsolete Studio instances to remove.

## Phone repair

Tag the authored Phone Model with `PhoneRepair` and retain the screenshot hierarchy. It lifts, turns, disassembles, lays out its parts, accepts the configured wire drags, then requires battery, cover and four screws. Full setup, wire pairings, controls and Studio checks: [PHONE_REPAIR](docs/PHONE_REPAIR.md).

## Dialogue test

The authored `HUD.Dialogue` presents conversations in both Game modes (`DPU_PrototypeHUD.DialogueSubtitles` and `HUD.Subtitles` remain compatibility fallbacks) using `ReplicatedStorage.Assets.NPC` and your avatar for You lines. Typewriter reveal, configured portraits and fade/slide speaker transitions preserve authored text properties and size. The ten-second demo is disabled by default. Setup and controls: [DIALOGUE](docs/DIALOGUE.md).

## Customers and orders

Customers now approach a shared counter, hand over a repairable phone through the existing dialogue, wait while the crew repairs it, then pay ten credits per present employee when it is returned. A small temporary bench and compatible phone generate in Studio for testing. Place an invisible, non-collidable/non-queryable `Workspace.OrderBenchOrigin` Part at floor level to choose its location; otherwise it appears near a SpawnLocation. The old ten-second dialogue demo is disabled. Setup, authored station replacement, ownership rules and Studio checks: [CUSTOMER_ORDERS](docs/CUSTOMER_ORDERS.md).
