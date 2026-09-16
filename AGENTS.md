# Don't Pick Up repository instructions

These instructions apply to the entire repository.

- Use short, concrete repair instructions for younger players. Diagnosis shows WORKING/BROKEN after each check; never require voltage, resistance or signal jargon. Training and night one use simple matching plus three-number visible copy tasks; later orders keep those easy tasks for two of every three seed classes. Harder tasks remain occasional. `WorkPuzzles.IsEasy` owns this selection; retries keep the order seed. Keep server validation, all three diagnosis checks, assembly and four screws. Number-copy UI shows COPY/NEXT, and phase-based tasks explain only the current step.

- Game uses `GClient/Interactions/FirstPersonCamera`: first person with a four-pixel white dot at 0.45 transparency and centered mouse during ordinary keyboard/mouse play. V and the small mouse button toggle manual release. Automatically release for local repair seating/work, timeclock, notes, game modals, results/death, Roblox menus, text input and lost window focus. The free dot follows screen coordinates; Roblox menus/text input use the native cursor. WorldInteraction uses a viewport-center ray while locked. One small post-camera cursor binding enforces policy without camera transforms, scene scans or remotes. Preserve native touch/controller and repair/timeclock camera ownership; remove bindings/UI and restore input on teardown. This supersedes always-free/right-click-look behavior. Lobby remains unchanged.

## Latest owner direction and architecture (2026-09-15)

- The latest request favors a simple, funny, readable night job. Keep deeper government/conspiracy lore optional; use short authored customer/player/coworker exchanges, never player chat. This supersedes a uniformly serious presentation.
- Read `docs/CURRENT_ARCHITECTURE.md` and `docs/SOURCE_CHANGES.md`. Modules are now grouped under responsibility folders within the exact existing L/G roots. Root bootstraps/controllers stay executable; all moved files remain ModuleScripts. Legacy descriptions of flat sibling modules below are superseded by this deployment map.
- Two independent repair benches supersede the previous single-bench restriction. `RepairStations` owns per-bench order/work state; `RepairFlow` receives explicit station records. Shared hazards pause both; personal injuries cancel only the victim. Never swap global order/work fields as a temporary context. Cross-bench votes use `Vote.OrderId`.
- Keep the first repair and night short: added puzzle stages begin on later nights. Preserve the existing task catalog and button/controller fallbacks.
- `LoreService` validates personal, expiring inspection and discloses only the inspected record. Thirteen optional records keep existing evidence IDs and the original three-record ending condition. Readable descriptions/transcripts are placeholders for future authored artwork/audio.
- `WorldInteraction` uses direct mouse/touch/RT input for small objects, an aimed highlight and a short label. Large door/bench/counter/fuse interactions retain prompts. No per-frame remotes. `Networking/Requests` serializes calls and keeps deferred close intents scoped to their original run/visit; restock puzzle input has no OrderId.
- Keep server customer, dialogue and lore catalogs private. Shared roots remain intentionally empty. Preserve canonical LServer/Core and identical GServer/Core; do not add compatibility copies of moved modules.
- Run `tests/Improvements.luau` in addition to the five existing suites. Source/mocked tests do not establish actual Studio/device usability or published persistence/teleports.

## Start here

- Read `README.md`, inspect the current file tree, and check Git status before editing.
- Read the complete owner-supplied game context at the end of this file before designing or changing gameplay, narrative, presentation, or progression. It is the design source of truth; the implementation notes above it describe what currently exists, not the finished game.
- This Roblox horror project has parties, private teleports, profiles, authored Lobby queues, and a generated Game-place prototype. Read `docs/SERVER_SYSTEMS.md`, `docs/LOBBY_QUEUES.md`, and `docs/GAME_PROTOTYPE.md` for runtime contracts and validation limits. The prototype now supports a three-night Story arc and continuing Endless nights; the larger authored campaign remains future work.
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
- **Mode rules:** `ModeRules` defines a three-night Story arc with chapter-specific evidence and an ending at final survival or personal death. Endless continues until no staff survive or everyone leaves. No Story ending unlocks in Endless. Difficulty growth is capped, with the calm opening and scare limits preserved. `StudioGameMode` selects the direct-Studio preview mode.
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
- Each server environment has exactly one executable `Bootstrap.server.luau`. Other server source files are ModuleScripts. Do not run both bootstraps in one place. The server creates `ReplicatedStorage.DontPickUpLobbyNet` or `DontPickUpGameNet`; no shared-folder mapping is needed for this foundation.
- `LClient/QueueController.local.luau` is the Lobby LocalScript, deployed under `StarterPlayerScripts`, with sibling `QueueView.luau`. Bind `PlayerGui.Queue.Party` and `Queue.Leave`; preserve all authored sizes/positions. Mode buttons are `Party.ScrollingFrame.Story` and `.Endless`. Show the selected button's `Selected` frame and use UIStroke RGB `(4, 255, 0)`; hide the other marker and use `(58, 58, 58)`. Reuse an authored Selected marker for Story if it is missing.
- `src/LServer/Core` is canonical for common server code. Run `tests/SyncCore.ps1` to refresh the identical `src/GServer/Core` copy, and run the parity check. Do not move persistence or admission modules into replicated shared folders.

