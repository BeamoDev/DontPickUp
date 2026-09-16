# Lobby walk-in queues

Current folder deployment and latest controls are defined in [CURRENT_ARCHITECTURE](CURRENT_ARCHITECTURE.md). Preserve the new subfolders when syncing; older flat sibling descriptions in this historical integration detail are superseded.

## Sync and authored hierarchy

Sync the updated **LServer**, **LClient**, and **GServer** roots together. Lobby place: `110554757455252`; Game place: `111652489432168`.

- Lobby `LServer` belongs inside `ServerScriptService`, retaining its module subtree.
- Include `QueueBillboard.luau` as a sibling ModuleScript of `QueueWorld.luau`; it binds the updated world sign.
- Lobby `LClient` belongs inside `StarterPlayer.StarterPlayerScripts`. `QueueController.local.luau` is a LocalScript; `UI/QueueView.luau` and `Networking/QueueRequests.luau` are ModuleScripts under the same client root. Sync all three together with the updated Lobby server.
- Game `GServer` contains the matching Core and GameSession changes that preserve the selected mode during admission.
- The client uses the replicated copy of your authored `StarterGui.Queue`, at `PlayerGui.Queue`. No replacement ScreenGui or physical queue model is generated.

Screenshot-based UI contract:

```text
StarterGui.Queue (ScreenGui)
  Party (Frame)
    Background
    ScrollingFrame
      Story (TextButton or ImageButton)
        UIStroke
        Selected (Frame)
      Endless (TextButton or ImageButton)
        UIStroke
        Selected (Frame)
    Create (button)
    Lower (button)
    Raise (button)
    Expire (text)
    Limit (text)
    PlayerTitle
    Title
  Leave (button)
  Status (optional TextLabel)
```

The exact selected-marker name in the screenshot is `Selected`; lowercase `selected` is also supported. If Story has no marker, the client clones only the authored Endless selection marker into Story. It does not replace buttons or their layout. Both mode buttons need their own UIStroke.

Selecting a mode makes its marker visible and sets its stroke to **RGB 4, 255, 0**. The other mode's marker is hidden and its stroke becomes **RGB 58, 58, 58**. Story is the initial default. All buttons bind through `Activated` for mouse/touch/controller activation. [Roblox button events](https://create.roblox.com/docs/ui/buttons)

The controller reveals the ScreenGui, Party, scrolling frame, and required ancestor chains when opening. It preserves authored positions, sizes, images, and text styling. It rebinds when the ScreenGui is replaced on respawn. Lower/Raise change only the displayed capacity, clamped to 1-4. Both Story and Endless are implemented in the Game place.

`Queue.Status`, if authored, displays party count, departure time, preparation, and short notifications. If absent, the client creates a small `DPU_Status` label at the lower center, using Expire's font. Author `Status` to control its position and appearance. Existing controls are not moved. ImageButtons can use a child `Title` TextLabel for button wording. Leaving displays `Leaving...`; preparation and dispatch display different messages. Entry rejection and Studio completion remain visible even with Party hidden.

Screenshot-based world contract:

```text
Workspace.Queues
  Queue (Folder or Model; duplicate names are supported)
    InQueue (Folder)
    Model (...authored geometry...)
    Refs
      Enter (BasePart)
      EnterPos (BasePart)
      ExitPos (BasePart)
    UI (BasePart or container)
      BillboardGui
        Background
        Icon (ImageLabel or ImageButton)
          UIAspectRatioConstraint
          UICorner
          UIStroke
          Bar (Frame)
            Gamemode (TextLabel)
        Status (TextLabel)
        PlayerCount (TextLabel)
        Title (TextLabel)
```

Refs and UI can also be nested inside that Queue's authored Model: direct children are preferred, then a search scoped to the queue is used. Each pad gets a unique `DPU_QueueId` attribute even if every pad is named Queue. Missing refs produce a warning and leave that pad unbound until corrected. Late/replaced boards are rebound.

