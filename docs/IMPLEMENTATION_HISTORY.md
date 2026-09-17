# Historical implementation notes

These notes describe earlier checkouts and the removed generated shop. They are retained as history, not current startup, mapping, or feature instructions. Current source and [CURRENT_ARCHITECTURE](CURRENT_ARCHITECTURE.md) take precedence.

## Previous repository notes

# Don't Pick Up repository instructions

These instructions apply to the entire repository.

- TV viewing: exact lowercase `tv` applies to a Model and routes through TaggedInteraction into a separate ModelInspection instance. GClient/Camera/TelevisionViewConfig frames a level view from local -Z, fitted to model bounds/viewport. Q/B/STOP WATCHING and normal inspection interruptions restore the camera. Viewing is local, mutually exclusive with other inspection/throw input, and sends no gameplay remote or screen/media mutation. Run tests/Television.luau with the interaction suites. Imported model orientation still needs Studio verification.

- Tagged throwing: exact lowercase `throw` joins the central tag system for small Models/BaseParts. Hold mouse/touch/RT/E to grab/charge, release to throw; Q/B/interruption cancels. GServer/Interaction/ThrowService owns reservation, token-scoped release/cancel, server-clock charge (1.5-second cap), server-owned physics and hold cleanup; never accept client force/charge/positions. ThrowInteraction queues releases/cancels arriving before the grab reply and updates a small local meter without streamed remotes. ThrowEffects owns only its short trail/particles/temporary collision filters; preserve authored effects and welds. No damage/reward/respawn is added. Read docs/THROWING.md and run tests/Throwing.luau plus existing suites. Actual physics/replication/visual feel remains a Studio check.

- Latest owner direction: active world interactions use CollectionService tags `Drink`, `Fax`, `Container`, superseding name-only discovery and earlier no-tags instructions. Tag whole Container/Fax Models; Drink supports a Model or BasePart. GShared/Interaction/InteractionTags defines resolution; GClient/Interaction/InteractionController centrally picks/highlights/routes; GServer/Interaction/InteractionService and TagBindings centrally bind tagged objects anywhere in Workspace. ContainerService supports multiple groups. DrinkService reserves server-side, validates admission/alive/standing/range/visibility, fades all parts/decals to 1 in 0.5 seconds and deletes only after every tween finishes. Do not add rewards. Preserve authored initial transparency, shared highlight styling, drawer view and fax keypad. Tags/removal/reparenting invalidate old identities and close obsolete inspections. Remove the prior Containers/ContainerInteraction ModuleScript on sync. Read docs/TAGGED_INTERACTIONS.md and run tests/TaggedInteractions.luau with Containers, Telephone and existing suites.

- Authored telephone (2026-09-16): GClient/GameController is the single active entrypoint for containers and telephone; remove the prior ContainerController on sync. GClient/Effects/PhysicalTelephoneController owns a local, interruptible close-up and physical keypad for a Model tagged Fax. Shared Telephone/TelephoneConfig defines a model-relative, bounds-fitted camera above/front and exact Key0-Key9, Key*, Key#, KeyClear/KeyClose, Dial and End mappings. Preserve InputArea.SurfaceGui.Frame.TextLabel and restore its text/visibility chain on exit. Reuse the existing idle ray and authored SelectionHighlight. Digits are local UI state; Dial explicitly says NOT CONNECTED. No server call, reward, hidden record, pickup or horror behavior is added. Close on movement, menus, typing, focus loss, death, respawn, removed model and camera replacement; restore camera and local avatar visibility. Read docs/TELEPHONE.md and run tests/Telephone.luau with existing suites. Exact Studio camera fit remains a live check.

- Latest owner direction (2026-09-16): archive prototype gameplay/views under exact `GServer/Prototype`, `GClient/Prototype`, `GShared/Prototype` folders; keep real game systems outside them. `GServer/GameConfig.PrototypeEnabled = false` gates all prototype imports and UI. Active `Containers/ContainerService`, `GameController` and `Interactions/TaggedInteraction` bind direct BasePart/MeshPart children named Box or Box followed by digits under any Model tagged `Container` in Workspace. First hover/click selects the whole Model tagged Container and enters a bounds-fitted camera view; only subsequent clicks inside that view toggle individual boxes. GClient/Camera/InspectionCamera owns camera restoration; GClient/Camera/InspectionFrame also supplies telephone framing math. Q/B/CLOSE VIEW exits, and movement/menus/focus loss/death/respawn/removal cancel inspection. Hover clones the authored `ReplicatedStorage.Assets.SelectionHighlight` into the selected model or box (root ReplicatedStorage.SelectionHighlight is a fallback for the supplied screenshot). Click toggles a smooth 0.35-second world-Z offset of -0.8 studs relative to each box's closed CFrame. Use the Container tag; no custom authoring attributes, generated highlight styling or hints. Shared tuning lives in GShared/Interaction/ContainerConfig. Preserve authored welds/models; moving boxes must be anchored and queryable, matching Label1/Label2/etc parts now move with Box1/Box2/etc using identical tweens. Unanchored labels already welded to their box follow the weld; independent labels tween explicitly. Preserve label offsets/rotation, cancel and restore labels with their box, and never weld them to the fixed cabinet. Run tests/ContainerLabels.luau. Keep first-person input and server admission/alive/range/line-of-sight/revision/cooldown checks. Read docs/CONTAINERS.md and run tests/Containers.luau plus existing suites. Source paths below are updated; older root-controller and startup descriptions are superseded by this deployment layout.

- Use short, concrete repair instructions for younger players. Diagnosis shows WORKING/BROKEN after each check; never require voltage, resistance or signal jargon. Training and night one use simple matching plus three-number visible copy tasks; later orders keep those easy tasks for two of every three seed classes. Harder tasks remain occasional. `WorkPuzzles.IsEasy` owns this selection; retries keep the order seed. Keep server validation, all three diagnosis checks, assembly and four screws. Number-copy UI shows COPY/NEXT, and phase-based tasks explain only the current step.

- Game uses `GClient/Camera/CameraController`: first person with a six-pixel white dot at 0.45 transparency and centered mouse during ordinary keyboard/mouse play. V and the small mouse button toggle manual release. Automatically release for local repair seating/work, timeclock, notes, game modals, results/death, Roblox menus, text input and lost window focus. The free dot follows screen coordinates; Roblox menus/text input use the native cursor. WorldInteraction uses a viewport-center ray while locked. Reuse its bounded hover query for a slow 1.2-second dot transparency pulse (0.15-0.45) over enabled, nearby interactions; pickup hints respect the local order, stock, carried part and kit. Reduced motion/flashes uses steady 0.2 transparency. No extra raycast/render loop for the pulse. One small post-camera cursor binding enforces policy without camera transforms, scene scans or remotes. Preserve native touch/controller and repair/timeclock camera ownership; remove bindings/UI and restore input on teardown. This supersedes always-free/right-click-look behavior. Lobby remains unchanged.

## Latest owner direction and architecture (2026-09-15)

- Latest release scope supersedes earlier three-night notes: **Story is five nights**, Endless continues. The 1980s government-controlled society is central. `Customers/PhoneSession` privately owns a usable phone during the existing Install work stage: explicit CIVIC WATCH installation, optional messages/recordings/contact calls, occasional answer/ignore calls, and team approval for refusing spyware. Reuse Shared PuzzleView's six softkeys. Never replicate unopened content; retain run/work/order/revision, operator, seat, tool and distance checks. Interrupted work keeps order-local discoveries/program state but receives a fresh work identity. Only deliberately discovered clues enter evidence voting. Investigate returns to a recovered record on the phone. Customer calls never mutate the disconnected horror-phone ending counter.
- Government rules now prohibit private records from night two and private calls from night three; PhoneSession logs unique records and actual calls, with suspicion on violations. Inspectors review the log. The night summary shows activity totals. These are explicit game rules, not assertions about the reference video's hidden arrest logic. Later Story chapters add Mira/Reed records linking CIVIC WATCH to the Ministry archive.
- `ProfileSchema.Version = 2` adds `Stats.Credits`, migrating valid v1 profiles with zero starting credits and preserving all existing progress/settings/outcome IDs. Keep the `DontPickUp_PlayerData_v1` namespace and practice store unchanged. Canonical LServer/Core owns edits; sync Game Core. DataService settles 10 Credits per contributed repair plus 50 per survived night once per existing outcome ID. Leaderstats are **Best Night** (`HighestShift - 1`, minimum zero) and **Credits**. Lifetime totals remain in saved Stats/replicated Statistics. No purchase or client-grant remote is added.
- Wires have four numbered/color-coded input/output pairs; BatteryFit and Assembly retain three. Both physical and button/controller adapters use the wire slot count. Optional `DontPickUpTemplates.RepairWire` BasePart/MeshPart is a local cable visual, length along Z, thickness from X/Y; authored template remains untouched. Run `tests/PhoneGameplay.luau` and all existing suites; Studio presentation and published migration still need live checks.
- `Services/EngagementService` owns fictional employee reviews derived only from allowlisted actions inside the current run, non-duplicated night awards, run-local handbook totals and cooldown-protected authored team callouts. Public snapshots expose employee status but not unopened observations. Never inspect player chat or external account activity. Run `tests/Engagement.luau`; the generated employee board, avatar thumbnails and vote markers still require live Studio checks.

- Customer drop-offs now receive six-digit tickets from server-only `Customers/PickupService`. Tickets remain distinct across active orders and advance across nights/runs in the server. `Test -> ReadyForPickup -> PickupArriving -> Return`; only a valid fax call starts collection, and only the final handover awards repairs/payment. Customers leave after intake and come back after dialing. The counter fax is separate from the disconnected horror phone. Shared `UI/FaxView` keeps keypad digits local and sends one `DialTicket` intent with FaxId/Ticket; visits require living, clocked-in, briefed, standing staff within five studs, expire after 90 seconds, and close on movement/hazards/injury. Finished orders stop their repair deadline. Pickup approaches pause/restart across hazards. Both benches share the fax; counter handovers resolve the actual eligible order. Run `tests/Pickup.luau` alongside existing suites. Source/mock checks do not verify Studio rendering.