## Existing server foundation

- Staff spawn outside. OpenClock opens a per-player, 30-second Timeclock inspection; ClockIn requires its current FocusId and being inside within five studs. Movement/expiry closes inspection. ClockIn precedes ReadRules and is idempotent. Door/radio/lamp/log remain distance-checked activities. Restocking sorts a manifest and selects the lowest supply when there is no order. Replay resets entry and physical kit.
- `GServer/Repair/WorkPuzzles` owns diagnosis, polarity, wire matching, keypad, software-code, final-test and crate-sorting inputs. Work never completes by waiting on a puzzle timer: 120 seconds cancels it. PuzzleInput requires current RunId/WorkId/OrderId/revision, work ownership, distance, seat, actual tool, and valid phase. Only the operator receives puzzle controls. Solved Repair alone starts a 1.2-second fitting animation, then Secure. World pickup prompts use hold durations; collection reserves stock on successful activation. Secure is a puzzle chain, never a Contact payload increment.
- Tester, Screwdriver, Cartridge and optional BrassKey are physical reusable Tools tracked by identity in Workshop. Required tools must actually be in the player's Backpack/character. Lost tools cancel work and can be recollected. Kit and replacement reservations use separate ownership maps; cleanup cannot destroy unrelated Tools.
- `GServer/Lore/ShopSecrets` contains three optional discoveries: Timecard, Tape and a key-locked Locker. Only inspected text is exposed; evidence uses UnlockEvidence. Personal run discoveries reset on replay while saved evidence remains. Re-reading gives no money/repair reward.
- `GServer/Shifts/EndingRules` owns eight Story conclusions. Priority: death, answered phone, suspicion >=50, personal three-record archive, Investigate, Hide, Report, ordinary survival. Resolve personal death immediately and survival only after Story night three. Accumulated team choices affect survivors; dead members retain their own ending. `RecordOutcome` runs once per player per earned night with a fresh identifier and actual night number; Endless and interrupted survivors receive no Story ending.

- The owner explicitly requested a playable Game prototype while waiting for assets. `PrototypeWorld` generates only `Workspace.DPU_Prototype` (default origin `(0,0,400)`, optional `Workspace.DontPickUpPrototypeOrigin` BasePart), customers, stations, figures, lamps, and spawn. Preserve other Workspace content. `PrototypeConfig.Enabled` controls startup. `GClient/PrototypeController.local.luau` belongs in Game StarterPlayerScripts with sibling `PrototypeView`; it owns `DPU_PrototypeHUD`, objective highlight, and spectator camera behavior. This temporary content can later be replaced by authored adapters.
- `GamePrototype` connects ShiftService to world, network, admission, and DataService. Never start before GameSession readiness. One safe tutorial repair starts the first clock; later clocks start after all living staff clock in and acknowledge the directive. Dead/late spectators cannot work. Departures after full admission preserve the remaining team; partial initial arrivals still fail closed. A last-survivor departure interrupts the run without inventing outcomes. Post-start published admissions cannot rejoin.
- Prototype actions require current RunId and relevant OrderId/EventId. Future order content stays server-side. `RecordOutcome` records contributed repairs and survival/death with one server-issued ID per player/run; delayed recording and saves retry. Tutorial/evidence use existing APIs. Revenue, stock, suspicion, and decisions are run-local, not persistent money/campaign state. The schema is unchanged.

