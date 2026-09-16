# Current architecture and deployment

## Player experience

Normal Game play is first person with a free mouse cursor. Hold right-click to look around, then release to click items or controls. Touch and controller retain native camera input. `GClient/Interactions/FirstPersonCamera` uses Roblox's first-person mode and a transparent modal cursor control, leaving repair/timeclock camera ownership intact. Sync this ModuleScript with the Game client root. Verify cursor release, respawn, device switching and close-up return in Studio.

A strange night job, with short authored jokes and occasional unsettling customers. Repair remains the repeatable activity. The first repair and first night use shorter task selections; later nights add existing cleanup, fitting and testing variants. Notes are optional. Three Story nights and continuing Endless nights retain the existing endings, calm opening and profile rules.

After training, staff can use **Bench 1** or **Bench 2**. Interact with another bench once to select its job, then again to sit when its phone is ready. Both use the intake counter and shared parts shelf. To help a coworker, select their bench before collecting a part. A carried part must be deposited before changing benches. Each bench handles all steps including final testing. Solo players can keep using Bench 1.

Small items use mouse click, touch tap or controller centre aim + **RT/R2**. A small label and occluded highlight identify the aimed object. Dragging the touch camera does not activate an item. Doors, bench seating, counter intake and the fuse box retain larger-world prompts. HUD buttons remain a fallback for the current task. Clicking the receiver offers **LEAVE IT / ANSWER ANYWAY**; the phone base silences the call.

Thirteen optional records include the original timecard, tape and locked archive, plus notes, files, a newspaper, a photograph reverse, a recorded-message transcript and redacted documents. Records connect employee E. Voss (07), Ward Seven, Station Nine, Nina Vale, Mara Ellis and the Municipal Communications Office. They use a paginated reader with clickable/tappable/controller buttons and Q/B close. The transcript is readable text, not an uploaded recording. Original evidence IDs and the original three-record ending condition are preserved.

## Source organization

```text
src/
  LServer/
    Bootstrap.server.luau, Runtime.luau
    Core/                 canonical server persistence, admission and networking
    Parties/              party roster and countdown
    Queues/               authored world queues and signs
  LClient/
    QueueController.local.luau
    UI/                   authored queue view
    Networking/           scoped requests and timeouts
  GServer/
    Bootstrap.server.luau, Runtime.luau
    Core/                 identical independent-place deployment copy
    Services/             admission, prototype adapter, dialogue sequencing
    Shifts/               lifecycle, actions, snapshots, mode/ending rules, tuning
    Repair/               per-bench orders, puzzles, seats, Tools, templates
    Customers/            private customer catalog and authored conversations
    Anomalies/            event director, outdoor risk and threat execution
    Lore/                 private records and personal inspection rules
    World/                generated shop and world adapter
  GClient/
    PrototypeController.local.luau
    Networking/           one in-flight request and scoped deferred exits
    UI/                   HUD and document reader
    Interactions/         timeclock and direct world input
    Repair/               task controls, local pieces, camera and fitting
    Dialogue/             local subtitle typing and pagination
    Effects/              local scare presentation/audio
  LShared/, GShared/       intentionally empty
```

Executable controller scripts remain at each client root. Do not add empty folders just to match a template. No current server catalog needs to be shipped to clients; shared roots remain empty rather than exposing future clues. Existing intentional Core duplication is required by independent place deployment.

`ShiftService` composes cohesive method modules. Each method operates on the owning shift instance; modules contain no shared mutable run state. `RepairStations` maps players to explicit station records; `RepairFlow` receives the station record as an argument. It never temporarily swaps global order/work fields. All order IDs and work IDs remain unique within the run. Individual injuries, departure and work cancellation affect the correct operator; shared disturbances pause all orders. All living staff receive evidence votes regardless of their selected bench. Simultaneous evidence phones queue their ballots; only the visible ballot counts down, and the next gets a full response window. Profiles still store personal earned outcomes, not resumable shared campaigns.

## Network contracts

The existing per-place `Core/Network` remains the server boundary. No extra remotes were added. `GClient/Networking/Requests` builds payloads and serializes calls; deferred close/stand intents retain their original run/inspection IDs. World prompts share the same token bucket before entering gameplay validation.

`PrototypeAction` still allows six scalar fields. Direct input uses `{RunId, Action="Interact", Station, OrderId?, EventId?}`. The server maps the allowlisted station to the current action, checks the submitted order/event against that player's selected bench, then validates phase, proximity, tools and seating. `SelectStation` requires a living, clocked-in, briefed player near the actual bench. Puzzle controls retain RunId, OrderId, WorkId and PuzzleRevision checks. Clients never submit completion, damage or reward claims.

Snapshots add `StationId`, `PhoneName`, `TrayName` and a personal `Inspection` only after valid discovery. `Vote.OrderId` identifies the shared evidence order and can differ from `Order.Id`. An inspected record expires on movement, hazard, death/results or 90 seconds. `CloseInspection` uses the issued `InspectionId`; old closes cannot dismiss a newer document.

Authored conversations contain at most four lines. Only the current line is replicated with an ID, server start/expiry timestamps and optional speaker UserId. The client renders that player's authored line as **You** for them and their name for coworkers. It never reads chat or impersonates user-entered text. Subtitle settings and reduced motion are respected.

## Script Sync migration

1. Back up each Studio place, then sync **all four populated roots** with their new subfolders. Source root names retain exact casing. Lobby place is `110554757455252`; Game is `111652489432168`.
2. Server roots go inside their own place's ServerScriptService. Only `Bootstrap.server.luau` is a Script. Other server files are ModuleScripts.
3. Client roots go under StarterPlayerScripts. Keep the root LocalScript and all its folders together; all other client files are ModuleScripts. Modules are no longer flat siblings of the controller.
4. If Script Sync does not remove moved files, remove **only the obsolete script instances listed in [SOURCE_CHANGES](SOURCE_CHANGES.md)**. Do not leave old copies enabled or remove authored UI/models/templates. The already-retired QueueBillboardMotion also stays removed.
5. No Shared mapping, new remotes, dependency manager, schema migration, paid assets or audio uploads are required. Do not run both server bootstraps in one place.

## Manual assets and verification

The shop, second bench, customer figures and lore props are prototype geometry inside DPU_Prototype. The builder can replace them through the existing world/template adapters. Photographs currently show a readable written description; the tape/telephone message has a transcript. Final photographs, document textures, cabinet/drawer animation and recorded performances require authored assets. Do not claim these are finished art or voice acting.

Run the six Lune suites listed in README, the Core parity check and `git diff --check`. Local tests cover a full shared shift with simultaneous jobs, cross-station rejection, shared votes, injury/hazard isolation, lore secrecy/expiry/key requirements, serialized requests and simulated mouse/touch/controller input. They use mocked Roblox services and cannot verify rendered usability.

In Studio test: both benches' real seats, complete solo and cooperative jobs, phone/camera targeting, part delivery, stock recovery, clicking thin notes and the receiver, reader readability at portrait/landscape sizes, controller focus, touch taps versus camera drags, local avatar restoration, subtitle timing, effects and Output. In published clients test full party admission, one reserved server, profile ownership/saves, Lobby return and network latency. No Studio connector is available in this session; these live checks remain unperformed.