- The owner likes the current flow and explicitly prioritizes actual customer-phone interactions: install the government program, answer/ignore calls and browse phone contents. These are core gameplay, even when deeper lore remains optional. Read `docs/PHONE_GAMEPLAY_RESEARCH.md` before expanding repairs. Current Install puzzles and automatic evidence votes are placeholders for this experience; the disconnected shop-phone hazard is separate. Preserve the bench flow and short tasks. The owner supplied the full reference-video transcript after direct retrieval failed; it was reviewed. It also establishes outgoing contact calls, calls to arrange pickup and a daily instruction to dial 0042 for a firmware update. Do not claim the footage, completed installation or hidden arrest conditions were verified. Keep required work calls distinct from optional snooping.

- Shared is now populated and required: `src/LShared` -> Lobby `ReplicatedStorage.LShared`; `src/GShared` -> Game `ReplicatedStorage.GShared`. Preserve the live folder names `LShared` and `GShared` in their respective places. Sync each Client/Server/Shared trio together. Client roots retain entrypoints and stateful input/camera/effect adapters; Shared holds reusable views, request helpers, public repair definitions and Lobby geometry/billboard helpers. See the move manifest before removing obsolete copies. Never put private catalogs, generated answers/seeds, gameplay mutations, profile/admission modules or ending rules in Shared. This supersedes earlier empty-shared/no-mapping instructions. Shared modules execute on whichever side requires them, not automatically in a different runtime.

- The latest request favors a simple, funny, readable night job. Keep deeper government/conspiracy lore optional; use short authored customer/player/coworker exchanges, never player chat. This supersedes a uniformly serious presentation.
- Read `docs/CURRENT_ARCHITECTURE.md` and `docs/SOURCE_CHANGES.md`. Modules are now grouped under responsibility folders within the exact existing L/G roots. Root bootstraps/controllers stay executable; all moved files remain ModuleScripts. Legacy descriptions of flat sibling modules below are superseded by this deployment map.
- Two independent repair benches supersede the previous single-bench restriction. `RepairStations` owns per-bench order/work state; `RepairFlow` receives explicit station records. Shared hazards pause both; personal injuries cancel only the victim. Never swap global order/work fields as a temporary context. Cross-bench votes use `Vote.OrderId`.
- Keep the first repair and night short: added puzzle stages begin on later nights. Preserve the existing task catalog and button/controller fallbacks.
- `LoreService` validates personal, expiring inspection and discloses only the inspected record. Thirteen optional records keep existing evidence IDs and the original three-record ending condition. Readable descriptions/transcripts are placeholders for future authored artwork/audio.
- `WorldInteraction` uses direct mouse/touch/RT input for small objects, an aimed highlight and a short label. Large door/bench/counter/fuse interactions retain prompts. No per-frame remotes. `Networking/Requests` serializes calls and keeps deferred close intents scoped to their original run/visit; restock puzzle input has no OrderId.
- Keep server customer, dialogue and lore catalogs private. Shared roots contain only public reusable code. Preserve canonical LServer/Core and identical GServer/Core; do not add compatibility copies of moved modules.
- Run `tests/Improvements.luau` in addition to the five existing suites. Source/mocked tests do not establish actual Studio/device usability or published persistence/teleports.

## Start here

- Read `README.md`, inspect the current file tree, and check Git status before editing.
- Read the complete owner-supplied game context at the end of this file before designing or changing gameplay, narrative, presentation, or progression. It is the design source of truth; the implementation notes above it describe what currently exists, not the finished game.
- This Roblox horror project has parties, private teleports, profiles, authored Lobby queues, and a generated Game-place prototype. Read `docs/SERVER_SYSTEMS.md`, `docs/LOBBY_QUEUES.md`, and `docs/GAME_PROTOTYPE.md` for runtime contracts and validation limits. The prototype now supports a five-night Story arc and continuing Endless nights; the larger authored campaign remains future work.
- Current source, the user's latest instructions, and the actual Studio hierarchy take priority over dated notes. Update this file and `README.md` when mappings or architecture become concrete.
- Preserve unrelated changes and Studio-authored UI, models, audio, lighting, and templates. The other projects are references for conventions; do not import their gameplay, identifiers, data, secrets, Git history, or remotes.

## Game direction

- The inspiration is the Steam game linked in `README.md`; this repository implements the user's Roblox game.
- The latest owner request specifies **1-4 players**, superseding the older 1-5 context preserved below. This is a cooperative psychological horror game set during the **1980s**, inside a government-controlled phone/electronics repair shop. Players are Device Repair Associates working night shifts.
- Repair is the main repeatable activity: intake, diagnosis, parts retrieval, disassembly, repair, software installation, reassembly, testing, return, and payment. Preserve satisfying ordinary work as the foundation for gradual horror.
- Each shift begins with new government regulations. Devices expose linked evidence across multiple customers and days; players report, hide, or investigate it. Choices affect government loyalty/suspicion, civilian trust, resistance support, customer outcomes, later events, and accumulated ending conditions.
- Major multiplayer story decisions require a team vote. Repairer, Restocker, Camera Operator, Spy Watcher, and Distractor are freely interchangeable activities, not mandatory classes. Every required task must remain possible solo.
- The tone is quiet, oppressive, uncertain, and paranoid, with occasional supernatural anomalies. Keep most repairs normal; the owner's approximate distribution is 70-80% normal, 15-25% minor unusual information/anomalies, and about 5% major events. These are pacing targets, not independent probabilities to sum blindly.
- Use the dark PS2-inspired, low-poly art direction and readable retro government-terminal UI. Respect the period props, rusty horizontal window bars, and restrictions on modern/futuristic technology. Preserve existing authored queue UI until an explicit visual change is requested.
- The full context below includes all repair examples, role activities, anomaly ideas, inspector thresholds, story variables, possible endings, art/UI guidance, public copy, and development principles. Preserve the distinction between firm principles and examples or possible story outcomes; examples do not establish a finished campaign or implemented content.
- Treat phone data and malware installation as fictional in-game content and mechanics.
- Every new feature should support repair, observation, communication, choice, or consequence. Keep short tasks and instructions clear for younger Roblox players; introduce mechanics gradually.

## Design-to-implementation gaps and next backend work

- **Player count:** keep 1-4 in Config, queues, admission rosters and Studio direct entry. All required tasks must work solo; each of two repair/testing benches supports cooperative handoffs with its own work reservation.
- **Mode rules:** `ModeRules` defines a five-night Story arc with chapter-specific evidence and an ending at final survival or personal death. Endless continues until no staff survive or everyone leaves. No Story ending unlocks in Endless. Difficulty growth is capped, with the calm opening and scare limits preserved. `StudioGameMode` selects the direct-Studio preview mode.
- **Run state:** `ShiftService` owns nightly setup, tutorial on night one, six-minute nights, work/votes/hazards, outcomes and ready checks. A continuing night preserves HP/death, decisions, suspicion, answered calls and personal discoveries; resets supplies/work/kit; and issues a fresh RunId. Only living staff must ready to continue; all remaining staff must ready for a new run after completion. Outcome recording must finish before continuation. Shared campaign checkpoint/resume is still unimplemented.
- **Saving:** current profiles hold lifetime statistics, settings, highest shift, personal evidence/ending unlocks, and recent outcome IDs. They do not save a playable shared campaign. Keep shared story state separate from individual profile summaries. Establish campaign ownership, checkpoint boundaries, rejoin/host-departure behavior, and how mixed-progress friends join before shipping campaign resume.
- **Repair and stock:** the prototype has a compact stockroom with three bins on one shelf, restock crate, authentic carried Tools, and two repair/final-test chairs, each with its own order/work reservation. One repair-kit pickup supplies Tester, Screwdriver and Cartridge together. ShiftService owns reservations and seat/work validation; Workshop owns physical Seat/Tool instances. Collect inside the room, deposit at the bench, sit to diagnose/fit/secure/install/test. Secure is an owned work puzzle: assemble board/battery/cover in order, then turn each of four screws three times. It requires the current order, screwdriver and real seating. Unused carried parts recover on death/disconnect/tool loss; deposited parts survive cancellation. Independent bench allocation is implemented; detailed disassembly and authored hand animations remain future work.
- **Evidence and voting:** store evidence links and hidden consequences server-side. Separate discovering information from committing Report/Hide/Investigate decisions. Resolve major team choices once with explicit eligible-voter, tie, timeout, and disconnect rules; a solo player must be able to resolve the same decisions.
- **Regulations and consequences:** represent each day's active directives explicitly and evaluate actions against that day's rules. Preserve an ordered decision history and schedule later customer/story consequences rather than scattering unrelated booleans across modules.
- **Inspection and pacing:** future inspectors need a state machine around the owner's 0/25/50/75/100% suspicion stages. A separate event scheduler should control quiet periods, compatible simultaneous events, escalation, and solo/team workload. Leave movement, character appearance, animation, audio, and rendered scares to adapters for the builder/modeller assets.
- **Recommended first playable backend slice:** start one shift, issue its regulations, process a normal repair using stock, process one evidence-bearing repair, resolve a team decision, and settle a shift summary/checkpoint. Exercise this with server tests or a temporary debug driver; the authored world can connect to the same interaction contracts later.
- The owner is waiting for the modeller and builder. Prefer backend rules, content schemas, deterministic scenarios, integration contracts, and meaningful failure-path tests while assets are being made. Do not replace the planned authored shop or devices with unsolicited generated models.

## Repository and sync boundaries