- `PartyService` owns parties in one Lobby server. A player may belong to one party. Hosts create parties of 1-4 players, choose Friends/Public, kick members, and start/cancel the five-second countdown. Every member must be ready and data-ready. Friendship checks must revalidate the roster after yielding.
- `QueueWorld` binds each child of `Workspace.Queues` by its `Refs.Enter`, `EnterPos`, and `ExitPos` BaseParts, plus `UI.BillboardGui`. `WorldQueueService` reserves an empty pad for 20 seconds, opens setup, and creates an automatic queue. Physical entry is readiness. Depart after 20 seconds including the final five-second countdown; full parties shorten the deadline, and member departure never lengthens it. Keep stable per-member placement slots for entry/exit. Leave/death/expiry releases membership; avoid immediate reentry until the player steps clear. Walking away releases membership without moving the character back. Only queue-owned ObjectValues may be removed from `InQueue`.
- `QueueWorld` binds `Refs.Enter.Touched` at construction and enables CanTouch for immediate server admission/placement/sign updates. Keep root-bounds validation, profile readiness, capacity, busy/retry and leave guards shared through TryEnter. The quarter-second bounds poll is a fallback; do not put a polling wait back on successful contact. Disconnect pad touch listeners on removal/shutdown. No client membership prediction is used; live network responsiveness still needs Studio/multiplayer verification.
- Physical Create/Leave requests require the current per-visit `EntryId`. Never allow delayed requests to alter a later visit. Generic Leave/Ready/Start/Cancel/Kick reject physical queue members. `LClient/Networking/QueueRequests` owns pending operations, bounded unanswered requests, timeout feedback, and stale-reply ownership; server snapshots remain authoritative. Deploy it as a sibling ModuleScript of QueueController and QueueView. Optional authored `Queue.Status` displays queued status and notifications; QueueView creates/removes a small fallback label when absent. Preserve existing control geometry and prevent ImageButton text updates from revealing hidden setup ancestors.
- Physical queues default to Public; generic API parties retain Friends/Public. Story/Endless and versioned GameData (mode, starting night one, party size) live in the MemoryStore admission. Client teleport metadata is presentation-only. GameSession uses the trusted ticket, and DataService loads profiles through the source save/release handoff. Legacy tickets without GameData remain compatible. Never send profile payloads or private-server access codes in TeleportData.
- `LServer/Queues/QueueBillboard` renders the owner's updated `UI.BillboardGui` children: `Icon` with nested `Bar.Gamemode`, `Status`, `PlayerCount`, and `Title`, plus Background. QueueBillboard prefers these names and retain the older GamemodeIcon/Players/GreenStatus aliases. Empty means `SHIFT AVAILABLE / READY`; occupied titles use the current host's shift. Show actual count/capacity and the server departure deadline. Setup/final countdown/preparation use amber; ready/gathering/dispatch use green. Apply these state colors only to Status.TextColor3. Never recolor Background.UIStroke, Title.Frame.UIStroke, direct board strokes or any other authored sign borders. Preserve authored geometry/fonts and all text sizing/wrapping settings. Legacy MapIcon/PartyLeader/Time remain fallbacks. Optional Queue attributes StoryIcon/EndlessIcon override the authored image; capture each replacement image instance's own fallback before applying an override.
- `StudioTeleportPreview = true` runs roster/save checks, prints the selected mode/roster/destination, and releases the queue. It makes no reservation, admission write, or real teleport in Studio. Never print a passed preview after failed saving, and do not treat practice-save output as live verification.
- `TravelService` freezes and saves all profiles before dispatch. Reserve one private Game server per party; reuse its access code across bounded retries. Correlate `TeleportInitFailed` with the active attempt. Revoke failed admissions before thawing profiles; never reopen an ownership-lost profile.
- `TicketStore` issues expiring MemoryStore rosters. Game admission checks source universe/place, destination place/private server, allowed user, expiry, revocation, and destination JobId. Ticket IDs are not permission by themselves; never expose access codes or profile data in teleport payloads.
- `GameSession:IsReady()` is the gate future gameplay must use. Every expected member must arrive and load. Incomplete or interrupted parties must not start a run. Cross-instance/cross-play splits are rejected rather than allowed to run separate copies of one party.
- `DataService` is the only mutation/save owner. `SessionStore` uses atomic UpdateAsync leases, owner-checked serialized saves, and final release. A failed load never becomes a saveable default. Preserve cancellation and ambiguous-write recovery paths.
- Both places use `DontPickUp_PlayerData_v1`, schema 1. Studio defaults to in-memory practice; enabling StudioSaving uses the separate `_STUDIO` store. Never use production data for Studio practice.
- `leaderstats` and `PlayerData` values are replicated views. Never save values read back from instances. Hidden evidence/ending IDs and the profile payload remain server-side. Future systems award progress through `DataService:RecordOutcome`, `UnlockEvidence`, and `CompleteTutorial`, never a client reward remote.
- Outcome replay protection retains the most recent 100 server-issued IDs. It is not a permanent receipt ledger; never reuse it for paid purchases or replay old outcomes after eviction.

## Gameplay authority and state

- Repair tasks: `GServer/Repair/RepairTasks` provides Probes, BatteryFit, Wires, Circuit, Dials and Memory behind WorkPuzzles. Probes must acquire all three readings before diagnosis. Pair moves encode source*10+destination (11-33); circuits/dials use controls 1-6 plus check 7. Memory uses server-clock reveal timing with a 0.8-second lead; control 7 replays and resets progress. Keep current RunId/WorkId/OrderId/revision, ownership, proximity, tool and seating checks. Only solved Repair starts the existing fitting tween. Never accept client completion flags, pointer coordinates, or elapsed-client-time claims.
- `GServer/Repair/BenchTasks` adds Clean, Debris, Broken, Screen, SIM, Fuse, Charger, Sort, Assembly, Screws, Buttons, PhoneNumber, Waves, Meter, Stamp and Speaker. WorkPuzzles selects short seeded chains when expanded=true (all shift work), hides Pending/Seed in snapshots and preserves monotonically increasing revisions between stages. Only the last solved stage completes work or starts the fitting tween. Meter dwell uses server elapsed time; speaker replies are gated by the server demonstration deadline. Secure always requires four screws and no longer accepts Contact increments.
- `GClient/Repair/BenchTaskView` is a required sibling of RepairTaskView. It shares twelve pooled controls and the existing drag protocol, draws two wave traces and a drifting meter, and plays local pitched speaker cues with numbered/silent alternatives. No new per-frame remotes or scene scans. Update only the moving meter between unchanged snapshots. World prompt hold durations: tool 0.5s, part 0.85s, stock 1s, bench 0.4s, counter 0.6s, fuse 1.2s. Keep escape controls immediate. Lobby sign animations remain removed.
- `GClient/Repair/RepairTaskView` is a sibling ModuleScript used by PuzzleView. It pools native controls, wire lines, dial faces and one drag preview; no per-frame remotes or scene scans. Mouse/touch drags submit once on release; tap-source/tap-destination supports touch and controller navigation. Cancel held input on task/revision change, busy state, menu/hazard/death, resize, lost focus and teardown. Memory cues use the existing bounded update and text-only feedback under reduced flashes. Keep black 0.5-transparency content panels and one active task surface.

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

