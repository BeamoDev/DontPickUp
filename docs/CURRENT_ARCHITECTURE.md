# Current architecture and deployment

## Player experience

**Phone use / five-night release scope:** Install work now opens a server-owned customer phone menu with six reusable Shared softkeys. Connect the cartridge, wait for the server's two-second copy deadline, then check installation of CIVIC WATCH. Optional messages/recordings disclose only opened content. Contact calls and incoming ANSWER/IGNORE calls have text dialogue; taking a family message changes pickup dialogue. Asking to skip installation uses the existing team-vote rules, with explicit install/skip/investigate consequences. Browsing is optional and most phones contain ordinary records. A deliberately opened clue enters the team vote on finishing; investigation reopens its recovered record. The six-digit shop fax pickup flow stays separate.

Story has five chapter-specific nights. Night one allows testing/browsing; night two bans private records; night three onward bans private calls as well. Violations raise suspicion and affect inspection feedback; the summary shows record reads, private calls and violations. Calls do not cause the disconnected-phone hazard's damage or ending. This uses prototype text content, not recorded speech or a completed authored campaign.

Schema 2 adds saved Credits. DataService awards 10 per contributed completed repair and 50 per survived night through once-only outcome settlement. Best Night shows HighestShift minus one (zero before any survival); lifetime totals stay separate. Old valid schema-1 records migrate without resetting existing fields; the namespace is unchanged. Deploy both Core copies together. New server module: `GServer/Customers/PhoneSession`; Shared `Repair/PuzzleView` renders its whitelisted current-page snapshot.

Wires now expose four colored/numbered pairs through both physical dragging and button/controller selection. Optional `ReplicatedStorage.DontPickUpTemplates.RepairWire` accepts a BasePart or MeshPart cable authored along Z; the local adapter retains X/Y thickness and stretches/tints a clone. `tests/PhoneGameplay.luau` covers privacy, server installation timing, refusal/investigation, migration and four-wire completion. Real Studio rendering, authored cable fit and live persistence remain manual checks.

Customers now drop off their phone with a six-digit ticket and leave during repairs. Finish the final test, walk to the **FAX PHONE** on the service counter, enter the ticket and press **CALL CUSTOMER**. Its list shows both benches' ticket numbers and whether each phone is ready. The owner returns after the configured arrival time; the counter hands back the eligible phone and awards payment once. Wrong, incomplete or unfinished tickets do not summon customers; repeated calls do not restart the walk. Finished phones have no repair-patience deadline. The fax unlocks the mouse and supports keyboard digits, clickable/tappable/gamepad buttons, delete/clear and Q/B close. Customer-phone browsing and private calls are available at the bench.

`GServer/Customers/PickupService` owns ticket allocation, fax visits, validation and current ticket snapshots. `GShared/UI/FaxView` owns presentation only. Sync both new ModuleScripts together with updated GServer, GClient and GShared. The existing disconnected phone still handles horror calls independently. `tests/Pickup.luau` covers rules and input mocks; check actual customer walks, counter phones and keypad layout in Studio.

Repair text uses short actions and WORKING/BROKEN results. Check all three parts, then choose REPLACE for the broken one. Number-copy tasks display the whole code and the next number; screen, assembly, fuse and final-check instructions change with the current step. Training and night one replace circuit/memory/dial challenges with matching and three-number copy tasks. Later nights use easy tasks for two of three order seed classes; the remaining class uses existing harder task chains. Difficulty stays stable when retrying an order. Assembly and all four screws still require real inputs. The server keeps its ownership, tools, seating and revision checks.

Normal Game play is first person with a faint six-pixel white center dot. It gently pulses over available nearby interactions and pickups, using the existing aim query; reduced motion/flashes uses a steady brighter dot. Move the mouse to look; aim the dot and click small objects. Press **V** to free/relock the mouse or click the small mouse control when free. Repairs, timeclock interactions, document reading, menus and results release it automatically; the dot then follows the pointer. Roblox menus/chat use the native cursor. Touch and controller retain native input. `GClient/Interactions/FirstPersonCamera` controls cursor policy after the native camera update and never changes station camera transforms. `WorldInteraction` aims through viewport center while locked. Sync the complete Game client root. Local tests cover automatic/manual release, native-menu handoff, focus loss, input switching, respawn, aim and teardown; verify the actual cursor and camera feel in Studio.

A strange night job, with short authored jokes and occasional unsettling customers. Repair remains the repeatable activity. The first repair and first night use shorter task selections; later nights add existing cleanup, fitting and testing variants. Notes are optional. Five Story nights and continuing Endless nights retain the existing endings, calm opening and profile rules.

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
  LShared/                Lobby ReplicatedStorage.LShared
    UI/                   authored queue view
                          QueueBillboard renderer called by Lobby server
    Networking/           scoped requests and timeouts
    Geometry/             pure queue bounds helper
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
    Interactions/         timeclock and direct world input
    Repair/               camera and fitting adapters
    Dialogue/             local subtitle typing and pagination
    Effects/              local scare presentation/audio
  GShared/                Game ReplicatedStorage.GShared
    Networking/           one in-flight request and scoped deferred exits
    UI/                   reusable HUD and document reader
    Repair/               public definitions, task views and local piece descriptions