- Repository configuration, agent instructions, and project documentation belong at the repository root, never inside `src/`. Put future extended documentation in `docs/` and local test tools in `tests/`.
- Keep runtime Luau source under `src/` with the user's environment prefixes: uppercase `L` means **Lobby**, uppercase `G` means **Game**.
- The existing source folders are `src/LClient`, `src/LServer`, `src/LShared`, `src/GClient`, `src/GServer`, and `src/GShared`. Preserve this exact casing. These filesystem names do not establish the live Studio hierarchy.
- Keep Lobby and Game bootstraps, remotes, state, and dependencies separate. Do not collapse them into unprefixed `client`, `server`, or `shared` roots.
- Lobby place ID is `110554757455252`; Game place ID is `111652489432168`. These were supplied by the user. Verify both are in one experience before live tests. The bootstraps require their parent containers inside their respective place's `ServerScriptService` and resolve modules relatively; the actual Studio sync hierarchy has not been inspected.
- Use the sibling projects' Roblox Script Sync workflow. Do not add Rojo, Wally, Rokit, generated places, dependency manifests, or CI commands unless the task actually establishes that tooling.
- Code in either shared container is client-visible. Cross-environment sharing must be explicit; a Game server cannot assume Lobby instances are present.
- Each server environment has exactly one executable `Bootstrap.server.luau`. Other server source files are ModuleScripts. Do not run both bootstraps in one place. The server creates `ReplicatedStorage.DontPickUpLobbyNet` or `DontPickUpGameNet`; the matching Shared root must also be synced to ReplicatedStorage.LShared or ReplicatedStorage.GShared.
- `LClient/Matchmaking/QueueController.luau` is the Lobby LocalScript, deployed under `StarterPlayerScripts`, using `ReplicatedStorage.LShared.UI.QueueView`. Bind `PlayerGui.Queue.Party` and `Queue.Leave`; preserve all authored sizes/positions. Mode buttons are `Party.ScrollingFrame.Story` and `.Endless`. Show the selected button's `Selected` frame and use UIStroke RGB `(4, 255, 0)`; hide the other marker and use `(58, 58, 58)`. Reuse an authored Selected marker for Story if it is missing.
- `src/LServer/Core` is canonical for common server code. Run `tests/SyncCore.ps1` to refresh the identical `src/GServer/Core` copy, and run the parity check. Do not move persistence or admission modules into replicated shared folders.

## Existing server foundation

- Staff spawn outside. OpenClock opens a per-player, 30-second Timeclock inspection; ClockIn requires its current FocusId and being inside within five studs. Movement/expiry closes inspection. ClockIn precedes ReadRules and is idempotent. Door/radio/lamp/log remain distance-checked activities. Restocking sorts a manifest and selects the lowest supply when there is no order. Replay resets entry and physical kit.
- `GServer/Prototype/Repair/WorkPuzzles` owns diagnosis, polarity, wire matching, keypad, software-code, final-test and crate-sorting inputs. Work never completes by waiting on a puzzle timer: 120 seconds cancels it. PuzzleInput requires current RunId/WorkId/OrderId/revision, work ownership, distance, seat, actual tool, and valid phase. Only the operator receives puzzle controls. Solved Repair alone starts a 1.2-second fitting animation, then Secure. World pickup prompts use hold durations; collection reserves stock on successful activation. Secure is a puzzle chain, never a Contact payload increment.
- Tester, Screwdriver, Cartridge and optional BrassKey are physical reusable Tools tracked by identity in Workshop. Required tools must actually be in the player's Backpack/character. Lost tools cancel work and can be recollected. Kit and replacement reservations use separate ownership maps; cleanup cannot destroy unrelated Tools.
- `GServer/Prototype/Lore/ShopSecrets` contains three optional discoveries: Timecard, Tape and a key-locked Locker. Only inspected text is exposed; evidence uses UnlockEvidence. Personal run discoveries reset on replay while saved evidence remains. Re-reading gives no money/repair reward.
- `GServer/Prototype/Shifts/EndingRules` owns eight Story conclusions. Priority: death, answered phone, suspicion >=50, personal three-record archive, Investigate, Hide, Report, ordinary survival. Resolve personal death immediately and survival only after Story night five. Accumulated team choices affect survivors; dead members retain their own ending. `RecordOutcome` runs once per player per earned night with a fresh identifier and actual night number; Endless and interrupted survivors receive no Story ending.

- The owner explicitly requested a playable Game prototype while waiting for assets. `PrototypeWorld` generates only `Workspace.DPU_Prototype` (default origin `(0,0,400)`, optional `Workspace.DontPickUpPrototypeOrigin` BasePart), customers, stations, figures, lamps, and spawn. Preserve other Workspace content. `GServer/GameConfig.PrototypeEnabled` controls startup. `GClient/Session/SessionController.local.luau` belongs in Game StarterPlayerScripts with sibling `PrototypeView`; it owns `DPU_PrototypeHUD`, objective highlight, and spectator camera behavior. This temporary content can later be replaced by authored adapters.
- `GamePrototype` connects ShiftService to world, network, admission, and DataService. Never start before GameSession readiness. One safe tutorial repair starts the first clock; later clocks start after all living staff clock in and acknowledge the directive. Dead/late spectators cannot work. Departures after full admission preserve the remaining team; partial initial arrivals still fail closed. A last-survivor departure interrupts the run without inventing outcomes. Post-start published admissions cannot rejoin.
- Prototype actions require current RunId and relevant OrderId/EventId. Future order content stays server-side. `RecordOutcome` records contributed repairs and survival/death with one server-issued ID per player/run; delayed recording and saves retry. Tutorial/evidence use existing APIs. Revenue, stock, suspicion, and decisions are run-local, not persistent money/campaign state. The schema is unchanged.

- `PartyService` owns parties in one Lobby server. A player may belong to one party. Hosts create parties of 1-4 players, choose Friends/Public, kick members, and start/cancel the five-second countdown. Every member must be ready and data-ready. Friendship checks must revalidate the roster after yielding.
- `QueueWorld` binds each child of `Workspace.Queues` by its `Refs.Enter`, `EnterPos`, and `ExitPos` BaseParts, plus `UI.BillboardGui`. `WorldQueueService` reserves an empty pad for 20 seconds, opens setup, and creates an automatic queue. Physical entry is readiness. Depart after 20 seconds including the final five-second countdown; full parties shorten the deadline, and member departure never lengthens it. Keep stable per-member placement slots for entry/exit. Leave/death/expiry releases membership; avoid immediate reentry until the player steps clear. Walking away releases membership without moving the character back. Only queue-owned ObjectValues may be removed from `InQueue`.
- `QueueWorld` binds `Refs.Enter.Touched` at construction and enables CanTouch for immediate server admission/placement/sign updates. Keep root-bounds validation, profile readiness, capacity, busy/retry and leave guards shared through TryEnter. The quarter-second bounds poll is a fallback; do not put a polling wait back on successful contact. Disconnect pad touch listeners on removal/shutdown. No client membership prediction is used; live network responsiveness still needs Studio/multiplayer verification.
- Physical Create/Leave requests require the current per-visit `EntryId`. Never allow delayed requests to alter a later visit. Generic Leave/Ready/Start/Cancel/Kick reject physical queue members. `LClient/Matchmaking/QueueRequests` owns pending operations, bounded unanswered requests, timeout feedback, and stale-reply ownership; server snapshots remain authoritative. Deploy it under Lobby ReplicatedStorage.LShared.Networking; QueueView lives under LShared.UI and QueueController stays in StarterPlayerScripts. Optional authored `Queue.Status` displays queued status and notifications; QueueView creates/removes a small fallback label when absent. Preserve existing control geometry and prevent ImageButton text updates from revealing hidden setup ancestors.
- Physical queues default to Public; generic API parties retain Friends/Public. Story/Endless and versioned GameData (mode, starting night one, party size) live in the MemoryStore admission. Client teleport metadata is presentation-only. GameSession uses the trusted ticket, and DataService loads profiles through the source save/release handoff. Legacy tickets without GameData remain compatible. Never send profile payloads or private-server access codes in TeleportData.
- `LServer/World/QueueBillboard` renders the owner's updated `UI.BillboardGui` children: `Icon` with nested `Bar.Gamemode`, `Status`, `PlayerCount`, and `Title`, plus Background. QueueBillboard prefers these names and retain the older GamemodeIcon/Players/GreenStatus aliases. Empty means `SHIFT AVAILABLE / READY`; occupied titles use the current host's shift. Show actual count/capacity and the server departure deadline. Setup/final countdown/preparation use amber; ready/gathering/dispatch use green. Apply these state colors only to Status.TextColor3. Never recolor Background.UIStroke, Title.Frame.UIStroke, direct board strokes or any other authored sign borders. Preserve authored geometry/fonts and all text sizing/wrapping settings. Legacy MapIcon/PartyLeader/Time remain fallbacks. Optional Queue attributes StoryIcon/EndlessIcon override the authored image; capture each replacement image instance's own fallback before applying an override.
- `StudioTeleportPreview = true` runs roster/save checks, prints the selected mode/roster/destination, and releases the queue. It makes no reservation, admission write, or real teleport in Studio. Never print a passed preview after failed saving, and do not treat practice-save output as live verification.
- `TravelService` freezes and saves all profiles before dispatch. Reserve one private Game server per party; reuse its access code across bounded retries. Correlate `TeleportInitFailed` with the active attempt. Revoke failed admissions before thawing profiles; never reopen an ownership-lost profile.
- `TicketStore` issues expiring MemoryStore rosters. Game admission checks source universe/place, destination place/private server, allowed user, expiry, revocation, and destination JobId. Ticket IDs are not permission by themselves; never expose access codes or profile data in teleport payloads.
- `GameSession:IsReady()` is the gate future gameplay must use. Every expected member must arrive and load. Incomplete or interrupted parties must not start a run. Cross-instance/cross-play splits are rejected rather than allowed to run separate copies of one party.
- `DataService` is the only mutation/save owner. `SessionStore` uses atomic UpdateAsync leases, owner-checked serialized saves, and final release. A failed load never becomes a saveable default. Preserve cancellation and ambiguous-write recovery paths.
- Both places use `DontPickUp_PlayerData_v1`, schema 2 (migrated from schema 1). Studio defaults to in-memory practice; enabling StudioSaving uses the separate `_STUDIO` store. Never use production data for Studio practice.
- `leaderstats` and `PlayerData` values are replicated views. Never save values read back from instances. Hidden evidence/ending IDs and the profile payload remain server-side. Future systems award progress through `DataService:RecordOutcome`, `UnlockEvidence`, and `CompleteTutorial`, never a client reward remote.
- Outcome replay protection retains the most recent 100 server-issued IDs. It is not a permanent receipt ledger; never reuse it for paid purchases or replay old outcomes after eviction.

## Gameplay authority and state