- `GServer/World/ShopLayout` generates a compact 44x42-stud main shop and back stockroom with one eight-stud doorway. The latest owner request supersedes the earlier eight-room design: avoid adding separate stations for each repair step. Counter, two benches, one kit pickup and grouped replacement bins form the core loop; phone/fuse/shelter support horror events. Inspection records sit on the counter and only prompt during inspection. Preserve authored assets outside DPU_Prototype and keep secrets unlabelled. Layout.Access/Rooms blocks interactions through the partition; World:Outside uses Layout.Bounds.
- Diagnose/Repair/Secure/Install/Test all use Bench/RepairSeat/RepairPhone. Validate actual seating and preserve one work reservation per selected bench. Do not recreate TestBench/TestSeat/TestPhone or send players to another chair for final testing. Kit pickup grants all missing reusable tools with server identity checks and retry-safe partial grants; replacement parts remain individual carried Tools.
- The current objective's single reusable Highlight must use AlwaysOnTop so required parts and hazard stations remain visible through walls. Keep ordinary prop labels small, white and occluded; do not highlight every prop simultaneously.
- Game UI now uses off-white/neutral accents and muted warnings, superseding the earlier green terminal HUD. Keep functional wire colors and meter target colors. `GClient/Dialogue/SubtitleView` consumes current server Dialogue IDs and expiry times for customer, radio, inspector and phone speech. Local typing uses MaxVisibleGraphemes, short paginated lines, speaker labels and reduced-motion immediate text. Hide on menus/hazards/death/results; do not restart on repeated snapshots. Disconnect the active-only render callback on expiry/cleanup and never send per-letter remotes. No recorded dialogue voices are added.

## Interface and performance

- Sync new client ModuleScripts `PuzzleView` and `StationInteraction` beside PrototypeController. PuzzleView reuses six controls and only rebuilds their text when work/revision/busy/layout changes. StationInteraction owns the Timeclock close-up and clickable stamp/close controls; restore camera on movement, menus, death, expiry, replacement, reduced motion and teardown. Do not let repair and station views compete for the camera.
- Network retains four scalar fields for ordinary requests; PrototypeAction allows six for RunId, Action, OrderId, WorkId, Move and PuzzleRevision. Keep canonical LServer/Core and mirrored GServer/Core Network synchronized.