```

Executable controller scripts remain at each client root. Shared maps to **ReplicatedStorage.LShared in Lobby** and **ReplicatedStorage.GShared in Game**; do not deploy both into the same place. Shared contains reusable ModuleScripts and public definitions. Requiring them from a client still executes them on that client; QueueBillboard and QueueGeometry are called by the Lobby server. Moving source does not create a new execution service or reduce frame work by itself. Private customer/lore catalogs, puzzle generation/answers, ending rules, authoritative actions, profiles and admission stay in ServerScriptService. Existing intentional Core duplication is required by independent place deployment.

`ShiftService` composes cohesive method modules. Each method operates on the owning shift instance; modules contain no shared mutable run state. `RepairStations` maps players to explicit station records; `RepairFlow` receives the station record as an argument. It never temporarily swaps global order/work fields. All order IDs and work IDs remain unique within the run. Individual injuries, departure and work cancellation affect the correct operator; shared disturbances pause all orders. All living staff receive evidence votes regardless of their selected bench. Simultaneous evidence phones queue their ballots; only the visible ballot counts down, and the next gets a full response window. Profiles still store personal earned outcomes, not resumable shared campaigns.

## Network contracts

The existing per-place `Core/Network` remains the server boundary. No extra remotes were added. `GShared/Networking/Requests` builds payloads and serializes calls; deferred close/stand intents retain their original run/inspection IDs. World prompts share the same token bucket before entering gameplay validation.

`PrototypeAction` still allows six scalar fields. Direct input uses `{RunId, Action="Interact", Station, OrderId?, EventId?}`. The server maps the allowlisted station to the current action, checks the submitted order/event against that player's selected bench, then validates phase, proximity, tools and seating. `SelectStation` requires a living, clocked-in, briefed player near the actual bench. Puzzle controls retain RunId, OrderId, WorkId and PuzzleRevision checks. Clients never submit completion, damage or reward claims.

Snapshots add `StationId`, `PhoneName`, `TrayName` and a personal `Inspection` only after valid discovery. `Vote.OrderId` identifies the shared evidence order and can differ from `Order.Id`. An inspected record expires on movement, hazard, death/results or 90 seconds. `CloseInspection` uses the issued `InspectionId`; old closes cannot dismiss a newer document.

Authored conversations contain at most four lines. Only the current line is replicated with an ID, server start/expiry timestamps and optional speaker UserId. The client renders that player's authored line as **You** for them and their name for coworkers. It never reads chat or impersonates user-entered text. Subtitle settings and reduced motion are respected.

## Script Sync migration

1. Back up each Studio place, then sync **all six roots** with their subfolders. Source root names retain exact casing. Lobby place is `110554757455252`; Game is `111652489432168`.
2. Server roots go inside their own place's ServerScriptService. Only `Bootstrap.server.luau` is a Script. Other server files are ModuleScripts.
3. Client roots go under StarterPlayerScripts. Keep the root LocalScript and remaining adapters together. Sync `src/LShared` to **Lobby ReplicatedStorage.LShared** and `src/GShared` to **Game ReplicatedStorage.GShared**; preserve those exact folder names. Every shared file is a ModuleScript. Public dependencies use bounded waits during replication; a missing Shared root produces a sync error. Deploy each place's Client, Server and Shared together.
4. If Script Sync does not remove moved files, remove **only the obsolete script instances listed in [SOURCE_CHANGES](SOURCE_CHANGES.md)**. Do not leave old copies enabled or remove authored UI/models/templates. The already-retired QueueBillboardMotion also stays removed.
5. No new remotes, dependency manager, schema migration, paid assets or audio uploads are required. Do not run both server bootstraps or deploy the other place's Shared modules in one place.

## Manual assets and verification

The shop, second bench, customer figures and lore props are prototype geometry inside DPU_Prototype. The builder can replace them through the existing world/template adapters. Photographs currently show a readable written description; the tape/telephone message has a transcript. Final photographs, document textures, cabinet/drawer animation and recorded performances require authored assets. Do not claim these are finished art or voice acting.

Run the six Lune suites listed in README, the Core parity check and `git diff --check`. Local tests cover a full shared shift with simultaneous jobs, cross-station rejection, shared votes, injury/hazard isolation, lore secrecy/expiry/key requirements, serialized requests and simulated mouse/touch/controller input. They use mocked Roblox services and cannot verify rendered usability.

In Studio test: both benches' real seats, complete solo and cooperative jobs, phone/camera targeting, part delivery, stock recovery, clicking thin notes and the receiver, reader readability at portrait/landscape sizes, controller focus, touch taps versus camera drags, local avatar restoration, subtitle timing, effects and Output. In published clients test full party admission, one reserved server, profile ownership/saves, Lobby return and network latency. No Studio connector is available in this session; these live checks remain unperformed.