- Repair tasks: `GServer/Prototype/Repair/RepairTasks` provides Probes, BatteryFit, Wires, Circuit, Dials and Memory behind WorkPuzzles. Probes must acquire all three readings before diagnosis. Pair moves encode source*10+destination (11-33 for three-piece tasks, 11-44 for four wires); circuits/dials use controls 1-6 plus check 7. Memory uses server-clock reveal timing with a 0.8-second lead; control 7 replays and resets progress. Keep current RunId/WorkId/OrderId/revision, ownership, proximity, tool and seating checks. Only solved Repair starts the existing fitting tween. Never accept client completion flags, pointer coordinates, or elapsed-client-time claims.
- `GServer/Prototype/Repair/BenchTasks` adds Clean, Debris, Broken, Screen, SIM, Fuse, Charger, Sort, Assembly, Screws, Buttons, PhoneNumber, Waves, Meter, Stamp and Speaker. WorkPuzzles selects short seeded chains when expanded=true (all shift work), hides Pending/Seed in snapshots and preserves monotonically increasing revisions between stages. Only the last solved stage completes work or starts the fitting tween. Meter dwell uses server elapsed time; speaker replies are gated by the server demonstration deadline. Secure always requires four screws and no longer accepts Contact increments.
- `GShared/Prototype/Repair/BenchTaskView` is a required sibling of RepairTaskView. It shares twelve pooled controls and the existing drag protocol, draws two wave traces and a drifting meter, and plays local pitched speaker cues with numbered/silent alternatives. No new per-frame remotes or scene scans. Update only the moving meter between unchanged snapshots. World prompt hold durations: tool 0.5s, part 0.85s, stock 1s, bench 0.4s, counter 0.6s, fuse 1.2s. Keep escape controls immediate. Lobby sign animations remain removed.
- `GShared/Prototype/Repair/RepairTaskView` is a sibling ModuleScript used by PuzzleView. It pools native controls, wire lines, dial faces and one drag preview; no per-frame remotes or scene scans. Mouse/touch drags submit once on release; tap-source/tap-destination supports touch and controller navigation. Cancel held input on task/revision change, busy state, menu/hazard/death, resize, lost focus and teardown. Memory cues use the existing bounded update and text-only feedback under reduced flashes. Keep black 0.5-transparency content panels and one active task surface.

- Lobby queue signs have no UI animations. The latest owner request supersedes the earlier ten-percent pulse rule. Do not tween or change label Size, Position, UIScale, TextSize, TextScaled, or TextWrapped. QueueBillboardMotion is removed and QueueController must not load it.

- Prototype UI uses black content panels at `BackgroundTransparency = 0.5`. Keep only the compact header/objective during ordinary play. SHIFT INFO exposes ticket/team/directive details; modals and local puzzle/timeclock interactions suppress the ordinary HUD. Preserve urgent feedback and a touch-accessible close/stand control. Generated prototype prop labels use small white text, `UDim2.fromScale(3.8, 0.55)` (world studs), transparent backing and `MaxDistance = 22`; this does not alter authored Lobby queue billboards.

Apply these rules when the corresponding systems are implemented:

- The server owns assignments, phone ownership/access, accepted actions, task completion, suspicion/danger, death, outcomes, rewards, and saved progression.
- Validate remote payload types, bounds, action eligibility, player state, and request frequency. A client reports intent; it does not choose the authoritative result.
- Keep unrevealed phone evidence, future story content, hidden threat decisions, and secret ending conditions server-side. Replicate only the information needed for the player's current interaction.
- Model phone/task/session transitions explicitly so repeated clicks, delayed requests, respawns, or reconnects cannot duplicate completion or apply an action to the wrong phone.
- If Lobby and Game use separate places, treat teleport payloads as untrusted input and verify admission and progression on the receiving server. Record real place IDs only when supplied or verified.
- Give this project its own persistence namespace. Never copy another game's live DataStore names. Do not overwrite stored data with defaults after a failed load; handle session ownership, retries, migrations, and shutdown when persistence is introduced.
- Keep credentials out of source. Purchases, if introduced, need server-side validation and durable duplicate-grant protection.

- `GServer/Prototype/World/ShopLayout` generates a compact 44x42-stud main shop and back stockroom with one eight-stud doorway. The latest owner request supersedes the earlier eight-room design: avoid adding separate stations for each repair step. Counter, two benches, one kit pickup and grouped replacement bins form the core loop; phone/fuse/shelter support horror events. Inspection records sit on the counter and only prompt during inspection. Preserve authored assets outside DPU_Prototype and keep secrets unlabelled. Layout.Access/Rooms blocks interactions through the partition; World:Outside uses Layout.Bounds.
- Diagnose/Repair/Secure/Install/Test all use Bench/RepairSeat/RepairPhone. Validate actual seating and preserve one work reservation per selected bench. Do not recreate TestBench/TestSeat/TestPhone or send players to another chair for final testing. Kit pickup grants all missing reusable tools with server identity checks and retry-safe partial grants; replacement parts remain individual carried Tools.
- The current objective's single reusable Highlight must use AlwaysOnTop so required parts and hazard stations remain visible through walls. Keep ordinary prop labels small, white and occluded; do not highlight every prop simultaneously.
- Game UI now uses off-white/neutral accents and muted warnings, superseding the earlier green terminal HUD. Keep functional wire colors and meter target colors. `GClient/Prototype/Dialogue/SubtitleView` consumes current server Dialogue IDs and expiry times for customer, radio, inspector and phone speech. Local typing uses MaxVisibleGraphemes, short paginated lines, speaker labels and reduced-motion immediate text. Hide on menus/hazards/death/results; do not restart on repeated snapshots. Disconnect the active-only render callback on expiry/cleanup and never send per-letter remotes. No recorded dialogue voices are added.

## Interface and performance

- Sync `GShared/Prototype/Repair/PuzzleView` to Shared.Repair and `GClient/Prototype/Interactions/StationInteraction` with the client controller. PuzzleView reuses six controls and only rebuilds their text when work/revision/busy/layout changes. StationInteraction owns the Timeclock close-up and clickable stamp/close controls; restore camera on movement, menus, death, expiry, replacement, reduced motion and teardown. Do not let repair and station views compete for the camera.
- Network retains four scalar fields for ordinary requests; PrototypeAction allows six for RunId, Action, OrderId, WorkId, Move and PuzzleRevision. Keep canonical LServer/Core and mirrored GServer/Core Network synchronized.

- `GShared/Prototype/Repair/PhysicalRepairView` and `PhysicalRepairTasks` are sibling modules used by PuzzleView. BatteryFit/Wires/Assembly/Screen/Debris/Screws/Clean/Probes use local 3D pieces on RepairPhone.Body. Mouse/touch project InputObject.Position through ScreenPointToRay onto the phone plane; previews stay local and completed gestures submit existing work/order/revision-scoped moves. Do not trust client piece positions or add pointer-stream remotes. Retain button fallback, controller/reduced-camera fallback, owner/seat/hazard/menu checks, multi-touch identity, pending guards, active-only render cleanup and transparency restoration. Release physical pieces before starting RepairAssembly; clear old fitting visuals before building a new physical task. Teammates see authoritative progress, not the local drag preview. Custom phone proportions need authored task positions.
- Repair camera markers now sit nearly overhead; use a 45-degree landscape lens and adapt portrait distance/FOV without crossing the roof; respond to viewport changes. RepairPresentation hides only the local character/accessories, caches exact original visibility, handles DescendantAdded, and restores on exit/death/respawn/menu/hazard/teardown. Never change server character transparency or hide teammates.
- Game repair presentation lives in `GClient/Prototype/Repair/RepairPresentation`, a sibling ModuleScript of PrototypeController/PrototypeView. Reuse its single Highlight/progress card; camera focus follows the local player's authoritative SeatVisit and stays between repair steps. The client also verifies its actual Humanoid SeatPart/Sit state. Sitting hides side cards, shows the required component/step, and enables Q/B/touch stand. Standing cancels unfinished work; jump, movement, death, respawn, menus, hazards, and cleanup release the close-up. Preserve original camera CFrame, Focus, FOV, subject/type; disconnect and guard obsolete tween callbacks. Respect ReducedMotionEnabled/ReducedFlashes. No per-frame remotes/scans; the focus/cancellation render callback exists only while a camera close-up/return is active.
- `GServer/Prototype/Customers/CustomerCatalog` contains 270 records (30 original plus 240 composed residents), 12 devices and 12 service profiles. 204 records are ordinary. Jobs vary contacts within the existing two/three-contact template, 3-6 digit sequences, fees and patience (minimum 120 seconds). Story decks only include their chapter's evidence; Endless shuffles after its stable training customer. Never replicate the full catalog or future clues. Hazards precede work/arrivals, pause patience/vote deadlines and leave a recovery gap. Preserve solo play and co-op handoffs.
- `GServer/Prototype/Repair/RepairTemplates` supplies `ReplicatedStorage.DontPickUpTemplates.RepairPhone` only if missing, clones it into the generated shop, and preserves authored templates. Optional named BaseParts Body/Screen/Battery/Speaker/Keypad and Contact1/Contact2/Contact3 support highlights. Its pivot is bottom center. Bench RepairCamera/RepairFocus Attachments define the shot. Missing contact targets fall back to the phone model.
- `GClient/Prototype/Repair/RepairAssembly` animates one local component from the tray, above its slot, then into the exact authored CFrame. Server work timestamps determine remaining motion. Preserve/restore LocalTransparencyModifier, disconnect stale completions before cancelling, and clean up on cancellation, hazards, death, results, reduced motion, and teardown. Tween completion never grants gameplay progress. There are no hand rigs or drag-to-disassemble controls.
- `GServer/Prototype/Anomalies/EventDirector` is server-only. Production nights begin with 90 calm seconds plus 0-15 seconds of jitter; first interruption is harmless. It selects seven weighted event types at decision boundaries, with quiet rolls, no immediate repeats, 85-second per-kind cooldowns, later lethal visitors, five-event and two-planned-scare caps. Do not reveal random seeds, next events, pending scare targets or timestamps before dispatch. The fixed Events list is used only with Director.Enabled=false.
- Minor Knocks/Shadow/DeadAir events pause arrivals/work without damaging players. Existing four hazards retain warnings and counteractions. A pending scare picks one eligible living staff member, cancels when its event ends or the run finishes, and obeys the personal cooldown. All scare routes respect the initial calm period. Later phone puzzles use per-order random seeds; tutorial remains stable.
- `GClient/Prototype/Effects/ScarePresentation` reuses a hooded face, viewport-camera lunge, impact Sound and localized anomaly Sound. It never owns the world camera. Default audio uses installed Roblox content sounds; optional DontPickUpTemplates.ScareSound overrides the impact. MasterVolume scales audio; reduced motion/flashes uses silent text. Deduplicate IDs, wait for the short dispatch timestamp, discard stale cues, stop pooled audio and cancel tweens on cleanup. No strobe or permanent render callback.
- Attack scare cues now queue one server impact at +0.6 seconds (visual cue +0.25), default 25 HP. Interrupt only the victim's work/focus; always use ShiftService.Damage and existing death/settlement. Damage's accompanying scare is marked Applied and must not queue another injury. Clear pending hits before applying, on death/departure/results/new nights; do not wait for client acknowledgement or change damage for menus/reduced motion. Preserve calm gates, shelter protection for visitor cues, personal cooldowns and no new dispatch across dawn. Injury snapshots and death-cause text make the outcome explicit.
- `GServer/Prototype/Anomalies/OutdoorRisk` is a server sibling module. World:Outside uses shop-local bounds and one-stud doorway tolerance, returning nil for missing/live-invalid rigs. Shift samples positions once a second, outside decisions every eight seconds after 12 seconds of grace. Chance rises 12% +0.8 points/exposed second beyond grace, capped at 65%. Seven-second warnings can be escaped indoors; failure commits 35 HP before second 180 or 100 HP after, then a 30-second cooldown. Outside warnings are personal, never damage indoor teammates, and postpone new shared disturbances. Tutorial, calm opening and first director interruption are protected; chances/future rolls stay server-only. Reset exposure for missing characters/spectators/results/replay.
- PrototypeConfig.DebugScares defaults on in Studio only. Print COMING before dispatch and CANCELLED/DISPATCHED for scheduled cues; never print every tick. DebugScaresInLive explicitly enables published diagnostics. These are Output messages, never player-facing countdowns.
- PrototypeWorld skips scene/prompt rebuilding when only puzzle/profile revisions change. Its visual key must cover every state used by the world adapter. RepairAssembly exits before world lookups unless fitting; StationInteraction exits before character/world lookups unless inspecting. Local scheduling checks are not proof of live FPS or lag-free operation.
- Shift revisions represent mutations, not time passing. GamePrototype coalesces changed snapshots on the quarter-second tick with a five-second refresh. Publish on every authoritative transition, including settlement/save status, arrival, cancellation, work completion and notices. Timers derive from server timestamps; retain frozen result time. PrototypeWorld binds by revision, HUD timers update once per second between snapshots, responsive layout updates only on viewport category changes. Validate scheduling separately from live FPS/latency.

