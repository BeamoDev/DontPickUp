# First playable Game prototype

## Start playing

Open **Game place `111652489432168`** and sync:

- `src/GServer` into a container inside **ServerScriptService**. `Bootstrap.server.luau` is the only executable Script; every other file is a ModuleScript. Keep Core and the new prototype modules together.
- `src/GClient` into **StarterPlayer.StarterPlayerScripts**. `PrototypeController.local.luau` is a LocalScript; `PrototypeView`, `RepairPresentation`, `RepairAssembly`, `ScarePresentation`, `PuzzleView`, and `StationInteraction` are sibling ModuleScripts.

Press **Play**. Existing `StudioAllowDirectGame = true` admits Studio players without a Lobby teleport. Data loading and party readiness finish before training starts. The client creates `PlayerGui.DPU_PrototypeHUD`; no Game models or UI need to be authored first.

The shop generates under **Workspace.DPU_Prototype**, centered at `(0, 0, 400)`. To choose its position, add a BasePart named **DontPickUpPrototypeOrigin** directly under Workspace before Play; its CFrame becomes the origin. Leave room around it for the shop/street. Existing Workspace assets are preserved.

`PrototypeConfig.Enabled = false` disables the prototype and tells its client to remove the temporary HUD. Shutdown restores the original Lighting values and player respawn locations. Generated runtime geometry is not a saved Studio place asset.

## Playable loop

### Story, Endless and the party handoff

**Story** is a three-night introductory arc: The First Shift (Ward Seven), Station Nine, then The Transfer List. The third customer slot contains the chapter's linked evidence phone; future chapter evidence is excluded from its deck. Choices, suspicion, answered calls and personal keepsakes carry forward. Survival on night three resolves the Story ending; personal death resolves the death ending immediately. Intermediate dawns save earned progress without granting a premature ending.

**Endless** scores completed nights and continues without a final Story chapter. Event frequency and job pressure increase gradually, then cap. The 90-second calm opening, bounded scare count and at least 120 seconds of customer patience remain. At dawn, surviving staff choose **NEXT NIGHT** together. Dead staff remain spectators and do not block readiness or receive repeated death rewards. HP carries over. When everyone dies, **NEW RUN** resets everyone to night one. A completed Story also offers NEW RUN.

Each night begins with a short mode/chapter introduction, clock-in and directive acknowledgement. Only night one requires the training repair. Later nights start their clock once all living staff have acknowledged. Supplies and physical kit reset between nights; decisions and discoveries do not. Each earned night receives a fresh outcome ID and saves through the existing profile API. Shared runs stay in this server: leaving does not create a resumable checkpoint.

The customer database contains **270 identities**: 30 original records plus 240 composed residents. **204 are ordinary**, with unusual/anomalous dialogue kept in the minority. Twelve devices and twelve service profiles vary fees, patience, two/three required contacts, and 3-6 input verification sequences. Each puzzle generates independent targets from its server-owned job seed. Only the current task is sent to its operator; the database remains server-only. The prototype still has one shared repair bench, with intake, diagnosis, delivery and fitting transferable between teammates.

Lobby admission stores **GameData `{Version = 1, Mode, StartNight = 1, PartySize}`** beside the expected 1-4 player roster. TeleportData contains a public copy for presentation; GameSession trusts the server ticket, never this client-visible copy. Saved profiles are frozen/saved before departure and loaded through DataService in the destination. A partial initial arrival cannot start. After full admission, a departure removes that member while friends continue; rejoining an already-started published admission is rejected. The last living player leaving interrupts unfinished play.

Sync **LServer, GServer and GClient**, including `GServer/ModeRules`. Use matching `Core.Config.StudioGameMode = "Story"` or `"Endless"` in both Core copies for direct Studio testing. Studio teleport preview remains print-only. Test both modes with 1, 2, 3 and 4 clients: intro, handoffs, death, partial ready, next night, disconnect, and final/new-run results. Published teleports, live saving and rendered multiplayer behavior still require Studio/application verification.

### Minimal prototype UI