`Enter` is the entry box. The server enables `CanTouch` and binds `Touched` at startup: valid character contact immediately runs admission, places the player, and updates the sign without waiting for a maintenance tick. Readiness, capacity, live-character proximity, and leave protection still apply. Repeated limb contacts cannot duplicate membership. Touch listeners disconnect when pads are removed or the server closes. [Roblox touch events](https://create.roblox.com/docs/reference/engine/classes/BasePart#Touched)

The four-times-per-second bounds check remains a fallback for missed contacts, scripted movement, and avatars whose collision settings suppress touch events. Both paths check the live character root against the oriented box, with a one-stud horizontal margin and four-stud vertical margin for floor markers. The fallback does not require CanTouch or CanQuery. Configure the box to cover the intended entrance; normal network replication latency still applies. Failed admission retries remain bounded to twice per second.

`EnterPos` and `ExitPos` are ground-level placement markers. The server adds avatar root/hip clearance and moves the character there. Each member holds a stable slot; replacements use the first vacant slot without moving existing members. Both entry and exit use these offsets, with the first member on the marker and remaining slots spaced three studs apart behind it. Keep a clear area around both markers; actual avatar collisions, model dimensions, and placement need a Studio playtest.

## Player flow

1. Walk into an empty queue with loaded data. The server reserves that pad and moves you to EnterPos. Party setup and Leave become visible.
2. Choose Story/Endless and use Lower/Raise for a 1-4 player limit. `Expire` shows the remaining **20-second setup timeout**.
3. Press Create. Party setup closes, Leave stays visible, and the board updates to the chosen mode/leader/count.
4. Other players walk into the occupied queue to join. Physical entry makes them ready. Physical pads default to Public; change `WorldQueueAccess` to Friends if desired. General nonphysical parties still support both access modes.
5. Depart **20 seconds after creation**, including the **five-second final countdown**. A full party shortens the remaining time to at most five seconds. The board and client use the same server deadline. Leaving during the final countdown preserves the remaining party's deadline instead of resetting the timer. A solo queue with capacity 1 goes straight to that final countdown.
6. Leave is available during setup, gathering, and the final countdown. It removes the member and moves them to ExitPos. During save/teleport preparation it displays Preparing and is temporarily disabled.
7. After leaving, the player must step outside all entry boxes before entry can fire again, preventing overlapping exit/entry markers from trapping them in a rejoin loop. Once clear, entry is available immediately. Entry retries while standing at an unavailable pad run at most twice per second; each changed rejection reason produces one notification. Overlapping entry boxes select the closest marker deterministically.

Host departure transfers leadership to the oldest remaining member. Death, disconnect, setup expiry, walking more than 35 studs from EnterPos, or deleting a pad cleans up its physical membership. Walking away releases membership in place rather than pulling the player back to ExitPos. Create and Leave publish their completed physical state so setup does not flash back open while leaving. A transfer failure releases the remaining pad members so they can regroup. Server profile freeze/ownership rules remain enforced.

`QueueBillboard` binds `Icon`, nested `Icon.Bar.Gamemode`, `Title`, `PlayerCount`, and `Status`. Sync **LServer/Queues/QueueBillboard** and **LClient/QueueController** together for this hierarchy. `PlayerCount` shows the actual count/capacity, such as `2/3`. Empty signs display Story; a created party displays its confirmed mode. The title is `SHIFT AVAILABLE` when empty and `<HOST>'S SHIFT` when occupied, including after leadership changes.

| Queue state | Status | Accent |
| --- | --- | --- |
| Empty | `READY` | Green |
| Host choosing | `SETUP 20s` | Amber |
| Gathering | `STARTS 20s` | Green |
| Final countdown | `LEAVING 5s` | Amber |
| Saving/reserving | `PREPARING` | Amber |
| Transfer dispatched | `TELEPORTING` | Green |

Times come from the existing server deadlines, round up, and never become negative. The status text and an existing Background UIStroke (or direct BillboardGui UIStroke) share the accent. Fonts, images, size, and position remain authored; TextSize, TextScaled, TextWrapped, and UIScale stay exactly as authored. Hidden ancestor frames are revealed. Older `GamemodeIcon`/`MapIcon`, `Players`, `GreenStatus`/`Time`, and `PartyLeader` names remain fallback bindings for pads that have not been updated.

Optional string attributes `StoryIcon` and `EndlessIcon` on the **Queue folder/model** provide mode image IDs, for example `rbxassetid://123456789`. Without a nonempty override the actual icon's authored image is retained. Both ImageLabel and ImageButton icons work. Replaced icons and labels rebind within the same board; replacing the whole BillboardGui is discovered too. No art or world model is generated.

`InQueue` receives only this system's `DPU_<UserId>` ObjectValues pointing at members, plus a Count attribute. Other authored children are preserved. Queue state is exposed as `DPU_QueueState` on the queue and `DPU_WorldQueueId` on the player.

## Authored label sizing

Queue sign animations have been removed. Text, images, status colors, and visibility update directly; scripts do not change label Size, Position, UIScale, TextSize, TextScaled, or TextWrapped. Configure text fit in Studio.

Sync the updated **LClient/QueueController** and **LServer/Queues/QueueBillboard**, then restart Play. The retired QueueBillboardMotion ModuleScript is no longer required and can be removed from Studio if sync leaves it behind.

## Studio teleport preview

`Core/Config.luau` defaults to `StudioTeleportPreview = true` and `StudioSaving = false`.

After the countdown, Studio validates the roster, freezes each profile, and runs the save path. With StudioSaving false, those saves are in-memory practice saves. On success, Server Output prints:

```text
[DPU][Studio] SAVE/ROSTER CHECKS PASSED | Mode=Endless | Players=2 | Destination=111652489432168
[DPU][Studio] WOULD TELEPORT: ... No reservation, admission write, or teleport was attempted.
```

The server thaws the profiles, moves players to ExitPos, clears the pad, and hides their queue UI. A failed save/changed roster never prints success. With StudioSaving enabled, saving uses the existing isolated Studio namespace.

Other diagnostics are `[DPU][Queue] Bound`, `SETUP OPEN`, `CREATED`, `JOINED`, `LEFT`, and client `[DPU][Queue UI] Bound PlayerGui.Queue`. They help confirm each part of the flow. Prints verify only the checks that actually ran, not live Roblox teleport/storage reliability. Published servers use the real reserved-server path; Roblox requires published-client testing for TeleportService. [Teleport testing limitation](https://create.roblox.com/docs/projects/teleport)

## Physical UI network contract

All remotes are under `ReplicatedStorage.DontPickUpLobbyNet`:

| Request action | Payload | Response |
| --- | --- | --- |
| `GetQueueState` | none | `{ Ok = true, Queue = snapshot }` |
| `QueueCreate` | `{ Capacity = 4, Mode = "Story", EntryId = snapshot.EntryId }` | `{ Ok, Code?, Queue }`; requires the caller's current unexpired pad reservation |
| `QueueLeave` | `{ EntryId = snapshot.EntryId }` | `{ Ok, Code?, Queue }`; applies only to this visit |

`QueueStateChanged` pushes snapshots with Active, QueueId, EntryId, State, Configuring, CanLeave, Mode, Capacity, MaxCapacity, Count, HostUserId, ExpiresAt, Revision, and optional Message. Inactive snapshots contain Active=false and Revision, plus Message when notifying a player. Revisions prevent a delayed request response overwriting newer pushed state. EntryId changes on every visit, including reentering the same pad: delayed Create/Leave requests cannot affect the next visit. Setup drafts stay local until Create; capacity and mode are validated on the server.

`QueueRequests` serializes button actions and releases the busy indicator after eight seconds with a timeout notification. A timeout does not imply the server cancelled or accepted anything. Server snapshots remain authoritative; late responses cannot clear a newer request's busy indicator or show its stale failure. At most two unanswered invocations can remain outstanding. A server push confirming creation or a changed visit releases the old operation promptly.

The existing generic Join endpoint rejects physical-pad parties. Generic Leave/Ready/Start/Cancel/Kick actions also reject callers in physical queues; use scoped QueueLeave and automatic pad readiness/countdown. A client cannot choose a pad ID remotely and force itself into that queue; world entry is checked server-side before claiming even an empty pad and again after a yielding friendship lookup. The selected mode is stored in the server-side MemoryStore admission, and GameSession publishes the admitted mode as a Mode attribute and snapshot field.

## Verification

`tests/Queues.luau` uses authored hierarchy fixtures and real Lune vector/CFrame math to test pad lifecycle, rotated entry bounds, board/member updates, mode colors/markers, capacity bounds, exit behavior, death cleanup, and UI connection cleanup. `tests/Runtime.luau` verifies that the Studio preview exercises save/freeze/thaw without calling reservation, admission-write, or teleport APIs. Run all six suites from README after changes.

Still test in Studio: actual UI visibility/overlap and input, both modes, entering/exiting every pad, avatar clearance at markers, a two-client party, death/respawn, and a full countdown's Output. No screenshot-provided model or UI was rendered or inspected live during this source implementation.