- Preserve authored phone interfaces and layout. Confirm exact instance names and casing before binding UI.
- When showing a screen, ensure its ScreenGui and ancestor containers are enabled/visible, not just the target child.
- Use `GuiButton.Activated` for discrete buttons and support mouse, touch, and controller where relevant. Keep phone text and interactive targets readable on small screens.
- Clean up connections, camera overrides, input locks, audio, and effects when interactions end or the player dies/respawns.
- Avoid unnecessary per-frame polling and repeated remote traffic. Prefer events and bounded updates; profile before claiming performance improvements.

## Validation and handoff

- Run `lune run tests/Validate.luau`, `lune run tests/Runtime.luau`, `lune run tests/Concurrency.luau`, `lune run tests/Queues.luau`, and `lune run tests/Prototype.luau`, plus `powershell -NoProfile -ExecutionPolicy Bypass -File tests/SyncCore.ps1 -Check` for Core parity. The harness uses mocked Roblox services, authored/generated hierarchy fixtures, and deterministic concurrency; it does not validate live services or rendered UI. No CI workflow is configured.
- Review changed files for whitespace errors, merge markers, secrets, stale project names, and incorrect environment prefixes. Use `git diff --check` for tracked diffs and inspect new files as well.
- Once gameplay exists, use Studio Script Analysis and inspect both Server and Client Output. Test Lobby startup, Game startup, phone interaction, failure/death, cleanup, and supported inputs as applicable.
- Teleporting, persistence, multiplayer isolation, and published behavior need their corresponding runtime checks when introduced.
- Report concrete changed files, what was verified, and what still needs Studio or published testing. Local source or mock checks are not live verification.
- Keep Git metadata at the repository root; never initialize a nested repository in `src/`. Do not commit, push, attach a remote, or publish without user authorization.

---

## Complete game design (owner-supplied)

The following is the complete supplied design document, preserved verbatim apart from line-ending normalization. It defines the intended game. Consult the implementation and gap notes above before claiming any described feature exists.


## Previous overview

# Don't Pick Up

A Roblox horror game in early development. Players search through customer phones, install government malware as part of their assigned work, and decide whether to spy on private information. Investigating too far can put their life at risk.