Content panels use black backgrounds with **0.5 transparency**, restrained green action accents, and transparent text labels. Ordinary play shows a small centered status header and one objective/action card. **SHIFT INFO** opens a scrollable ticket, team, earnings, keepsakes and directive view; **BACK TO WORK** closes it. Briefings, votes and results hide the ordinary HUD. Timeclock inspection and local puzzles also hide it, leaving the relevant controls. Seated work keeps a stand-up button; only fitting displays a progress bar. Urgent errors remain visible, and incidental notices stay out of close-up work.

Every generated prototype sign uses **`UDim2.fromScale(4.8, 1.1)`**. Billboard scale is in world studs, so signs shrink with distance instead of keeping a fixed pixel size. They stop rendering beyond **35 studs** and remain occluded by world geometry. Authored Lobby billboards retain their existing layout. Verify readability and control placement in Studio at desktop and phone sizes; local tests cover visibility transitions, not rendered appearance.

### Interactive work and exploration

The timeclock prompt opens inspection rather than stamping immediately. The camera moves to its InteractionCamera Attachment; click **CLOCK IN**, or close with Q/B/the close button. Each visit has a server-issued FocusId and expires after 30 seconds. Walk away or open the Roblox menu to leave. Reduced motion keeps the buttons with the ordinary camera.

Collect the reusable **Tester**, **Screwdriver**, and **Cartridge** separately as prompted. These are actual Tools; keeping them in the Backpack counts. Replacement parts remain separate per-order pickups. Tools survive ordinary steps, are cleared on death/replay, and can be recollected if lost. Other staff can deliver replacement parts while the operator stays seated.

| Task | Player input |
| --- | --- |
| Diagnose | Read voltage, continuity and keypad measurements; select the failed component |
| Repair Battery | Flip three contacts to match printed polarity, then check |
| Repair Speaker | Cycle three wire colors to match terminals, then check continuity |
| Repair Keypad | Enter the printed four-key calibration sequence |
| Secure | Tighten three physical contacts in order using the screwdriver |
| Install | Enter the cartridge's four-digit verification code |
| Test | Repeat the final three-input function-test sequence |
| Restock | Sort Battery/Speaker/Keypad labels in manifest order |

Only the current operator sees the puzzle controls. Incorrect answers show feedback or reset sequence progress; they never grant completion. Waiting 120 seconds closes an abandoned task. Standing, tool loss, departure and hazards cancel it. After solving a repair, a 1.2-second fitting animation places the component; all other puzzles advance directly on valid inputs. World prompts now use immediate activation; the work is in the controls.

Search the shop for a discarded timecard, unmarked tape, and small brass key. The key opens a locked archive drawer. Each record unlocks personal evidence through the existing profile API; rereading grants nothing extra. Finding all three records in the current run makes **The Night Archivist** available at survival, below answered-call and high-suspicion outcomes in priority. Objects and their owned text/geometry are temporary modeller-replaceable content.

New server modules: **WorkPuzzles**, **ShopSecrets**. New client modules: **PuzzleView**, **StationInteraction**. Sync the updated **Core/Network** too: PuzzleInput uses six scalar fields: `RunId, Action, OrderId, WorkId, Move, PuzzleRevision`. Restocking has no OrderId. Puzzle revisions reject delayed clicks; the operator and physical station/tool/seat remain server-checked.