- `GClient/Repair/PhysicalRepairView` and `PhysicalRepairTasks` are sibling modules used by PuzzleView. BatteryFit/Wires/Assembly/Screen/Debris/Screws/Clean/Probes use local 3D pieces on RepairPhone.Body. Mouse/touch project InputObject.Position through ScreenPointToRay onto the phone plane; previews stay local and completed gestures submit existing work/order/revision-scoped moves. Do not trust client piece positions or add pointer-stream remotes. Retain button fallback, controller/reduced-camera fallback, owner/seat/hazard/menu checks, multi-touch identity, pending guards, active-only render cleanup and transparency restoration. Release physical pieces before starting RepairAssembly; clear old fitting visuals before building a new physical task. Teammates see authoritative progress, not the local drag preview. Custom phone proportions need authored task positions.
- Repair camera markers now sit nearly overhead; use a 45-degree landscape lens and adapt portrait distance/FOV without crossing the roof; respond to viewport changes. RepairPresentation hides only the local character/accessories, caches exact original visibility, handles DescendantAdded, and restores on exit/death/respawn/menu/hazard/teardown. Never change server character transparency or hide teammates.
- Game repair presentation lives in `GClient/Repair/RepairPresentation`, a sibling ModuleScript of PrototypeController/PrototypeView. Reuse its single Highlight/progress card; camera focus follows the local player's authoritative SeatVisit and stays between repair steps. The client also verifies its actual Humanoid SeatPart/Sit state. Sitting hides side cards, shows the required component/step, and enables Q/B/touch stand. Standing cancels unfinished work; jump, movement, death, respawn, menus, hazards, and cleanup release the close-up. Preserve original camera CFrame, Focus, FOV, subject/type; disconnect and guard obsolete tween callbacks. Respect ReducedMotionEnabled/ReducedFlashes. No per-frame remotes/scans; the focus/cancellation render callback exists only while a camera close-up/return is active.
- `GServer/Customers/CustomerCatalog` contains 270 records (30 original plus 240 composed residents), 12 devices and 12 service profiles. 204 records are ordinary. Jobs vary contacts within the existing two/three-contact template, 3-6 digit sequences, fees and patience (minimum 120 seconds). Story decks only include their chapter's evidence; Endless shuffles after its stable training customer. Never replicate the full catalog or future clues. Hazards precede work/arrivals, pause patience/vote deadlines and leave a recovery gap. Preserve solo play and co-op handoffs.
- `GServer/Repair/RepairTemplates` supplies `ReplicatedStorage.DontPickUpTemplates.RepairPhone` only if missing, clones it into the generated shop, and preserves authored templates. Optional named BaseParts Body/Screen/Battery/Speaker/Keypad and Contact1/Contact2/Contact3 support highlights. Its pivot is bottom center. Bench RepairCamera/RepairFocus Attachments define the shot. Missing contact targets fall back to the phone model.
- `GClient/Repair/RepairAssembly` animates one local component from the tray, above its slot, then into the exact authored CFrame. Server work timestamps determine remaining motion. Preserve/restore LocalTransparencyModifier, disconnect stale completions before cancelling, and clean up on cancellation, hazards, death, results, reduced motion, and teardown. Tween completion never grants gameplay progress. There are no hand rigs or drag-to-disassemble controls.
- `GServer/Anomalies/EventDirector` is server-only. Production nights begin with 90 calm seconds plus 0-15 seconds of jitter; first interruption is harmless. It selects seven weighted event types at decision boundaries, with quiet rolls, no immediate repeats, 85-second per-kind cooldowns, later lethal visitors, five-event and two-planned-scare caps. Do not reveal random seeds, next events, pending scare targets or timestamps before dispatch. The fixed Events list is used only with Director.Enabled=false.
- Minor Knocks/Shadow/DeadAir events pause arrivals/work without damaging players. Existing four hazards retain warnings and counteractions. A pending scare picks one eligible living staff member, cancels when its event ends or the run finishes, and obeys the personal cooldown. All scare routes respect the initial calm period. Later phone puzzles use per-order random seeds; tutorial remains stable.
- `GClient/Effects/ScarePresentation` reuses a hooded face, viewport-camera lunge, impact Sound and localized anomaly Sound. It never owns the world camera. Default audio uses installed Roblox content sounds; optional DontPickUpTemplates.ScareSound overrides the impact. MasterVolume scales audio; reduced motion/flashes uses silent text. Deduplicate IDs, wait for the short dispatch timestamp, discard stale cues, stop pooled audio and cancel tweens on cleanup. No strobe or permanent render callback.
- Attack scare cues now queue one server impact at +0.6 seconds (visual cue +0.25), default 25 HP. Interrupt only the victim's work/focus; always use ShiftService.Damage and existing death/settlement. Damage's accompanying scare is marked Applied and must not queue another injury. Clear pending hits before applying, on death/departure/results/new nights; do not wait for client acknowledgement or change damage for menus/reduced motion. Preserve calm gates, shelter protection for visitor cues, personal cooldowns and no new dispatch across dawn. Injury snapshots and death-cause text make the outcome explicit.
- `GServer/Anomalies/OutdoorRisk` is a server sibling module. World:Outside uses shop-local bounds and one-stud doorway tolerance, returning nil for missing/live-invalid rigs. Shift samples positions once a second, outside decisions every eight seconds after 12 seconds of grace. Chance rises 12% +0.8 points/exposed second beyond grace, capped at 65%. Seven-second warnings can be escaped indoors; failure commits 35 HP before second 180 or 100 HP after, then a 30-second cooldown. Outside warnings are personal, never damage indoor teammates, and postpone new shared disturbances. Tutorial, calm opening and first director interruption are protected; chances/future rolls stay server-only. Reset exposure for missing characters/spectators/results/replay.
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

<!-- BEGIN OWNER-SUPPLIED GAME CONTEXT -->

# DON’T PICK UP — Complete Game Context

## Project overview

**DON’T PICK UP** is a 1–5 player Roblox psychological horror game set inside a government-controlled phone repair shop during the 1980s.

The player is a **Device Repair Associate** working the night shift. On the surface, the job is simple: accept damaged phones, diagnose problems, collect replacement parts, repair the devices, test them and return them to customers.

The horror begins when players discover private messages, photographs, recordings and government information hidden inside the devices.

Players must decide whether to:

* Report suspicious information to the government
* Hide evidence to protect the customer
* Investigate further and risk being caught
* Follow the daily regulations
* Break the rules for moral or personal reasons

Every decision affects government trust, suspicion, future events, customer outcomes and the ending.

The game should feel like a mixture of:

* A hands-on phone repair simulator
* A cooperative job game
* A mystery that slowly connects across multiple devices
* A government surveillance thriller
* A restrained psychological horror experience
* A decision-based story with multiple endings