The direction is inspired by [Don't Pick Up on Steam](https://store.steampowered.com/app/4878690/). The prototype now includes usable customer-phone menus, government-program installation, optional messages/recordings, private calls, team decisions and night survival in a government-controlled 1980s society. See the [phone gameplay research](docs/PHONE_GAMEPLAY_RESEARCH.md) for the reference and design background. The larger authored campaign remains future work.

## Current source layout and latest changes

**TV viewing:** add lowercase `tv` to the whole television Model. Click to smoothly enter a level viewing shot; Q/B or STOP WATCHING returns to normal play. Camera framing is model-relative and fits the viewport. Sync GClient and GShared; tune GClient/Camera/TelevisionViewConfig for the imported model's front. Existing television content stays authored.

**Charged throws:** add lowercase `throw` to a small prop part/model. Hold mouse, touch, RT or E to grab and charge; release to throw toward your aim. Charge caps after 1.5 seconds. Includes a power meter, short trail and subtle release particles. Server-owned grabs prevent competing holders; Q/B or interruptions cancel. See [throw setup](docs/THROWING.md). Sync all three Game roots.

**Central tagged interactions:** add `Drink` to a drink Model/part, `Fax` to the telephone Model, and `Container` to the drawer-group Model. All use the authored SelectionHighlight. Drinks fade to invisible over 0.5 seconds and are removed for everyone; fax and container camera/keypad behavior is preserved. Names no longer select the interaction. Sync GClient/GServer/GShared together; remove the obsolete GClient/Containers/ContainerInteraction ModuleScript. See [tag setup and source layout](docs/TAGGED_INTERACTIONS.md).

**Telephone close-up and keypad:** click an authored Model tagged `Fax` to smoothly look down at its keypad, using an offset relative to its pivot and size. Key0-Key9, Key*, Key#, KeyClear and KeyClose use the supplied physical parts; digits appear in `InputArea.SurfaceGui.Frame.TextLabel`. Q/B or CLOSE PHONE restores the camera. The active client entrypoint is now **GameController**; remove the previous ContainerController LocalScript after syncing. Calls are not connected yet. See [telephone setup](docs/TELEPHONE.md).

**Active container system / prototype archived:** `GServer/GameConfig.PrototypeEnabled = false`. All prototype gameplay and views live under `GServer/Prototype`, `GClient/Prototype` and `GShared/Prototype` and stay unloaded. Active systems remain outside those folders. First click the whole Model tagged `Container` to move the camera into a view of all containers. Then click individual `Box1`–`Box4` parts to slide them 0.8 studs toward negative world Z; click again to close. Matching Label1/Label2/etc parts move with their respective boxes. Hover uses your `ReplicatedStorage.Assets.SelectionHighlight`. Q/B or CLOSE VIEW returns to normal play. Add the Container tag to the group Model; no custom authoring attributes are needed. Sync **GServer, GClient and GShared** together, remove obsolete copies listed in [SOURCE_CHANGES](docs/SOURCE_CHANGES.md), and restart Play. See [container setup](docs/CONTAINERS.md). The remaining feature notes below describe the preserved prototype.

**Usable phones and five-night Story:** after reassembly, open the customer's phone at the bench. Install **CIVIC WATCH**, browse private messages/recordings, call contacts, or answer/ignore an occasional incoming call. Installation needs an explicit check after copying finishes. Asking to skip the mandatory program opens a team vote; looking closer opens a recovered record on the phone. The fax still handles six-digit pickup tickets. Story now lasts **five nights**; Endless continues. Night two prohibits private records; night three onward also prohibits private calls. The phone log and inspector track violations. Recordings/calls use readable text; no new recorded voices are included.

**Credits and Best Night:** the lobby/player list shows saved Credits and the highest night actually survived. Earn 10 Credits per contributed completed repair and 50 for surviving a night, paid once when its outcome is recorded. Lifetime repairs/survival totals remain saved. Schema 2 migrates existing profiles without resetting progress; the existing DataStore namespace stays unchanged. Sync both server roots for this profile change.

**Four wire pairs:** match four numbered, colored wire inputs to four outputs using 3D dragging or the button/controller fallback. An optional BasePart/MeshPart named `ReplicatedStorage.DontPickUpTemplates.RepairWire` supplies your cable artwork: orient its length along local Z; X/Y set its thickness. It is cloned locally, tinted to the connection color and stretched between endpoints. Existing prototype cables remain the fallback.

**Customer pickup:** every drop-off gets a unique six-digit ticket. Customers leave while staff repair their phones. After the final test, use the **FAX PHONE** on the counter, enter the ticket shown in its job list, and press **CALL CUSTOMER**. The customer returns after a short walk; hand the phone back at the counter to finish the order and receive payment. Both benches share the fax. Sync new `GServer/Prototype/Customers/PickupService` and `GShared/Prototype/UI/FaxView` with all three Game roots. The disconnected horror phone remains separate.

**The phones know the team:** later-night CIVIC WATCH records can contain clearly fictional employee reviews built only from actions performed in the current run. The shared employee board shows each staff member's current Ministry status, the results screen gives up to four funny performance awards, and SHIFT INFO tracks run-local customer/anomaly/stamp handbook totals. The compact TEAM menu sends six rate-limited authored callouts without reading player chat. These systems are server-owned by `GServer/Prototype/Services/EngagementService` and never inspect external Roblox account activity.

**Shared is now required.** Sync `src/LShared` to **ReplicatedStorage.LShared in Lobby**, and `src/GShared` to **ReplicatedStorage.GShared in Game**. Twelve reusable UI, puzzle-view, request and geometry modules moved there; public repair definitions are shared by server and client. Sync Client, Server and Shared together in each place, and remove the old moved ModuleScripts listed in [SOURCE_CHANGES](docs/SOURCE_CHANGES.md). Server rules, saves and unrevealed story content remain private.

Repair instructions now use plain language: parts are **WORKING** or **BROKEN**, and number-copy tasks show **NEXT**. Training and the first night use easy matching and short visible codes; later nights mix easy jobs with occasional harder puzzles. Sync all three Game roots for these task and UI changes.

Game play is first person with a small, faint white dot and a centered mouse. Press **V** to unlock/relock manually; the small mouse button can relock it too. Repairs, timeclock use, notes and menus unlock automatically. Sync the complete `GClient` root. Native touch/controller input remains supported.

The latest direction is a simple, sometimes funny night job with optional deeper lore. Short authored conversations, a personal document reader, direct small-object interaction and two independent repair benches build on the existing prototype.

**The source has moved into subfolders. Sync complete roots, not old flat sibling lists.** See [current architecture, controls and deployment](docs/CURRENT_ARCHITECTURE.md), [design review](docs/DESIGN_REVIEW.md), and the [complete file move/change manifest](docs/SOURCE_CHANGES.md). These instructions supersede older flat-module setup examples below.

## Current status

The server foundation implements 1-4 player Lobby parties, reserved Game-server teleports, destination admission, party arrival checks, and persistent player profiles. The generated shop has two playable modes: **Story** follows five nights of linked evidence to an ending; **Endless** continues across increasingly demanding nights until the team dies or leaves. Each night lasts six minutes after briefing; only the first night includes training.

**To play the saved prototype:** set `GServer/GameConfig.PrototypeEnabled = true`, sync `GServer` into the Game place's ServerScriptService, `GClient` into StarterPlayerScripts, and `GShared` into ReplicatedStorage.GShared, then restart Play. The shop and HUD generate only with that flag enabled. See [Game prototype setup and controls](docs/GAME_PROTOTYPE.md).

The prototype HUD uses black panels at 0.5 background transparency. **SHIFT INFO** opens repair-ticket, team and directive details on demand. Close-up controls replace the regular HUD; placeholder labels are small white text with scale sizing and a 22-stud visibility limit.

The shop has a compact **main shop and back stockroom**. Two independent benches each handle every phone task, including final testing; one repair-kit pickup supplies all three reusable tools. Replacement bins share one shelf, and current objectives highlight through walls. HUD accents are off-white and muted amber; customer/radio dialogue has typed speaker-labelled subtitles with short pages and reduced-motion support. Sync new **GServer/Prototype/World/ShopLayout** and **GClient/Prototype/Dialogue/SubtitleView** with all three Game roots. Room props are temporary labelled geometry for the builder to replace.

Repair close-ups now look down over the phone and hide your own avatar locally. Eight task types use **3D parts on the bench**: probe pads, battery cells, wire ends, ordered assembly, screen replacement, loose debris, screws and cleaning. Drag with mouse/touch; turn screws sideways and rub dirt patches. **USE BUTTONS** keeps the original controls available, with automatic controller/reduced-motion fallback. Sync new **GShared/Prototype/Repair/PhysicalRepairView** and **GShared/Prototype/Repair/PhysicalRepairTasks** alongside all other Game modules. These are temporary local task pieces; other players see the existing shared repair progress.

Players spawn outside and inspect the timeclock: the camera zooms in and a button stamps their arrival. Repairs require collecting one kit containing the tester, screwdriver and software cartridge, then fetching each replacement part as needed. Task controls guide diagnosis, fitting, circuit repair, installation and final testing. Solved parts tween into place; waiting alone never solves a puzzle. Restocking uses a crate-sorting task.

Repair work now includes **four screws, screen replacement, cleaning, SIM orientation, fuse matching, button/light/sound patterns, phone-number entry, part sorting, circuits, wave alignment, power balancing, broken-component removal, charger matching, ordered reassembly, debris removal and PASS/FAIL forms**, alongside battery dragging and colored wires. Each job uses a short selection of tasks. Small pickups and objects use direct click/tap/controller interaction; larger bench/counter/fuse prompts retain hold durations. Sync **all GServer, GClient and GShared**, including the new **GServer/Prototype/Repair/BenchTasks** and **GShared/Prototype/Repair/BenchTaskView** modules.

Explore thirteen optional records through a personal document reader, including the original timecard, tape and key-locked archive. Story preserves decisions, suspicion and discoveries between nights and resolves one of eight endings. Surviving staff ready up together to continue; dead players remain spectators until a new run. Each earned night records progress separately. Shared runs currently stay in their server and cannot be resumed after everyone leaves.

The server-only customer catalog now contains **270 records**, including 240 composed resident identities, **12 device models**, and **12 service profiles**. Contact counts, verification sequences, fees and patience vary; roughly 76% of records are ordinary customers. Each player receives only current job information and their own puzzle controls.

Attack jumpscares now have real consequences: ordinary signal/visitor scares take **25 HP** after the face appears, interrupt the victim's repair, and show damage feedback. Fatal hits enter the existing death/spectator/ending flow. Staying outside adds personal risk after a 12-second grace period; the chance increases every eight seconds. Footsteps give **seven seconds to get inside**. Ignoring them causes 35 damage early in the night or a fatal 100-damage attack after three minutes. Returning inside cancels the warning. Tutorial, calm opening and the first harmless interruption remain protected. Sync **GServer/Prototype/Anomalies/OutdoorRisk** with the updated server and client files.

Nights now start with **90 calm seconds**, followed by a harmless first interruption. A server-only director randomizes seven event types, timing, quiet gaps, and occasional personal scares. It avoids immediate repeats and limits planned scares. The face lunges with varied framing and a built-in impact sound; an optional `DontPickUpTemplates.ScareSound` overrides it. Reduced motion keeps a silent text cue.

Sync **all of GServer, GClient and GShared**, including the new `EventDirector`. Studio Output prints `[DPU][Scare] COMING ...` before a hit; diagnostics default off in published servers. Puzzle inputs now reuse unchanged world bindings, and idle effects skip scene lookups. Studio rendering, frame rate, and multiplayer latency still need profiling. See [pacing and scare configuration](docs/GAME_PROTOTYPE.md#randomized-night-and-scare-debugging).

Read [Lobby queue setup](docs/LOBBY_QUEUES.md) for the exact hierarchy and Studio print preview. Admission carries versioned mode, starting-night and party-size data; the destination trusts the server ticket and loads saved profiles separately. Sync **LServer, GServer and GClient**, including `ModeRules`. Set `Core.Config.StudioGameMode` to `Story` or `Endless` in both Core copies to preview their introductions and progression in Studio.

Queue entry now handles `Refs.Enter` contact immediately on the server, with bounds polling as a fallback. Sync the updated `LServer/World/LobbyWorldService` module for this change. Entry/exit uses stable standing slots, one departure deadline, visit-scoped requests, and visible status/error feedback. Sync the Lobby controller, LShared modules and updated Lobby server together. World signs update directly without animations and preserve authored label sizes and text-sizing settings. An optional authored `Queue.Status` label controls notification placement; a small fallback label is supplied when absent.

The world sign binds `Icon.Bar.Gamemode`, `Icon`, `Status`, `PlayerCount`, and `Title`. Sync **LServer/World/QueueBillboard** and **LClient/QueueController** for this hierarchy. Older sign names remain supported. It shows `SHIFT AVAILABLE / READY` when empty, then the host's shift, live countdown, preparation, and teleport status with green/amber status text only. Background and title border colors stay authored.

Local tests exercise storage failures, session ownership, party permissions, partial teleports, and concurrent load/save cleanup. Studio hierarchy, published teleports, and live persistence have not been verified. Read [the server integration guide](docs/SERVER_SYSTEMS.md) before syncing.

## Lobby and Game naming

The prefix identifies which part of the experience owns a source container:

| Prefix | Meaning | Source naming convention |
| --- | --- | --- |
| `L` | Lobby | `LClient`, `LServer`, `LShared` |
| `G` | Game | `GClient`, `GServer`, `GShared` |

These are the source folder names under `src/`, not verified live Roblox instance paths. Preserve their exact casing. Lobby and Game are separate places; each server bootstrap resolves modules relative to its own parent and requires that parent to be inside `ServerScriptService`.

| Environment | Configured place ID |
| --- | --- |
| Lobby | `110554757455252` |
| Game | `111652489432168` |

The IDs were supplied by the owner. Both places must belong to the same Roblox experience so group teleports and player data work across them; this relationship still needs dashboard verification.

- Client code owns presentation, input, camera, and local effects.
- Server code owns authoritative gameplay, validation, outcomes, and saved data.
- Shared code is visible to clients. Keep hidden story information, unrevealed phone content, and secret outcome rules on the server until needed by an authorized player.
- Lobby shared code and Game shared code belong to their respective environments; do not assume one can directly require the other.

## Repository layout

```text
DontPickUp/
  .git/             Local Git metadata
  .gitattributes    Text line endings and binary asset handling
  .gitignore        Source-focused tracking and local file exclusions
  AGENTS.md         Project instructions for coding agents
  README.md         Project overview and setup
  docs/             Integration, remote contract, persistence, and live test checklist
  tests/            Local regression tests and server Core synchronization helper
  src/
    LClient/        Lobby client source
    LServer/        Lobby server source
    LShared/        Lobby shared source
    GClient/        Game client source
    GServer/        Game server source
    GShared/        Game shared source
```

Keep repository configuration and project documentation outside `src/`. Detailed documentation belongs in `docs/`, and local tests belong in `tests/`. Public UI and repair presentation live in the corresponding Shared root; private gameplay and profile rules stay server-side.

## Development workflow

Follow the Roblox Script Sync workflow used by the sibling projects. No Rojo project, dependency manager, or generated place configuration is configured.

1. Read [AGENTS.md](AGENTS.md) and inspect the current source before changes.
2. Sync `LServer` inside the Lobby's `ServerScriptService`, and `GServer` inside the Game's `ServerScriptService`. Each contains one executable `Bootstrap.server.luau` Script; every other Luau file is a ModuleScript. Preserve the `Core` subtree.
3. Keep Lobby and Game source separate and sync each to its correct environment.
   Sync `LClient` under the Lobby's `StarterPlayer.StarterPlayerScripts`; `QueueController.local.luau` is a LocalScript, with `LClient/Interface/QueueView.luau` and `LClient/Matchmaking/QueueRequests.luau` ModuleScripts in `ReplicatedStorage.LShared`.
   Sync `GClient` under Game `StarterPlayer.StarterPlayerScripts`; `GameController.local.luau` is the active root LocalScript, and `Prototype/PrototypeController.local.luau` is the archived LocalScript. Preserve both folder trees. Sync `GShared` to `ReplicatedStorage.GShared`; active Containers and archived Prototype modules stay separate.
4. Preserve authored UI, models, audio, lighting, and other place assets. Keep separate private Studio place backups; this Git repository is not a complete place backup.
5. Run the local checks below. Use Studio Script Analysis and inspect Server and Client Output after syncing.

## Local checks

Using an existing Lune installation, run from the repository root:

```powershell
lune run tests/Validate.luau
lune run tests/Runtime.luau
lune run tests/Concurrency.luau
lune run tests/Queues.luau
lune run tests/Prototype.luau
lune run tests/Improvements.luau
lune run tests/Pickup.luau
lune run tests/PhoneGameplay.luau
lune run tests/Engagement.luau
lune run tests/Containers.luau
lune run tests/TaggedInteractions.luau
lune run tests/Throwing.luau
lune run tests/Television.luau
lune run tests/Telephone.luau
lune run tests/Engagement.luau
powershell -NoProfile -ExecutionPolicy Bypass -File tests/SyncCore.ps1 -Check
git diff --check
```

`LServer/Core` is the maintained source of the common **server-only** modules. After editing it, run `tests/SyncCore.ps1` without `-Check` to update the identical `GServer/Core` deployment copy. Both places use the same schema, storage namespace, admission format, and configuration; neither requires instances from the other place.

Source checks cannot establish Studio behavior, published teleport flow, persistence, device usability, or multiplayer performance. Record which environment was actually tested.

## GitHub setup

The repository uses `main`. Check `git remote -v` and `git status` for its current GitHub connection and working-tree state before committing or pushing.

The ignore rules allow the root documentation, `.github/`, `docs/`, `tests/`, and `src/`. Add an explicit root allowance when introducing another intentional repository file or directory. Credentials, logs, local editor settings, generated output, and Studio place backups are excluded.

Never commit API keys, Roblox cookies, webhook URLs, or other credentials. Keep private configuration outside tracked source.


## Source migration notes before system organization

These notes are historical; current deployment is documented in SOURCE_CHANGES.md.

# Source move manifest

HUD migration adds ModuleScripts `GClient/Interface/ShiftPanelController`, `GClient/Interface/Mugshot` and `GServer/Session/ShiftStats`. Sync the updated PrototypeController, PrototypeView, ShiftService, ShiftActions and ShiftSnapshot too. Keep both HUD screens: intro/votes/successful results and repair views still use DPU_PrototypeHUD. No entrypoint, root, profile schema or authored asset deletion. See [HUD_PANELS](HUD_PANELS.md).

Settings adds `SettingsController`, `SettingsView` and `SettingsAudio` ModuleScripts under both `LClient/Settings` (canonical) and `GClient/Settings` (deployment copies). No new entrypoints. Existing client entrypoints and scare motion were updated. Sync the schema-3 Core copies to Game and Lobby together; no authored frame rebuild is needed. See [SETTINGS](SETTINGS.md).

Latest gameplay integration adds four flat server ModuleScripts: `GServer/Story/GovernmentService`, `CustomerStories`, `DeviceRecords`, `RepairRoutine`. Sync all Game roots together; existing shift/client modules were updated in place. No entrypoint or root rename, no authored asset deletion and no persistence schema change. The active Prototype remains enabled. See [SHOP_DIRECTION](SHOP_DIRECTION.md) and [WORKSPACE_CLEANUP](WORKSPACE_CLEANUP.md).

**Latest owner request: prototype restored and enabled.** The Prototype retirement/removal directions below describe earlier changes and are superseded by [PROTOTYPE_RESTORATION](PROTOTYPE_RESTORATION.md). Keep the restored flat Prototype ModuleScript folders and the single Startup entrypoint in each root.

## Actual system layout (current)

Sync each place's Client/Server/Shared roots together according to [README](../README.md). System folders contain only scripts/modules. This table uses paths relative to `src/`; retain the suffix conventions when Script Sync creates instances. Replace old script instances rather than keeping compatibility copies. Do not remove authored world models, Assets, UI, lighting, audio or saved data.

| Old file | Current file |
| --- | --- |
| `GClient/GameController.local.luau` | `GClient/Startup/GameController.luau` |
| `GClient/Interactions/FirstPersonCamera.luau` | `GClient/Camera/CameraController.luau` |
| `GClient/Interactions/ModelInspection.luau` | `GClient/Camera/InspectionCamera.luau` |
| `GClient/Interactions/TaggedInteraction.luau` | `GClient/Interaction/InteractionController.luau` |
| `GClient/Interactions/ThrowInteraction.luau` | `GClient/Interaction/CarryController.luau` |
| `GClient/Telephone/TelephoneInteraction.luau` | `GClient/Effects/PhysicalTelephoneController.luau` |
| `GShared/Interactions/InspectionFrame.luau` | `GClient/Camera/InspectionFrame.luau` |
| `GShared/Interactions/TVConfig.luau` | `GClient/Camera/TelevisionViewConfig.luau` |
| `GShared/Telephone/TelephoneConfig.luau` | `GClient/Effects/TelephoneConfig.luau` |
| `GServer/Bootstrap.server.luau` | `GServer/Startup/Bootstrap.server.luau` |
| `GServer/Runtime.luau` | Removed |
| `GServer/Services/GameSession.luau` | Removed |
| `LServer/Bootstrap.server.luau` | `LServer/Startup/Bootstrap.server.luau` |
| `LServer/Runtime.luau` | `LServer/Startup/Runtime.luau` |
| `LClient/QueueController.local.luau` | `LClient/Matchmaking/QueueController.luau` |
| `LShared/UI/QueueView.luau` | `LClient/Interface/QueueView.luau` |
| `LShared/Networking/QueueRequests.luau` | `LClient/Matchmaking/QueueRequests.luau` |
| `LShared/UI/QueueBillboard.luau` | `LServer/World/QueueBillboard.luau` |
| `LShared/Geometry/QueueGeometry.luau` | `LServer/World/QueueGeometry.luau` |

Additional modules: `GClient/Camera/ContainerViewConfig`, `GClient/Interaction/SelectionHighlight`, `GShared/Interaction/InteractionQuery`, and `LShared/Matchmaking/QueueDefinitions`.

Delete the obsolete `GServer/GameConfig` ModuleScript and any older `GClient/ContainerController` LocalScript or `GClient/Containers/ContainerInteraction` copy. The removed Prototype folders must not remain deployed with executable scripts; active startup no longer supports them. No replacement generated world is provided. Camera fields moved from Shared ContainerConfig to Client ContainerViewConfig; only server/client drawer rules remain shared.

Client entrypoints are now `GClient/Startup/GameController` and `LClient/Queues/QueueController`; server entrypoints are `GServer/Startup/Bootstrap` and `LServer/Startup/Bootstrap`. Each bootstrap resolves its environment root two parents up. Only Lobby retains a Startup/Runtime registry. Game session gating was removed.

Lobby QueueView and QueueRequests now run from LClient/Queues. QueueBillboard and QueueGeometry now run from LServer/Queues. LShared contains public QueueDefinitions, genuinely consumed on both sides. Camera framing, TV/phone view config and input remain client-only.

`tests/SourceMoves.json` is the machine-readable file manifest. Old generated-game suites/fixtures were removed; active first-person tests were extracted. No active source or static import depends on the removed generated-game files.

See [IMPLEMENTATION_HISTORY](IMPLEMENTATION_HISTORY.md) for prior checkout notes; they are not current sync instructions.

## Fax/carry and simplified Game follow-up

Keep the Lobby runtime. Remove only these unused Game ModuleScripts on sync: `GServer/Session/GameSession`, `GServer/Core/AdmissionRules`, `GServer/Core/TicketStore`, `GServer/Core/TravelService`, `GServer/Startup/Runtime`. Game now loads/saves each profile directly without party arrival gating or a ReturnLobby endpoint. Lobby parties/queues/outbound teleports remain.

Rename `Core/SessionStore` to `Core/ProfileStore` in **both** server roots and remove the old ModuleScripts. This is a name change to the same save-lock/lease algorithm, not removal of save protection. `SyncCore.ps1` now copies/checks the seven required Game persistence/network modules only. Saved data/schema/store names are unchanged.

Add Game client Telephone/TelephoneCalls and Telephone/ReceiverMotion. Update TelephoneController/Config, Startup/GameController and the central/throw controllers. Game bootstrap creates the new token-validated ThrowAim event; sync server, client and shared roots together. Throwing is now click-to-carry/click-again-to-throw, with fixed server speed and a small white trail.

The non-runnable `tests/Legacy` archive was deleted. Active persistence, Lobby, interaction and camera suites remain, plus ReceiverMotion tests. The move manifest contains only current destinations.

## Authored Phone repair

Add the PhoneRepair system folders in GClient, GServer and GShared (six ModuleScripts total). Sync the updated Game startup, InteractionController, InteractionService, InteractionTags and InspectionCamera. Tag the authored whole Phone Model `PhoneRepair`; retain its asset folders. The new `RepairDrag` event is created by Game bootstrap. No old source files are removed for this addition. See [PHONE_REPAIR](PHONE_REPAIR.md).

## Authored dialogue presentation

Add the four client-only Dialogue modules and update GClient/Startup/GameController. Keep HUD.Subtitles and ReplicatedStorage.Assets.NPC authored in the Game place. No scripts/assets are removed. The demo begins after ten seconds while DialogueConfig.TestEnabled is true. See [DIALOGUE](DIALOGUE.md).

Phone repair now uses a dedicated overhead wire close-up fitted to all eight installed endpoints with viewport-aware margins and 38-degree FOV. After the fourth wire, it eases back to the wider assembly view (45-degree FOV). Repair camera transitions take 0.55 seconds; reduced motion still skips them. `GClient/Repair/RepairViewConfig` owns this framing. Lift, flip, layout and final return interpolate a common body transform to preserve the phone assembly; quintic easing softens part motion and installation. Verify actual endpoint scale, portrait/landscape framing, imported mesh clearance and replication in Studio.

Dialogue portraits now fit the full body with animation margins and prefer exact `ReplicatedStorage.Assets.NPC` (lowercase npc remains a fallback). AnimationController/skinned NPC models do not require a Head. Only the cloned rig root is anchored; source models remain untouched. `DialogueConfig.NPCAnimations` contains only Running, Angry, Nervous, HeadNodAgree, AngryIdle and HappyIdle. Lines optionally select `Animation = "HappyIdle"`, `"HeadNodAgree"`, `"Nervous"`, `"Running"`, etc.; the test uses HappyIdle and HeadNodAgree. You always uses the stock R6/R15 Roblox idle. Tracks stop and are destroyed on speaker changes/close. Verify asset permissions, matching rig/bones, animated framing and actual playback in Studio; local mocks cannot render animation assets.

Added client-only `GClient/Interaction/CarryView` for smooth local carried-prop prediction using the existing post-camera update. Server reservations, bounded aim updates and throw physics remain authoritative. ThrowEffects no longer spawns debris or installs impact listeners; the white trail remains. Sync CarryView alongside ThrowController and GameController.

CarryView now smooths camera-local offsets and retains its owner-only visual through a short release handoff. Sync the updated CarryView, ThrowController, GShared/Interaction/ThrowConfig and GServer/Interaction/ThrowService together; the latter two share the existing launch angular velocity. Server-owned physics, speed, aim limits and authority are unchanged.

## Customers, orders and temporary bench

Add `GClient/Orders/{OrderController,OrderView}`, `GServer/Orders/{OrderCatalog,OrderService,OrderStation,OrderTestBench}` and `GServer/Customers/CustomerActor` as ModuleScripts. No existing files moved for this feature. Sync the updated Game entrypoints, InteractionController, InteractionTags, PhoneRepairService and DialogueConfig with them. `Customer` is a new whole-model interaction tag. Game startup creates `OrderChanged` and routes `GetOrderState` / `ServeCustomer`. Both Core/DataService copies gain the server-only, idempotent order payment method; preserve canonical Lobby/Game parity.

The isolated Studio bench is explicitly requested temporary test content, not a restoration of the retired generated-game framework. Existing authored assets remain intact. No move-manifest entries or project mappings change. [CUSTOMER_ORDERS](CUSTOMER_ORDERS.md) documents placement and the authored production station contract.

## Full prototype restoration (enabled)

Recovered all 47 prototype gameplay/presentation modules from GitHub commit `b5cca9466adec1c08d2afabd77ffe1cb85be6a31` (see the exact commit in `tests/PrototypeRestoration.json`). They now live directly under each Game root's Prototype folder. Client-only legacy Shared views and Requests moved into GClient/Prototype; only public repair Definitions remains in GShared/Prototype.

`GClient/Session/SessionController` is now a ModuleScript called by the one existing `Startup/GameController` LocalScript. Do not restore a second root PrototypeController LocalScript or a second root Bootstrap Script. `GServer/Session/SessionService` connects current Core profiles/network to the recovered GameSession/GamePrototype. Three canonical Lobby admission/travel modules are copied into Prototype and checked by SyncCore. `PrototypeConfig.Enabled = true` is the default. Both entrypoints branch before creating authored-mode controllers/services.

`ShiftClosing` adds the 60-second finish-current-orders window before results. Original prototype suites and fixtures are active again. SourceMoves includes their old runtime locations; PrototypeRestoration records exact historical paths, including the separate legacy FirstPersonCamera copy without replacing the authored camera. See the restoration guide before syncing.

## Saved prototype map and UI

The prototype remains enabled but now binds the cloned Studio assets. Add `GShared/World/SceneReferences` and `GClient/Interface/AuthoredUI`. Sync the updated Prototype modules, Game entrypoints, DialoguePortrait and both canonical Core/Network copies. No script moves or entrypoints were added. Fixed map, seats, phone template, HUD and cursor builders were removed. Do not delete the saved map/UI; old PrototypeOwned attributes no longer authorize their deletion.

Use `Workspace.Prototype.DPU_Prototype`, sibling DPU_InteractFocus/DPU_RepairFocus Highlights, `ReplicatedStorage.Assets.Devices.Phone`, `Remotes.Request/StateChanged`, and the saved StarterGui DPU screens plus HUD.Subtitles. Optional RepairWire/ScareSound assets also moved to Assets. The authored subtitle Camera is reused without changing its pose/FOV. [Asset contract and checks](PROTOTYPE_ASSETS.md).

## Authored clock, customer models and physical pickup telephone

Remove deployed `GClient/Prototype/FaxView` and sync its replacement `PickupTelephone`. Add `GShared/Customers/CustomerTemplates`; update CustomerActor, PrototypeWorld/GamePrototype, order/dialogue snapshots and DialoguePortrait/View. Customer models now come from `ReplicatedStorage.Assets.NPC` children, including duplicate-name models, with one server-selected appearance per order. Generated customer body/label code was removed.

PrototypeView binds `Clock.Night/Time` instead of ShiftHeader. PrototypeController/WorldInteraction reuse the existing TelephoneController, ReceiverMotion and InspectionCamera for the authored `Workspace.Prototype.DPU_Prototype.Fax`; server PickupService confirms calls before the receiver lifts. No replacement screen keypad is required. Sync GClient, GServer and GShared together. Keep saved map/UI/phone assets; [current hierarchy and controls](PROTOTYPE_ASSETS.md).

## Subtitle hierarchy correction

Update `GClient/Prototype/{PrototypeController,SubtitleView}` and `GClient/Dialogue/{DialogueView,DialogueController,DialoguePortrait}` together. Prototype subtitles now prefer `DPU_PrototypeHUD.DialogueSubtitles.Frame` with the authored Title, Paragraph and CharacterViewPort.ViewportFrame. Older HUD.Subtitles remains a fallback; startup no longer requires an extra HUD ScreenGui. Subtitle teardown no longer claims/releases the entire prototype HUD. Existing cameras are preserved; an absent camera uses the configured portrait camera. No Studio objects need renaming or moving.

## Scare viewport camera correction

Update `GClient/Effects/HorrorController`. `DPU_PrototypeHUD.Scare.Visitor` no longer requires a saved child named Camera: it reuses an existing viewport camera or creates one owned runtime camera. Missing cameras therefore do not abort startup. Existing scare UI/geometry remains authored; borrowed camera state is restored and only owned cameras are destroyed. No asset renaming is required.

## Named customers and gender animation sets

Add `GShared/Customers/CustomerAnimations` and sync the updated CustomerTemplates, CustomerActor, PrototypeWorld, Dialogue modules, SubtitleView, DialogueService and authored OrderStation/OrderService. New arrivals choose uniformly across the valid Models in `Assets.Characters.Female` and `.Male`; legacy `Assets.NPC` is a fallback only when both folders have no valid models. Server-assigned customer names now reach portraits instead of being replaced with Customer. No source moves or Studio deletions are required. See [CUSTOMER_ANIMATIONS](CUSTOMER_ANIMATIONS.md).

## Authored Storage and optional notes

Add `GServer/Interaction/DrawerContents` and `GServer/World/StorageService`. Sync updated ContainerService, PrototypeWorld/GamePrototype, GShared SceneReferences and client WorldInteraction/Requests/RepairPresentation/PrototypeView together. Stock now binds Storage.Part_BatteryBox1, Part_KeypadBox2 and Part_SpeakerBox3. Secret_* and Tool_BrassKey are optional. No source moves or generated map/UI. [Setup and checks](PROTOTYPE_ASSETS.md#storage-drawers-and-removed-notes).

## CRT television model

Add client `GClient/Effects/TelevisionController`; sync updated PrototypeController/WorldInteraction, GServer PrototypeWorld and GShared SceneReferences. The active TV now binds `DPU_Prototype.CRT.CRTScreen` and uses existing inspection camera entry/return tweens through central input. No new entrypoint, remote or authored GUI is needed. Keep the CRT Model and nested screen; an obsolete separate root-level CRTScreen is no longer used.

## Waiting chair cleanup

WaitingChair has no active source functions or gameplay dependencies. Removed the leftover chair/sign from the offline authored-map fixture, including updating instance references. The Studio `DPU_Prototype.WaitingChair` prop may be deleted; retain RepairSeat and Bench2Seat. No runtime module or import changes are needed.

## Unified physical Fax telephone

Sync GShared SceneReferences, GServer PrototypeWorld/ShopLayout, and GClient PickupTelephone/RepairPresentation together. The active telephone now binds Workspace.Prototype.DPU_Prototype.Fax. Logical Phone and Answer event stations share that model; the Phone handset offers the existing confirmation while ringing, and the body silences it. Both actions retain server event, admission, range and wall validation. No new entrypoints/remotes or persistence changes. After syncing, the standalone DeskPhoneBase, Receiver and Phone props can be deleted; retain Fax.Phone. Customer calls, keypad and entry/return camera tweens remain on the existing controller.

## Authored customer Phone

Add `GServer/Repair/DevicePresentation` and `GClient/Repair/DeviceTaskView` ModuleScripts. Sync all Game roots: prototype scene/repair, stock carry, task presentation and public step labels changed together. `RepairTemplates` now resolves Assets.Devices.Phone; the old Assets.RepairPhonePrototype is no longer a runtime dependency. Keep the four existing bench/counter phone placement anchors and all Storage pickups. No new remote, entrypoint, profile schema or Lobby change.