1. **Arrival and directive:** spawn outside the shop, open the STAFF DOOR, enter, and use the TIMECLOCK. Clock-in requires being inside, within five studs. Every active staff member clocks in and acknowledges the rules before the first customer arrives. Training has no customer timeout or scripted scares; the clock waits for the first completed repair.
2. **Repair:** accept at INTAKE, sit at REPAIR BENCH, and diagnose the phone. Stand up, walk through the PARTS ROOM doorway, and take the indicated Battery, Speaker, or Keypad from its shelf. Collection equips a physical Tool. Bring it back and **PLACE REPLACEMENT**, then sit to fit it. The component tweens from the tray into its exact phone slot. Tighten the three highlighted contacts, install the government package, and test. Stand and return the phone at INTAKE. E, touch prompts, and nearby HUD actions all use the same server checks.
3. **Night:** the first training return starts a six-minute clock from midnight to 6 AM. Later nights start after briefing. Job-specific patience never falls below 120 seconds; tickets show the device, complaint, service profile, diagnosed part and quoted fee. Training pays $45. Missed orders raise suspicion. The supply crate replenishes the currently needed part.
4. **Evidence:** three catalog customers contain linked Ward 7, Station Nine, and transport clues. Report/Hide/Investigate needs a strict majority of living staff or resolves after 18 seconds. Timeout ties prefer Report, then Hide, then Investigate; no votes means Report. Investigation unlocks that customer's server-issued clue. Future clues stay server-side until discovered.
5. **Disturbances:** restore a blackout, silence the disconnected phone, present records to an inspector, and shelter from a visitor. Hazards stop new arrivals, suspend approaching customers, stand seated staff, and cancel unfinished work. Existing customer patience and team-vote deadlines pause; the night clock continues. Service reopens after a six-second quiet period. Warnings have response deadlines. Ignoring disturbances causes damage; the final visitor is fatal outside the marked storage shelter. Answering the phone is an explicitly labeled dangerous alternative.
6. **Results:** living staff survive at dawn; all staff dying ends the night immediately. Dead players cannot work after respawning and watch a living teammate until results. The summary shows team repairs, missed customers, earnings, personal repairs, team status, decisions, and save status.
7. **Continue/new run/return:** continuing requires every remaining survivor to ready on results; a new run requires all remaining staff. A fresh RunId prevents stale actions/outcomes crossing nights. Lobby return requires visible confirmation and a recorded result; existing save/freeze/teleport code handles transfer. Studio runs its print-only return preview.

Published admission requires the reserved-server ticket. Interrupted runs do not fabricate outcomes. Studio players arriving after a night starts spectate until a new run. The latest owner request sets the supported capacity to 1-4.

## Modules

| File | Responsibility |
| --- | --- |
| `GServer/PrototypeConfig` | Night length, customers, directive, hazards, interaction distances, work durations |
| `GServer/CustomerCatalog` | 270 server-only identities, 12 devices, 12 service profiles, chapter-filtered clues and shuffled decks |
| `GServer/ModeRules` | Three-night Story chapters, Endless continuation, introductions, directives and capped pressure |
| `GServer/Workshop` | Physical repair Seat, authentic carried Tools, component cloning and cleanup |
| `GServer/ShiftService` | Authoritative tutorial, orders, stock, work, votes, damage, results, replay |
| `GServer/EndingRules` | Eight deterministic epilogues resolved only for earned personal outcomes |
| `GServer/PrototypeWorld` | Temporary shop, customers, inspector/visitor, lights, prompts, spawning |
| `GServer/GamePrototype` | Admission/profile integration, save requests, snapshots, world adapter |
| `GServer/RepairTemplates` | Reusable fallback phone template, authored model cloning, owned-template cleanup |
| `GClient/PrototypeController` | Remotes, bounded HUD updates, spectating, request ownership, cleanup |
| `GClient/RepairPresentation` | Repair camera transitions, component/objective highlight, progress, input and camera restoration |
| `GClient/RepairAssembly` | Local replacement-part fitting tweens and visibility restoration |
| `GClient/ScarePresentation` | Pooled scare face, text cue, optional audio, age filtering and cleanup |
| `GClient/PrototypeView` | Terminal HUD, directive, tickets, team vote, warnings, results, controls |

Prompts and HUD actions both require server distance, alive/data-ready state, current order, and valid phase. A single work reservation prevents simultaneous duplicate repairs. Bench work also requires the server's real Seat occupancy and Humanoid seated state. Standing, moving away, disconnecting, or a disturbance cancels unfinished work. Shelf/crate interactions require being inside the parts room and within five studs; bench interactions allow six studs.

Collection reserves one stock and issues one authentic, non-droppable Tool. Server-owned identity links it to its player/run/order; copied Tool attributes do not grant authority. Deposit transfers it to the bench, where any seated teammate can fit it. Cancellation preserves a deposited component. Death/disconnect/lost tools return unused carried stock exactly once. Expiry/results/replay remove owned tools and return unfitted parts. A successful fit consumes the reserved part once; a completed return pays once.

**Co-op:** a repairer can remain seated after diagnosis while another player collects and deposits the replacement. The carrier's name and delivery state appear in snapshots/HUD. Solo players follow the same loop using the stand control. There is one repair chair and one shared order; parallel workbenches are not implemented.