The repair gameplay is the normal, repeatable core. The horror should interrupt that routine gradually rather than constantly attacking the players.

---

# Core fantasy

The player fantasy is:

> “I am working an ordinary night shift, but every phone I repair could contain something dangerous.”

Players should feel like low-level workers trapped inside a much larger political crisis. They are expected to follow orders without asking questions, but their job gives them access to information the government does not want them to understand.

The most effective horror comes from curiosity, uncertainty and paranoia.

Players should regularly wonder:

* Is this customer normal?
* Am I allowed to open this file?
* Should I report this message?
* Is the government watching me?
* Did someone leave that phone there?
* Is the person outside connected to the evidence?
* Can I trust the regulations?
* Will an inspector discover what we have hidden?
* Are the individual phones connected?
* What happens if we answer the call?

The game should avoid relying entirely on jumpscares. Jumpscares may exist, but tension, observation and difficult choices are more important.

---

# Setting

The game takes place during the **1980s** in a small, run-down phone and electronics repair shop controlled by an authoritarian government.

The shop should contain period-appropriate equipment and decoration:

* Beige CRT monitors
* Old keyboards and terminals
* Corded desk phones
* Early mobile and clamshell-style devices used by the game
* Green monochrome displays
* Paper repair tickets
* Filing cabinets
* Government regulation notices
* Analog clocks
* Fluorescent ceiling lights
* Worn green cutting mats
* Screwdrivers, soldering irons and loose components
* Shelves containing replacement parts
* Rusty horizontal bars across the service window
* A storage room
* A surveillance station
* A waiting area
* A back entrance or alley
* A dark parking lot visible outside

Avoid modern touchscreen technology, modern office furniture, digital window sensors and futuristic equipment unless the story specifically identifies them as unusual government technology.

The shop should initially feel mundane and believable. As the story progresses, small environmental changes should show that the city is becoming more dangerous.

Possible progression:

* Day 1: Quiet streets and normal customers
* Day 2: Increased police presence
* Day 3: Political posters and distant protests
* Day 4: Government checkpoints
* Day 5: Customers begin disappearing
* Day 6: Military vehicles appear
* Day 7 and later: Curfews, blackouts, raids and major story events

The outside world should tell part of the story without requiring constant cutscenes.

---

# Main gameplay loop

The complete loop is:

1. Start the day
2. Read the new government regulations
3. Open the repair shop
4. Receive customers and damaged devices
5. Add devices to the repair queue
6. Diagnose each problem
7. Retrieve the required replacement components
8. Disassemble and repair the device
9. Inspect or encounter information stored inside it
10. Install normal software or government surveillance software when ordered
11. Decide whether to report, hide or investigate sensitive information
12. Test and return the device
13. Handle customers, suspicious people and government inspections
14. Experience the consequences of previous decisions
15. Complete the shift
16. Continue to the next day with new rules and story developments

The player should always have understandable short-term tasks while the larger mystery develops in the background.

---

# Daily regulations

Every day begins with a new set of government directives.

These rules are not permanently consistent. Rules can be added, removed or deliberately contradicted on later days.

Example:

## Day 1 regulations

* Repair every submitted device
* Report suspicious communications
* Allow government officials priority service

## Day 4 regulations

* Do not access customer photographs
* Install surveillance software on marked devices
* Report customers who use prohibited language

## Day 7 regulations

* Certain individuals must be reported immediately
* Unapproved evidence must be destroyed
* Employees may be searched without warning

This system prevents players from mindlessly applying the same answer to every device. They must check the current rules and decide whether they are willing to follow them.

Breaking a regulation can increase government suspicion. Following every regulation may harm innocent customers or prevent players from learning the truth.

---

# Phone repair gameplay

Phone repair is the main repeatable activity and should feel satisfying even without the horror.

A typical repair follows this structure:

1. Receive the device
2. Read the customer’s reported problem
3. Inspect or test the device
4. Identify the damaged component
5. Open the casing
6. Remove screws and disconnected parts
7. Request or collect the correct replacement
8. Install the replacement component
9. Reconnect cables
10. Install required software
11. Reassemble the device
12. Test its features
13. Return it to the customer
14. Receive payment and continue to the next order

Possible problems include:

* Broken display
* Dead battery
* Damaged keypad
* Faulty speaker
* Broken microphone
* Damaged charging port
* Corrupted software
* Disconnected internal cable
* Water damage
* Unusual or unidentified components

Repairs should be short, physical and easy to understand. They should become more complex over time without turning into slow technical work.

Most devices should be normal. Suspicious devices become more effective when players do not expect every repair to contain an event.

Recommended distribution:

* Approximately 70–80% normal repairs
* Approximately 15–25% unusual information or minor anomalies
* Approximately 5% major story events

---

# Information and evidence

While testing or repairing a phone, players may encounter information its owner did not intend to share.

Examples include:

* Suspicious text messages
* Private photographs
* Deleted files
* Unknown contacts
* Recorded phone calls
* Location history
* Political conversations
* Government documents
* Evidence of disappearances
* References to other customers
* Messages warning that the shop is being watched
* Information connected to previous devices
* Evidence exposing government actions

The player should often make a deliberate choice to look deeper. Discovering information should feel like crossing a boundary.

A phone might initially contain one strange message. Several days later, another phone could mention the same person. Eventually, a photograph or recording reveals how those separate clues connect.

The story should reward players who remember names, faces, locations and repeated details.

---

# Evidence decisions

Important evidence creates three main choices:

## Report

Send the information to the government.

Possible results:

* Government trust increases
* Shop suspicion decreases
* The customer may disappear
* Players lose access to part of the mystery
* Government officials may reward the shop

## Hide

Conceal or destroy the evidence.

Possible results:

* The customer may be protected
* Government suspicion increases
* Hidden evidence may be discovered during an inspection
* Future customers may begin trusting the players
* New resistance-related events may become available

## Investigate

Continue searching through the device.

Possible results:

* Players uncover more of the conspiracy
* Additional files or contacts become available
* The repair takes longer
* The customer becomes impatient
* Government monitoring detects unauthorized access
* Players unlock new story paths

Large decisions should use a team vote in multiplayer so one player cannot accidentally determine the entire story.

---

# Multiplayer roles

The game supports 1–5 players. A solo player can complete every required task, while multiplayer allows the team to divide responsibilities naturally.

## Repairer

* Diagnoses devices
* Disassembles phones
* Installs replacement components
* Tests completed devices
* Discovers sensitive information

## Restocker

* Receives component requests
* Searches the storage room
* Identifies compatible parts
* Returns components to the repair desk
* Maintains the shop’s stock

## Camera Operator

* Watches the shop’s surveillance feeds
* Checks the front, alley, storage room and street
* Warns the team about inspectors or intruders
* Notices anomalies other players cannot see directly

## Spy Watcher

* Observes the street and parking lot
* Uses the barred window or binoculars
* Identifies suspicious people or vehicles
* Tracks people watching the shop
* Connects outside activity with evidence found on phones

## Distractor

* Speaks with government officials
* Handles impatient or suspicious customers
* Answers inspection questions
* Keeps officials away from hidden evidence
* Prevents the inspector’s suspicion meter from reaching 100%

These should function as activities rather than rigid character classes. Players should be free to move between jobs.

---

# Customers and anomalies

Customers should range from completely normal to subtly impossible.

Possible suspicious details include:

* An incorrect name or identification photo
* An impossible reflection
* Too many fingers
* A voice that does not match the person
* A customer appearing in a photograph from years earlier
* A person standing outside before their repair order exists
* The same customer appearing twice
* A customer whose shadow has the wrong shape
* An upside-down person watching through the upper window gap
* A customer holding a telephone receiver with no connected base
* Someone remaining under the parking light for the entire shift
* A face visible on a camera but absent from the real location
* A customer who knows what players found on another phone

Anomalies should fit the PS2 horror style. Avoid making every character a screaming monster. Normal-looking people with one incorrect detail are usually more unsettling.

---

# Government inspections

Government inspectors periodically visit the shop for a “routine inspection.”

During an inspection, players may need to:

* Hide unauthorized evidence
* Close private files
* Remove prohibited components
* Answer questions correctly
* Produce repair records
* Distract the inspector
* Prevent access to certain rooms
* Explain missing devices or customers

The inspector has a suspicion level:

* 0%: Routine visit
* 25%: Asking additional questions
* 50%: Checking workstations
* 75%: Searching storage and records
* 100%: Full shop search or arrest event

Inspections should create cooperative panic because ordinary repair tasks may still be happening while the inspector is present.

---

# Simultaneous events

The strongest multiplayer moments happen when several problems occur together.

Example:

* The Repairer discovers a classified file
* The Restocker is searching for a replacement display
* The Camera Operator notices a government vehicle
* The Spy Watcher sees someone photographing the shop
* The Distractor receives an inspector at the entrance
* A phone begins ringing by itself

Players must communicate and decide what matters most.

The game should produce stories players want to discuss after the shift.

---

# Narrative progression

Early decisions should feel small:

> “Should we report this strange message?”

Later decisions should become personal:

> “Should we report this customer even though we know they are innocent?”

Eventually, players may choose whether to:

* Hide evidence from the government
* Help a targeted civilian
* Expose the surveillance program
* Betray another employee
* Cooperate with an underground group
* Sacrifice the shop to reveal the truth
* Remain loyal and protect themselves
* Answer the mysterious final call

Individual phones should gradually reveal one connected conspiracy. The player assembles the story through repeated names, photographs, recordings and locations.

Do not explain the entire mystery immediately. Each day should answer one question while creating another.

---

# Persistent story variables

Player decisions may influence invisible or partially visible values such as:

* Government loyalty
* Government suspicion
* Civilian trust
* Resistance support
* Evidence discovered
* Evidence reported
* Evidence hidden
* Unauthorized files accessed
* Inspectors deceived
* Customers protected
* Major story contacts identified

