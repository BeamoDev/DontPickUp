# Restored prototype startup

The owner requested the complete prototype restored, enabled and playable again. The source was recovered from GitHub history at commit `b5cca94` (the complete version immediately before `be14264`, "post prototype"). `git fetch origin` confirmed the remote history before recovery. No branch reset, merge, commit or push was performed; the newer authored work is preserved.

## Load it

1. Stop Play in **Game place 111652489432168**.
2. Sync all three Game roots together, retaining their names:
   - `GServer` under `ServerScriptService`.
   - `GClient` under `StarterPlayer.StarterPlayerScripts`.
   - `GShared` under `ReplicatedStorage`.
3. Keep exactly one server Script, **`GServer/Startup/Bootstrap`**, and one client LocalScript, **`GClient/Startup/Bootstrap`**. All other runtime scripts are **ModuleScripts**, organized into flat systems. GameController and SessionController are modules. Remove obsolete root Bootstrap/PrototypeController LocalScript copies if they remain deployed. Use [SOURCE_CHANGES](SOURCE_CHANGES.md) and `tests/SourceMoves.json` for old paths.
4. **`GServer/Session/GameConfig.Enabled = true` is already set.** Press Play. Studio direct entry is enabled without requiring a Lobby teleport. Profiles load before preparation begins.

The prototype now binds your saved map at `Workspace.Prototype.DPU_Prototype`, `ReplicatedStorage.Assets.Devices.Phone`, `ReplicatedStorage.Remotes`, and the saved StarterGui screens. It does not build replacements. Keep the complete [authored asset hierarchy](PROTOTYPE_ASSETS.md). The world adapter places employees at the saved StaffSpawn; ShopFloor determines the original layout's local origin.

Enter through the staff door, use the timeclock, read the directives, collect the repair kit and follow the guided first repair. The saved HUD supplies objectives and controls. Prototype dialogue uses authored HUD.Subtitles and its existing Camera; the older copied dialogue card is hidden. Teardown preserves scene/UI assets and restores captured runtime changes.

To return to the newer authored interactions and customer bench, change **`GameConfig.Enabled = false`** on the server and restart Play. The setting is selected at startup, not hot-swapped. The server publishes it before the client constructs any HUD/camera stack. Only the selected mode starts.

## Restored content

- Complete saved shop, street, two repair benches, stockroom, kit/tools, component shelves, fax collection, radio, lighting, timeclock, service counter and shelter.
- Customer catalog and conversations; accepting, diagnosing, collecting/replacing parts, repair puzzles, reassembly, phone privacy/software choices, testing, pickup calls and return.
- Training/preparation, five-night Story progression, continuing Endless mode, government directives, voting, suspicion, events, personal scares, outdoor danger, injuries/death, endings, employee reports/awards and discoveries.
- Saved prototype HUD, authored subtitles, physical repair presentation, button alternatives, camera controls, scares and requests.
- Private party admission for published Lobby joins, direct Studio testing, profile save/outcome handling, results, replay/next-night readiness and Lobby return. Studio return performs the existing save/roster preview; real teleports require published testing.

`StartMode = "Story"` selects direct Studio play; use `"Endless"` to test that mode. Published joins use the Lobby's server-authorised mode. Capacity remains **1–4 employees**. The original prototype's mid-night late join behavior is retained: late arrivals are spectators, including during closing. The current profile namespace, schema migration and ownership leases are unchanged. StudioSaving remains false by default, so separate Studio sessions do not persist practice progress.

## Shift phases

| Phase | Behaviour |
| --- | --- |
| Waiting | Profiles and expected party members load. Studio can enter directly. |
| Preparation | Clock in, read the rules, and complete the guided first repair. The internal legacy phase name remains Tutorial. |
| Shop open | Normal customer orders and the existing night director run until 6 AM. Internal phase: Night. |
| Closing | New intake stops. Customers who have not handed over a device leave. Accepted phones can still be repaired, called for pickup and returned for up to 60 seconds. Pending threats are cleared. |
| Results | The last completed return or the grace deadline ends the night. Unfinished accepted phones are counted as missed. Outcomes settle once; then continue, start a new run or return to the Lobby. |

`GameConfig.NightSeconds = 360` retains the six-minute night. `ClosingSeconds = 60` controls the new grace window. An empty shop can finish immediately at dawn. Actual death and all-player departure still end the run safely during closing.

## Source layout and recovery

All folders remain flat: `src/<Root>/<System>/<Module>.luau`. The recovered game now lives in Session, Customers, Orders, Repair, Horror, Story and World on the server, and Session, Camera, Interaction, Repair, Interface and Effects on the client. Public definitions live in Shared systems. See [the current tree](CURRENT_ARCHITECTURE.md).

`tests/PrototypeRestoration.json` retains the historical commit and original paths, mapped to today's destinations. Common infrastructure is maintained once under common/ and deployed through project.sources.json and tools/SyncCommon.ps1. Runtime source no longer has Prototype folders; authored assets and legacy network action names retain their names.

## Checks and remaining Studio work

Run `tests/Run.ps1`: all **24 suites** cover the retained authored systems, recovered Prototype/PhoneGameplay/Pickup/Improvements/Engagement systems, preparation/closing/results, both startup selections, Core parity and full source compilation. Original fixtures keep immediate dawn for historical scenarios; ShiftPhases separately exercises the enabled 60-second production setting, including completing real tasks during closing.

Local mocks verify source behavior, not Roblox rendering or live service success. In Studio, verify that Play actually places 1–4 employees at the saved shop, only one HUD/camera owns input, clock-in/training and a complete repair work, closing permits pickup/return, results/replay work, and switching Enabled off restores authored mode. Also test mobile/controller gestures, avatar seating/visibility, physical puzzle alignment, sounds/scares, departure/respawn and cleanup. Published Lobby admission, teleports and DataStore saves still need live verification. This restoration has not published a place.