The catalog contains 24 ordinary customers, five unusual customers, and one major anomaly. The first three introductions remain stable (Mara, Arthur, Nina); the remaining 27 shuffle without repeats in a cycle on replay. Device labels and coats vary, but use the same temporary phone/customer geometry. This is authored prototype content, not a complete branching campaign.

## Networking and persistence

Existing `DontPickUpGameNet.Request` accepts:

- `GetPrototype`: personal snapshot; unadmitted callers receive only a loading message.
- `PrototypeAction`: `{ RunId, Action, OrderId? }`. Workshop actions include `Sit`, `Stand`, `Collect`, and `DepositPart`. `Collect` may include `Part`; it must match the diagnosed fault and actual shelf. Voting uses `{ RunId, Action = "Vote", OrderId, Choice }`. Event responses use `{ RunId, Action, EventId }`.
- Existing `ReturnLobby` after results, plus existing `SetSetting` and session `GetState`.

`StateChanged` sends `Kind = "Prototype"` snapshots when the run revision changes, coalesced by the quarter-second server tick, plus a five-second refresh and immediate action responses. Idle ticks do not generate revisions. Clients reject older revisions. Personal `Seated`, `SeatVisit`, and `CarriedPart`, plus order `PartDelivered`, `PartCarrier`, `Paused`, and `PatienceRemaining` describe the workshop flow. Work snapshots expose owner UserId, Station, StartedAt, and EndsAt. Hidden future orders and sensitive-device flags remain server-side. World prompts derive actions from server state. Common rate and scalar-payload limits remain intact.

## Repair presentation and templates

Sync **all of GServer and GClient**, including `CustomerCatalog`, `Workshop`, `RepairTemplates`, `RepairPresentation`, `EndingRules`, `RepairAssembly`, and `ScarePresentation`. No asset uploads or animation IDs are required.

- Sitting eases the camera toward the phone over 0.32 seconds and keeps it there between steps. Standing normally eases back over 0.24 seconds; urgent exits restore immediately. Bench work requires remaining seated.
- **Q, gamepad B, jump, or STAND UP** leaves the chair and cancels unfinished bench work. Movement, real Humanoid death, character/camera replacement, opening the Roblox menu, a shop disturbance, rules/voting/results UI, or teardown also releases the camera. A dismissed seat visit does not recapture the camera. Existing Scriptable cameras are not taken over. Reduced motion leaves the ordinary camera available with the seated repair UI.
- One reusable, occluded Highlight marks the objective. At the bench it marks the diagnosed Battery, Speaker, or Keypad in amber until fitted, and Screen for diagnosis/software/testing. Standing players see the required shelf highlighted. Missing component names fall back to the phone model. Hazards redirect it to their response station.
- Sitting hides the side cards and displays a repair panel with the fault/next step, progress bar, and stand control. Between work steps the panel remains visible without a looping tween. The bar follows the authoritative deadline, not a client-issued completion or reward. Repeated snapshots do not restart it. Evidence modals close during hazards so emergency controls remain usable.
- Roblox `GuiService.ReducedMotionEnabled` and the existing `PlayerData.Settings.ReducedFlashes` setting suppress camera motion while retaining progress and highlights. There is no shake, strobe, blur, or permanent render callback. Camera/FOV/subject/focus are restored on release; pending tween callbacks are disconnected and ownership-checked. See Roblox's [camera API](https://create.roblox.com/docs/reference/engine/classes/Camera) and [reduced motion setting](https://create.roblox.com/docs/reference/engine/classes/GuiService#ReducedMotionEnabled).

The server creates this fallback template only when it is missing:

```text
ReplicatedStorage
  DontPickUpTemplates
    RepairPhone (Model; pivot at bottom center)
      Body (BasePart)
      Screen (BasePart)
      Battery (BasePart)
      Speaker (BasePart)
      Keypad (BasePart)
      Contact1 (BasePart)
      Contact2 (BasePart)
      Contact3 (BasePart)
    ScareSound (optional Sound; use an audio asset owned/permitted by your experience)
```

