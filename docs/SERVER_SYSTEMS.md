# Server systems and integration

Current folder deployment and latest controls are defined in [CURRENT_ARCHITECTURE](CURRENT_ARCHITECTURE.md). Preserve the new subfolders when syncing; older flat sibling descriptions in this historical integration detail are superseded.

## Scope

Implemented: parties within one Lobby server, friends-only/public admission, ready checks, host countdown, reserved-server group teleports, retries, destination admission, party arrival gating, player profiles, settings, progress APIs, autosave, departure saves, and shutdown cleanup.

Authored walk-in queues are connected; see [Lobby queues](LOBBY_QUEUES.md). A [Game prototype](GAME_PROTOTYPE.md) now supplies a generated shop, tutorial, phone repairs, customers, a night clock, hazards, voting, and results. Full campaign gameplay, cross-server party discovery/invitations, purchases, and reconnect-to-running-session matchmaking remain unimplemented. Friends first join the same Lobby server and enter the same queue. General party APIs remain available independently of physical models.

## Studio setup

| Place | Source | Required destination |
| --- | --- | --- |
| Lobby `110554757455252` | `src/LServer` | A container inside this place's `ServerScriptService` |
| Game `111652489432168` | `src/GServer` | A container inside this place's `ServerScriptService` |

1. Verify both published places belong to the same experience. The supplied IDs are configured in both `Core/Config.luau` copies. Their universe relationship could not be checked from this environment.
2. Sync the entire relevant server root, retaining `Core`, `Runtime`, and the environment-specific service. `Bootstrap.server.luau` must be a **Script**. Every other `.luau` source is a **ModuleScript**. Do not activate both roots in one place. Module requires are relative, so the container itself can sit under an existing server wrapper.
3. Inspect Studio Script Analysis and Server Output. The bootstrap rejects the wrong published place and duplicate network creation. No source is imported from another place or from either replicated shared root.
4. For the Game subplace, use Creator Dashboard's **Secure within universe only** access setting. The Game server additionally checks its own admission roster. See [Roblox secure teleportation](https://create.roblox.com/docs/projects/teleport#configure-secure-teleportation).
5. Keep `StudioSaving = false` for practice. This makes no DataStore calls and preserves data only within the running practice server. If explicitly testing persistence in Studio, enable API access and `StudioSaving`; it uses `DontPickUp_PlayerData_v1_STUDIO`, never the production namespace.
6. Test teleports in the published Roblox application. Roblox does not support TeleportService playtesting in Studio. [Teleport documentation](https://create.roblox.com/docs/projects/teleport)

No remotes or player folders need to be manually authored. Existing client/shared roots remain available for future authored UI and client controllers.

## Runtime ownership

| Module | Responsibility |
| --- | --- |
| `LServer/Bootstrap.server.luau` | Lobby lifecycle, request routing, one-second service scheduling |
| `LServer/Parties/PartyService.luau` | Party roster, permissions, ready state, countdown, recovery |
| `LServer/Queues/WorldQueueService.luau`, `QueueWorld.luau`, `QueueGeometry.luau` | Physical pad reservations, entry/exit, gathering, board and member views |
| `LServer/Queues/QueueBillboard.luau` | Authored world sign: mode icon, host title, player count, green/amber status, legacy name fallbacks |
| `LClient/QueueController.local.luau`, `QueueView.luau`, `QueueRequests.luau` | Authored UI/status binding, mode/capacity draft, scoped Create/Leave requests, timeout ownership, respawn rebinding |
| `GServer/Bootstrap.server.luau` | Admission before profile loading, Game lifecycle, return-to-Lobby request |
| `GServer/Services/GameSession.luau` | Expected party, loaded members, all-member start gate |
| `GServer/Services/GamePrototype.luau`, `ShiftService.luau`, `PrototypeWorld.luau`, `PrototypeConfig.luau` | Playable introductory night, generated shop, server interactions, hazards, results, profile integration |
| `GClient/PrototypeController.local.luau`, `PrototypeView.luau` | Game tutorial/HUD, vote/results interface, objective highlight, spectator camera |
| `GServer/Repair/RepairTemplates.luau`, `GClient/Repair/RepairPresentation.luau` | Reusable phone template, local component highlights/progress, interruptible camera close-ups |
| `GServer/Repair/Workshop.luau`, `CustomerCatalog.luau` | Physical repair chair and carried parts; 270 server-only customers, variable service requirements and chapter clues |
| Each `Runtime.luau` | References for other server modules after startup |
| `Core/Config.luau` | Place IDs, limits, storage names, Studio settings |
| `Core/ProfileSchema.luau` | Defaults, strict known-field validation, future migration entry point |
| `Core/SessionStore.luau` | Atomic ownership acquisition, save, release, cancelled-load cleanup |
| `Core/DataService.luau` | Player lifecycle, serialized writes, progress/settings mutations, autosave |
| `Core/PlayerView.luau` | Replicated public profile summaries and session loading state |
| `Core/TravelService.luau` | Save/freeze, reservation, dispatch, retry correlation, safe recovery |
| `Core/TicketStore.luau`, `AdmissionRules.luau` | Server-issued admission roster and destination validation |
| `Core/Network.luau`, `RateLimiter.luau` | Bounded requests, per-player serialization, throttling |

Common server modules are deployed into both places. Maintain `LServer/Core`, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/SyncCore.ps1
```

The helper copies only the named Core files and refuses unexpected extra Game Core files. Tests check byte-for-byte parity. This is local code duplication for independent Script Sync deployment, not a runtime cross-place dependency.

## Client request contract

The server creates:

- Lobby: `ReplicatedStorage.DontPickUpLobbyNet.Request` (**RemoteFunction**) and `.StateChanged` (**RemoteEvent**).
- Lobby physical UI also subscribes to `.QueueStateChanged` (**RemoteEvent**) and uses `GetQueueState`, `QueueCreate`, and `QueueLeave`; see the [queue contract](LOBBY_QUEUES.md).
- Game: `ReplicatedStorage.DontPickUpGameNet.Request` and `.StateChanged`. Game session changes are currently exposed through the `DontPickUpGameSession` folder attributes; the Game `StateChanged` event is reserved for future interface integration.

Call `Request:InvokeServer(action, payload)`. Responses are `{ Ok: boolean, Code: string?, State: table? }`. Handle rejected requests and transport errors in the future client. Do not start client countdowns independently: party `CountdownEndsAt` uses `workspace:GetServerTimeNow()`.

### Lobby actions

| Action | Payload | Meaning |
| --- | --- | --- |
| `GetState` | none | Current party, up to 50 joinable parties, and DataReady |
| `Create` | `{ Capacity = 4, Access = "Friends", Mode = "Story" }` | Nonphysical API party; capacity 1-4; Friends/Public; Story/Endless |
| `Join` | `{ PartyId = "1" }` | Join an existing local party; server verifies friendship if needed |
| `Leave` | none | Leave before transfer preparation; host passes to oldest remaining member |
| `Ready` | `{ Ready = true }` | Change readiness; unready cancels a countdown |
| `Start` | none | Host starts the five-second countdown if everyone is ready |
| `Cancel` | none | Host cancels the countdown |
| `Kick` | `{ UserId = 123 }` | Host removes another member while Open; blocked from rejoining that party |
| `SetSetting` | `{ Key = "Subtitles", Value = true }` | Save an allowlisted personal setting |

The host begins ready when creating a party. New members begin unready. Full capacity is not required; everyone currently in the party must be ready. After a failed transfer, remaining members must ready again. Open parties expire after ten minutes without joining/ready activity.

These roster-control actions apply to nonphysical parties. Physical pads handle readiness/departure automatically and require `QueueLeave` with the current `EntryId`; generic Leave/Ready/Start/Cancel/Kick cannot override a physical queue's lifecycle.

`StateChanged` sends the current party snapshot to its members. Leaving sends `{ InParty = false }`. Snapshots include party ID, host user ID, access, capacity, state, member names/IDs/readiness, revision, countdown deadline, and last error. They never contain reserved access codes or admission tickets. Refresh the directory on demand; there is no continuous whole-server polling/broadcast.

States: `Open -> Countdown -> Preparing -> Teleporting`. Countdown can return to Open. Voluntary roster changes are rejected after preparation starts. A disconnect during preparation cancels the unsent transfer; after dispatch, remaining players retry into the original server.

### Game actions

| Action | Payload | Meaning |
| --- | --- | --- |
| `GetState` | none | Party arrival state/counts and personal DataReady |
| `ReturnLobby` | none | Save/freeze this player and teleport to a public Lobby server |
| `SetSetting` | `{ Key = "MasterVolume", Value = 0.8 }` | Allowlisted personal setting |

The prototype UI confirms Lobby return on results. While enabled, it rejects mid-run return and waits for the caller's outcome to enter the profile before travel. Its server rules award personal contributed repairs and survival/death through the existing profile API; see the prototype guide for interrupted-party and replay behavior.

### Request protection

All requests have a token bucket (burst eight, refill two per second), bounded strings, and finite-number checks. Ordinary requests allow four scalar payload fields; PrototypeAction allows six for the task-scoped puzzle input contract. One yielding request per player may run at once. Create has a three-second cooldown; Start and ReturnLobby have ten-second cooldowns. The party service rechecks membership/host/capacity after the friendship lookup yields.

Common error codes include `DataNotReady`, `FriendsOnly`, `PartyChanged`, `MembersNotReady`, `HostOnly`, `TransferInProgress`, `RateLimited`, `RequestPending`, and `PleaseWait`. Studio defaults to a save/roster print preview and returns `StudioPreviewComplete` for queue recovery; it never teleports. If `StudioTeleportPreview` is disabled, attempts return `TeleportUnavailableInStudio`. Physical pad parties must be joined through server-observed entry, not the generic Join request.

## Private-server transfer and admission

1. Freeze the roster after the ready countdown.
2. Reserve a Game server. Access codes remain server-only.
3. Freeze mutations and confirm a save for every member. Cancel before dispatch if a save fails or the roster changes.
4. Write a five-minute MemoryStore admission record containing expected user IDs, the server-validated Story/Endless mode, source/destination place IDs, private-server ID, and GameData `{Version = 1, Mode, StartNight = 1, PartySize}`. Public teleport metadata may mirror GameData for presentation; authoritative settings always come from the ticket. Profiles travel through the save/load lease handoff, never as client-supplied teleport data.
5. Send the group with `TeleportAsync` and the reserved access code. TeleportData contains only an opaque ticket ID and attempt ID, never a profile or reward claim.
6. Keep the source profile leased and frozen while departure is pending. `PlayerRemoving` performs the final save/release; the destination waits for ownership instead of racing a source save.
7. Game uses `Player:GetJoinData()` and an atomic MemoryStore claim. Verify source universe/place, target place/private-server ID, roster membership, expiry, and revocation. The first claim binds the ticket to one destination JobId.
8. Load the admitted player's profile. `GameSession:IsReady()` becomes true only when all expected members are present and data-ready.

Failures are per-player. Retry explicit transient failures at most three teleport attempts, using the same reservation. Flood errors wait longer. Old attempt callbacks are ignored. An accepted API call is not proof of arrival. If no terminal signal arrives within 45 seconds, revoke admission before allowing source recovery; do not overlap a speculative teleport retry.

If revocation storage is unavailable, keep the profile frozen and retry revocation until it succeeds or the ticket expires. An already claimed admission never thaws the old source session. A late teleport with revoked admission is rejected by the destination.

Game waits up to 120 seconds after the first loaded member for the full party. If nobody has loaded, the initial load gate is bounded by the profile-load timeout plus ten seconds. A missing/revoked initial member makes the session Incomplete. After Ready, departing members are removed while the remaining team continues; the empty session becomes Interrupted. A departed member cannot rejoin the started admission. Gameplay checks the **server API** `Session:IsReady()`, not replicated attributes.

Roblox may place players with different cross-play settings into different server instances sharing a private-server ID. This implementation rejects a second JobId and blocks the incomplete run; it does not promise an atomic all-player teleport or silently run split parties. Use ReturnLobby to regroup after a failed arrival. [Reserved server API](https://create.roblox.com/docs/reference/engine/classes/TeleportService)

## Player folders and saved data

```text
Player
  leaderstats
    Shifts Survived: IntValue = 0
    Cases Solved: IntValue = 0
  PlayerData
    Progression
      HighestShift: IntValue = 1
      TutorialComplete: BoolValue = false
      EndingsFound: IntValue = 0
      EvidenceFound: IntValue = 0
    Statistics
      Deaths: IntValue = 0
      PlaytimeSeconds: IntValue = 0
    Settings
      MasterVolume: NumberValue = 0.8
      MusicVolume: NumberValue = 0.6
      Subtitles: BoolValue = true
      ReducedFlashes: BoolValue = false
  Session
    DataStatus: StringValue
    DataLoaded: BoolValue
    Persistent: BoolValue
```

Progress folders appear after a successful load. Session states include Loading, Ready, Transferring, SaveDelayed, Saving, LoadFailed, and SessionLost. DataLoaded means **currently ready for mutation**, so it is false during transfer or unsafe saving. `DPU_DataStatus` mirrors the status as a Player attribute; Game admission initially sets it to CheckingAdmission. Queue/travel/run diagnostics use `DPU_PartyId`, `DPU_QueueStatus`, `DPU_TravelStatus`, and `DPU_RunStatus`.

Counts are public summaries. Actual unlocked ending/evidence identifiers and recent outcome IDs stay inside the server profile. `PlayerData` and leaderstats are views: editing ValueObjects never changes the save source. Settings are stored here but require future client code to affect rendering/audio. There is no arbitrary currency, paid progression, or persistent queue membership.

### Server integration example

From a future Game ModuleScript directly under `GServer`:

```lua
local runtime = require(script.Parent.Runtime).Get()
if not runtime or not runtime.Session:IsReady() then return end

-- The authoritative run service supplies these values after resolving a real run.
local ok, code = runtime.Data:RecordOutcome(player, {
    Id = runId,
    Survived = survived,
    Shift = shiftNumber,
    CasesSolved = solvedCaseCount,
    Ending = endingId, -- optional; omit when no ending was unlocked
})
```

`Data:Get(player)` returns a copy, never the live profile. Other APIs are `UnlockEvidence(player, id)`, `CompleteTutorial(player)`, `SetSetting(player, key, value)`, and `Save(player, false)` if a real milestone needs an immediate durability check. A mutation API returning true means accepted in memory; autosave/departure save persists it. Check the explicit Save result when immediate durability is required. Do not call Data:Save with release=true from gameplay; lifecycle owns release.

Outcome IDs prevent repeated grants within the latest 100 outcomes. This bounded run-history protection is not a permanent payment receipt ledger. A future run service must settle each run once and must not replay evicted outcomes. Shift settlement awards outcomes through this API.

### Storage guarantees and limits

- Production store: `DontPickUp_PlayerData_v1`, key `player_<UserId>`. Both places must share one experience.
- Schema 1, envelope Format 1. Reject malformed/future data; only a missing record creates defaults. Add explicit migrations in ProfileSchema before changing the format.
- `UpdateAsync` leases use unique tokens and a 180-second expiry. Loading polls up to 195 seconds, allowing an abandoned lease to expire. It never steals a live lease.
- Autosave runs every 50-60 seconds per player; failed autosaves retry after eight seconds. Mutations stop when less than 40 seconds remain on a confirmed lease. Expired/lost ownership disconnects the player instead of accepting unsafe writes.
- Saves are serialized per profile, use a snapshot, and preserve mutations made while an older snapshot is saving. Departure takes a final snapshot after earlier writes finish.
- Retried writes reuse an operation ID to recognize a committed write whose response was lost. Cancellation releases only the original owned record, preserving its data.
- Shutdown stops new work, closes profiles concurrently, and waits up to 25 seconds for profiles and in-progress load cleanup. Network calls themselves cannot be forcibly cancelled.
- Prolonged service outages or abrupt server loss can still lose progress since the last confirmed save. Failed final saves log an unconfirmed-save warning; no data system can promise lossless saving during every outage. Roblox [data-store guidance](https://create.roblox.com/docs/cloud-services/data-stores)

## Verification

Run all six Lune suites and the Core parity check in `README.md`. Tests compile every Luau file, use mocked Roblox instances/services and authored/generated hierarchy fixtures, and use a cooperative scheduler for coroutine interleavings in save/load/shutdown scenarios. They are local evidence, not a live Roblox certification.

Published checks still required:

- Verify the two place IDs share an experience and Game access is secured.
- Verify the Script Sync hierarchy, script types, single startup, and server-created remotes/folders in both places.
- Create solo and 2-4 player parties; test Friends/Public admission, kicking, host departure, unready, and repeated Start.
- Verify successful group arrival into one private Game JobId with all profiles loaded before gameplay.
- Exercise a disconnected member, partial failure, retry, failed reservation, and return to Lobby. Observe Incomplete/Interrupted states and present usable recovery UI.
- Save progression, return to Lobby, rejoin, and check both places see the same values. Test slow storage, rapid rejoin, server shutdown, and production access separately from Studio practice.
- Test different platform/cross-play settings. Inspect Server and Client Output and player diagnostic attributes.

No place was synchronized or published by the local implementation. No live DataStore or MemoryStore records were accessed by the test suites.