These variables determine future events, dialogue, regulations and endings.

---

# Endings

The game has multiple endings based on who the players serve, what they report and what they keep secret.

Possible ending directions include:

* Loyal Government Employee
* Arrested During Inspection
* Shop Shut Down
* Civilian Protector
* Government Informant
* Resistance Ally
* Conspiracy Exposed
* Evidence Destroyed
* Missing Employee
* Final Call Answered
* Final Call Ignored

Endings should feel like the result of accumulated behavior rather than a single final button.

---

# Tone and horror direction

The horror should be:

* Oppressive
* Quiet
* Uncertain
* Paranoid
* Political
* Psychological
* Occasionally supernatural
* Built around observation and consequences

Players should feel watched even when nothing is happening.

Use:

* Long periods of normal repair work
* Distant movement outside
* Unexplained phone calls
* Changing government posters
* Customers who know too much
* Quiet surveillance noises
* Flickering fluorescent lights
* Partially visible figures
* Inconsistent records
* Events visible only to one player
* Phones that connect separate story clues

Avoid constant loud scares, excessive gore or monsters appearing every few minutes. Ordinary work becoming slightly wrong is central to the game’s identity.

---

# Art direction

The game uses a dark PS2-inspired horror style.

Visual characteristics:

* Low-poly models
* Coarse hand-painted textures
* Hard baked lighting
* Dirty olive, brown, gray and navy colors
* Sickly green phone screens
* Weak amber desk lamps
* Deep black exterior spaces
* Rusted metal
* Worn paper and damaged equipment
* Subtle dithering and analog noise
* Simple, readable silhouettes
* Limited lighting and restrained effects

The environment should look intentionally old and game-rendered. Avoid polished photorealism, glossy cinematic CGI, smooth modern materials, excessive fog, intense bloom and imagery that looks AI-generated.

The game takes place in the 1980s. Keep props, furniture, signs, vehicles and technology visually consistent with that period.

The service window must use old, rusty horizontal iron bars. Do not add modern electronic window sensors.

---

# UI direction

The UI should feel like government software from an old computer terminal.

Use:

* Monochrome green, pale gray, black and muted amber
* Pixel or bitmap-inspired typography
* Boxy panels
* Simple icons
* Paper forms
* Stamps
* Warning symbols
* Minimal animations
* CRT flicker where appropriate
* Clear interaction prompts

The UI must still be readable and easy for younger Roblox players. Retro styling should never make important controls confusing.

---

# Roblox accessibility

Although the narrative is dark, the gameplay must remain understandable for children and general Roblox players.

Important design rules:

* Give every player a clear current task
* Use short instructions
* Introduce one mechanic at a time
* Keep repair interactions physical and satisfying
* Clearly identify required components
* Make daily regulations easy to reopen
* Highlight important evidence without revealing the correct decision
* Explain consequences through events rather than long paragraphs
* Allow solo players to complete every required role
* Prevent one player from ruining major team decisions
* Keep early shifts simple and short
* Increase complexity gradually

The writing should be clear, concise and natural. Avoid overly complicated political language when a simpler sentence communicates the same idea.

---

# Public game pitch

**DON’T PICK UP** is a 1–5 player psychological horror game where you work the night shift inside a government-controlled phone repair shop.

Repair damaged devices, install surveillance software and uncover messages, photographs and recordings you were never meant to see. Every day brings new regulations, stranger customers and harder decisions.

Report what you discover, hide the evidence or investigate the conspiracy. Your choices change the story and determine how it ends.

It is a cooperative phone repair simulator built around mystery, paranoia and the feeling that someone is always watching.

---

# Short Roblox description

📞 Work the night shift at a mysterious phone repair shop!

Fix broken phones, follow the daily rules and uncover hidden secrets. Choose what to report and what to keep hidden—your choices change the story!

**Fix the phones. Follow the rules. Don’t pick up.**

👥 1–5 Players
🎧 Headphones recommended

---

# Core development principles

When implementing, reviewing or suggesting features for this project:

1. Preserve phone repair as the main repeatable gameplay.
2. Connect horror events to the repair shop, customers, devices or government.
3. Keep the 1980s setting visually consistent.
4. Make multiplayer roles useful without making them mandatory classes.
5. Ensure solo players can complete the game.
6. Build tension through uncertainty rather than constant attacks.
7. Keep anomalies uncommon enough to remain surprising.
8. Make major decisions affect later gameplay.
9. Let story clues connect across several phones and days.
10. Keep instructions understandable for younger Roblox players.
11. Use the established dark PS2 visual direction.
12. Do not introduce modern technology without a story reason.
13. Avoid changing major story systems without checking this document.
14. Prioritize clear, physical and cooperative gameplay.
15. Every feature should strengthen at least one of these pillars: repair, observation, communication, choice or consequence.

Treat this document as the main source of truth for the game’s setting, gameplay loop, tone and intended player experience.

<!-- END OWNER-SUPPLIED GAME CONTEXT -->