Your modeller can author that Model before Play. The server clones it once into `Workspace.DPU_Prototype.RepairPhone`, anchors cloned parts, disables their collisions/touch events, and preserves the source. Named component parts may be nested; they are optional. Keep a correctly placed bottom-center model pivot. Only fallback templates created by this system are removed on shutdown.

`Workspace.DPU_Prototype.Bench.RepairCamera` and `.RepairFocus` are Attachments defining the close-up view and focal point. Adjust them to fit a replacement phone. The default scene supplies both. Fitting clones only the diagnosed component locally, hides the original and tray, lifts the clone into alignment, then lowers it to the authored component CFrame. Late snapshots enter the remaining tween stage. Cancellation, hazards, death, reduced motion, results, and cleanup restore the captured visibility. The next Contact1/2/3 is highlighted while securing; absent targets fall back to the model. This uses [local-only part transparency](https://create.roblox.com/docs/reference/engine/classes/BasePart#LocalTransparencyModifier). No screw dragging or hand rigs are implemented.

## Optional activities, scares, and endings

## Randomized night and scare debugging

Production uses `GServer/EventDirector`. Tutorial is safe, then the first **90 seconds after midnight** contain no director events or jumpscares (including the radio). The first interruption occurs after another 0-15 seconds and is harmless. Existing fixed timestamps apply only when `PrototypeConfig.Director.Enabled = false`.

- Randomized types: **Knocks**, **Shadow**, **DeadAir**, **Blackout**, **Call**, **Inspection**, **Visitor**. Minor events never deal damage. Knocks play at the staff door; dead air plays at the radio; shadows appear outside the window.
- Decisions choose weighted events, duration, and a 28-52 second next interval. Active events/recovery postpone the next decision; quiet rolls can skip one. No consecutive identical event; each kind has an 85-second cooldown. Visitors cannot occur before 180 seconds. Higher suspicion increases inspection weight.
- At most five director events and two planned personal scares per night. After the first event, a decision has a 45% scare chance while that budget remains. Damage and player-triggered radio scares separately retain their 20-second personal cooldown. Completing a counteraction can cancel a scheduled hit.
- Pending targets/timing stay server-side. Debug output appears before the hit; the client only receives the dispatched cue with a 0.25-second lead. Replay/results clear pending work, and unavailable/cooling targets are skipped. The random stream is private; no random rolls run every frame.
- Non-training phones now receive randomized puzzle seeds; the first training phone remains predictable for learning.

`PrototypeConfig.DebugScares = true` logs in Studio. `DebugScaresInLive = false` keeps published diagnostics off. Expected Output:

```text
[DPU][Scare] COMING kind=Signal player=PlayerName in=2.75s
[DPU][Scare] DISPATCHED: scheduled scare
[DPU][Scare] CANCELLED: disturbance ended before the scare
```

Scares use a pooled hooded face with teeth, one 0.14-second viewport-camera lunge, three framing/pitch variants, and an 0.8-second fade. The player's world camera stays with its current controller. The default sting uses `rbxasset://sounds/impact_explosion_03.mp3`; local Roblox installations were checked for this content file. Default anomaly sounds also use installed Roblox content. Audio still needs listening checks in Studio and on devices. No uploaded sound is required.

Performance checks cover zero idle assembly scene lookups, zero extra calm-period random rolls, and reuse of prompt bindings across twenty puzzle/profile revisions. The director, audio beats and expiry reuse existing bounded ticks; no new permanent render loop or per-frame network messages. These checks do not measure real frame time.

- Open/close the staff door. After clock-in, tune three radio channels, read the current shift log, and switch the bench light. These work without a customer; radio/log/light also work during disturbances. Restocking between customers fills the lowest shelf, two units at a time, up to eight. Activities do not grant repairs, money, or evidence unlocks.
- Night damage can trigger a brief personal scare. The dead-air radio channel can trigger once per staff member per night. A shared 20-second personal cooldown prevents stacking; training is safe. Scares use one generated low-poly face in a [ViewportFrame](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame), never the world camera. Old snapshots are discarded and repeated IDs do not replay. The normal effect lasts 0.8 seconds; reduced motion/flashes shows silent text for 1.5 seconds. Menus clear it.
- Add `ReplicatedStorage.DontPickUpTemplates.ScareSound` before Play to replace the default impact audio. The local clone uses at most 0.6 volume multiplied by MasterVolume and is destroyed when the cue ends; the authored Sound is preserved. Default impact/anomaly Sounds are reused and stopped between cues.
- Eight Story conclusions appear above the result stats. Priority is **Missing Employee** for death; for survivors at the end of night three, **The Line Is Still Open** if anyone answered, **Under Observation** at suspicion 50+, **The Night Archivist** after all three personal keepsakes, **After-hours Witness** after Investigate, **Civilian Protector** after Hide, **Loyal Employee** after Report, otherwise **Another Morning**. Decisions and discoveries accumulate across the short arc.
- Ending IDs use `RecordOutcome` and `Progress.Endings`; no schema change or reward remote. Dead teammates retain their personal death ending. Endless and interrupted survivors receive no Story ending. Next-night readiness preserves the run; NEW RUN clears it.

`Secure` requests include `{ RunId, OrderId, Action = "Secure", Contact }`, where Contact is the next index (1-3). Distance, real seating, current step, expiry, and cooldown are server-checked; a delayed duplicate cannot secure another contact. ClockIn is idempotent. Optional actions use their station and a shared per-action cooldown (radio three seconds, other activities one second).

## Performance changes and validation limits

- Gameplay validation stays on the quarter-second server tick. Scene/prompt bindings rebuild only when a revision changes; occupied stations disable their work prompt. Lighting advances once per game minute.
- Night time is derived locally from NightStartedAt/NightDuration and freezes at TimeFrozenAt. Network packets are not needed to advance the clock or work bar.
- The controller refreshes timed HUD text at most once per second between state updates, skips untimed idle refreshes, and only reapplies responsive layout when its viewport category changes. Highlights are reused and properties are written only when changed.
- TweenService interpolates camera/progress effects. One small RenderStepped callback exists only during a close-up/return to update camera focus and check local cancellation. There are no per-frame remotes, scene scans, or model clones.
- The deterministic ten-second idle fixture sends **2 refresh snapshots instead of the previous 20**. This measures scheduling, not real network bytes, FPS, server capacity, or latency. Studio and published multiplayer profiling are still needed before making lag claims.

The profile schema is unchanged. `RecordOutcome` records contributed repairs and survival/death once per player per earned night, using a fresh identifier and the night number. Dead spectators are not awarded further outcomes. Tutorial and evidence use existing APIs. Delayed recording retries; continuation and return wait until the result enters the profile. Save status is visible, failed saves retry, and transfers save again. Playtime stays owned by DataService.

Revenue, stock, suspicion, orders, and team decisions are **run-local**. This does not add persistent money or resumable campaigns. StudioSaving false uses session-only practice storage; published play uses the configured profile store. Interrupted survivors receive no invented death/survival outcome.

## Limits and checks

This is a generated-shop prototype with a short three-night Story and continuing Endless nights. The larger authored campaign, additional repair hardware and persistent shared checkpoints remain future work. Characters, props, repairs and clues are temporary. Authored assets can replace the world adapter later.

Run all five suites in README. `tests/Prototype.luau` covers complete survival, death/shelter, training, work cancellation, duplicate rewards/parts, voting, outcomes, interruption, replay, and generated world/UI bindings. Adapter tests use mocked services/instances and real vector math; they do not render Roblox.

Still test in Studio: spawn/directive, doorway access and shelf reach, Tool grip/equipping, actual Seat occupancy, full solo repair, two-client part delivery, restocking, NPC movement, paused approaches, shelter geometry, lighting/clock, death/respawn/spectating, replay, mobile landscape text, and Output. Test every component highlight; Q/B/touch/jump exit; movement, menu, death and hazard cancellation; camera replacement; reduced motion; and back-to-back repairs. Use MicroProfiler and network statistics with multiple clients and a lower-end mobile device. Verify real saves and Lobby return separately in published clients. Physical behavior follows Roblox's [Seat API](https://create.roblox.com/docs/reference/engine/classes/Seat) and [Tool API](https://create.roblox.com/docs/reference/engine/classes/Tool).
