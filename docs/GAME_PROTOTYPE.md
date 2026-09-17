# Playable Game prototype

The complete prototype is restored and enabled by default. Use [PROTOTYPE_RESTORATION](PROTOTYPE_RESTORATION.md) for current startup paths, deployment, switching modes and the new closing phase. The feature details below describe the recovered game; all runtime files now sit directly in flat Prototype system folders.

## Shop floor plan and placeholders

The compact shop covers **44 by 42 studs**: a main shop with two independent repair benches and one back stockroom, connected by an eight-stud doorway. `GServer/World/WorldLayout` retains the room/access definitions; the shell and props are saved under `Workspace.Prototype.DPU_Prototype`. See [authored asset binding](PROTOTYPE_ASSETS.md). Separate testing, software, records and staff rooms are removed.

| Area | Contents and purpose |
| --- | --- |
| Main shop | Barred service window, intake/return counter with inspection records, two independent repair/testing benches, repair kit, entrance and timeclock |
| Back stockroom | One shelf with three replacement bins, supply crate, shelter, phone/radio desk and fuse box |

The ordinary loop is **counter ? bench ? replacement shelf ? bench ? counter**. Collect one repair kit beside the bench to receive the reusable Tester, Screwdriver and Cartridge together. Each replacement part is still carried and fitted individually. All diagnosis, fitting, software and final testing use **Bench/RepairSeat/RepairPhone**; no second chair or phone transfer is needed. Leaving the chair still cancels unfinished work, and solo/team handoffs use the existing shared work reservation.

Clock-in stays beside the exterior staff entrance; players spawn outside. Props have small white labels naming their intended final asset: **3.8 x 0.55 scaled studs**, transparent backing and a **22-stud** range. Secret pickups remain unlabelled. Inspection records only show a prompt during an inspection. The current objective uses one **AlwaysOnTop Highlight** visible through walls; nearby labels stay occluded to limit clutter.

## Horror presentation and subtitles

**Physical repairs:** supported tasks now replace the large button panel with local, anchored 3D pieces directly over the phone body. Drag cells/wire ends/assembly pieces into numbered positions, lift and replace the screen, move debris to the waste tray, drag screws sideways through three notches each, scrub dirt patches twice, and touch probe pads before selecting a diagnosis. Mouse and touch gestures use the same server puzzle revisions; no pointer coordinates, physics updates or completion claims are sent. Wrong moves stay subject to the existing rules. Accepted placements snap into position; hazard/menu/seat/work changes cancel unfinished gestures.

**USE BUTTONS / USE 3D** switches presentation without changing puzzle progress. Controller input, reduced-motion camera fallback, missing phone Body or unavailable close-up use the existing task panel. Other task kinds remain in that panel. Physical pieces are temporary client-only blockout geometry; teammates receive shared server progress, not each pointer movement. A phone template's Body top surface anchors the prototype task positions; custom-sized models need an authored task layout before release.

Your own character and accessories are hidden locally while seated in a repair close-up, including accessories added during the visit. Original transparency values and the camera are restored when leaving, dying, changing character, opening menus, encountering hazards or tearing down. Other players' character visibility is unchanged. Camera framing adapts when the viewport changes. Scene nodes are reused across revisions; the render callback exists only while physical controls are active. The controller releases their phone transparency overrides before starting the cosmetic fitting tween.

Pointer coordinates use InputObject.Position with Camera.ScreenPointToRay; both account for GUI inset. See Roblox's [input position contract](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/InputObject.yaml) and [camera projection contract](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Camera.yaml). Actual touch alignment and rendering still require Studio/device checks.

The HUD and repair controls use off-white text, charcoal/black panels and muted amber warnings instead of neon green. Functional wire colors and the power meter's green target remain readable task signals. Normal play shows the compact shift header and objective; expanded information stays behind SHIFT INFO.

Customer complaints, return lines, radio broadcasts, inspector replies and the disconnected phone feed server-issued **Dialogue** records with stable IDs and expiry times. `GClient/Interface/DialogueController` reveals text locally at 32 characters per second, labels the speaker and splits long lines into short pages. Repeated snapshots never restart typing. Reduced motion displays each page immediately. Menus, hazards, death and results hide speech; expired/old-night lines never replay. The callback exists only while a caption is active, with no per-letter remotes, input blocking or typing sound spam. On landscape phones captions sit beside the task panel.

Dialogue subtitles represent scripted speech; this change does not add recorded customer voice acting. Test text placement, reading speed and room lighting in Studio on desktop/mobile before tuning further.

## Playable loop

### Story, Endless and the party handoff

**Story** is a five-night introductory arc: The First Shift (Ward Seven), Station Nine, The Transfer List, The Listening Room, then The Last Report. The third customer slot contains the chapter's linked evidence phone; future chapter evidence is excluded from its deck. Choices, suspicion, answered calls and personal keepsakes carry forward. Survival on night five resolves the Story ending; personal death resolves the death ending immediately. Intermediate dawns save earned progress without granting a premature ending.

**Endless** scores completed nights and continues without a final Story chapter. Event frequency and job pressure increase gradually, then cap. The 90-second calm opening, bounded scare count and at least 120 seconds of customer patience remain. At dawn, surviving staff choose **NEXT NIGHT** together. Dead staff remain spectators and do not block readiness or receive repeated death rewards. HP carries over. When everyone dies, **NEW RUN** resets everyone to night one. A completed Story also offers NEW RUN.

Each night begins with a short mode/chapter introduction, clock-in and directive acknowledgement. Only night one requires the training repair. Later nights start their clock once all living staff have acknowledged. Supplies and physical kit reset between nights; decisions and discoveries do not. Each earned night receives a fresh outcome ID and saves through the existing profile API. Shared runs stay in this server: leaving does not create a resumable checkpoint.

The customer database contains **270 identities**: 30 original records plus 240 composed residents. **204 are ordinary**, with unusual/anomalous dialogue kept in the minority. Twelve devices and twelve service profiles vary fees, patience and 3-6 input verification sequences; casing closure now always requires four screws. Each puzzle generates independent targets from its server-owned job seed. Only the current task is sent to its operator; the database remains server-only. The prototype has two independent repair benches, each handling its own final test, with intake, diagnosis, delivery and fitting transferable between teammates.

Lobby admission stores **GameData `{Version = 1, Mode, StartNight = 1, PartySize}`** beside the expected 1-4 player roster. TeleportData contains a public copy for presentation; GameSession trusts the server ticket, never this client-visible copy. Saved profiles are frozen/saved before departure and loaded through DataService in the destination. A partial initial arrival cannot start. After full admission, a departure removes that member while friends continue; rejoining an already-started published admission is rejected. The last living player leaving interrupts unfinished play.

Sync **LServer, GServer and GClient**, including `GServer/Session/ModeRules`. Use matching `Core.Config.StudioGameMode = "Story"` or `"Endless"` in both Core copies for direct Studio testing. Studio teleport preview remains print-only. Test both modes with 1, 2, 3 and 4 clients: intro, handoffs, death, partial ready, next night, disconnect, and final/new-run results. Published teleports, live saving and rendered multiplayer behavior still require Studio/application verification.

### Minimal prototype UI

Content panels use black backgrounds with **0.5 transparency**, restrained off-white action accents, and transparent text labels. Ordinary play shows a small centered status header and one objective/action card. **SHIFT INFO** opens a scrollable ticket, team, earnings, keepsakes and directive view; **BACK TO WORK** closes it. Briefings, votes and results hide the ordinary HUD. Timeclock inspection and local puzzles also hide it, leaving the relevant controls. Seated work keeps a stand-up button; only fitting displays a progress bar. Urgent errors remain visible, and incidental notices stay out of close-up work.

The copied prototype signs originally used **`UDim2.fromScale(3.8, 0.55)`**. Billboard scale is in world studs, so signs shrink with distance instead of keeping a fixed pixel size. They stop rendering beyond **22 studs** and remain occluded by world geometry. Authored Lobby billboards retain their existing layout. Verify readability and control placement in Studio at desktop and phone sizes; local tests cover visibility transitions, not rendered appearance.

### Interactive work and exploration

The timeclock prompt opens inspection rather than stamping immediately. The camera moves to its InteractionCamera Attachment; click **CLOCK IN**, or close with Q/B/the close button. Each visit has a server-issued FocusId and expires after 30 seconds. Walk away or open the Roblox menu to leave. Reduced motion keeps the buttons with the ordinary camera.

Collect the **repair kit** once to receive the reusable **Tester**, **Screwdriver**, and **Cartridge** together. These are actual Tools; keeping them in the Backpack counts. Replacement parts remain separate per-order pickups. Tools survive ordinary steps, are cleared on death/replay, and can be recollected if lost. Other staff can deliver replacement parts while the operator stays seated.

The first night keeps one primary puzzle per work phase (reassembly still includes screws). Later nights add short seeded task chains: diagnosis plus one cleanup/inspection task; the fault-specific repair plus one fitting task; ordered reassembly and four screws; the usable customer-phone menu; a signal/speaker test, sometimes power balancing, then the repair form. The same work reservation owns the whole chain. The stage counter shows progress; only the current stage is sent to the operator.

| Task | Player input |
| --- | --- |
| Diagnose | Probe three test points, then identify the fault |
| Battery | Drag marked battery cells into matching phone bays |
| Wires | Match colored, numbered wires to their sockets |
| Screws | Turn each of four screw heads three notches |
| Screen | Drag cracked screen to recycling, fit replacement, press four clips |
| Cleaning | Scrub each of six dirt patches twice |
| SIM | Rotate the notch to match the slot, then drag the card in |
| Fuse | Remove the blown fuse; choose and fit the correct amp rating |
| Buttons | Press the printed sequence in order |
| Light pattern | Watch and repeat the flashing numbered pads |
| Phone number | Dial seven shown digits on a keypad including zero; CLEAR resets |
| Part sorting | Drag Battery/Speaker/Keypad parts into labelled trays |
| Circuit | Rotate six traces to connect IN to OUT |
| Signal waves | Match frequency and phase using two visible traces |
| Power meter | Adjust -/+ to stay green for 2.5 server-timed seconds, then confirm |
| Broken component | Read six component markings and remove the OPEN/burnt one |
| Charger | Drag the plug with the matching port shape |
| Reassembly | Fit board, battery and cover in order |
| Debris | Drag coin, lint and paper clip into waste tray |
| Repair form | Read results and stamp PASS/FAIL; failure requires reseating the test lead, retesting, then PASS |
| Speaker | Repeat low/middle/high tone pattern; numbered cues and replay support muted/reduced-effects play |
| Customer phone | Install CIVIC WATCH, browse optional records, call contacts, answer/ignore incoming calls, or ask the team to skip installation |

Small tools, replacement bins, restock, notes and switches now use direct input. Remaining native holds are bench **0.4s**, intake/return **0.6s** and fuse box **1.2s**. Timeclock inspection, doors and emergency escape controls remain quick. These durations are for world prompts; HUD actions retain the same authoritative eligibility checks.

Only the current operator sees the puzzle controls. Incorrect answers show feedback or reset sequence progress; they never grant completion. Waiting 120 seconds closes an abandoned task. Standing, tool loss, departure and hazards cancel it. After solving a repair, a 1.2-second fitting animation places the component; all other puzzles advance directly on valid inputs. Prompt holds begin the action; they never solve the mini-game. Secure no longer accepts contact-click completion. Cancelled reassembly restarts that stage when another operator begins it.

Task surfaces are pooled and contextual. Drag previews move locally; only the released source/destination pair is sent to the server. Tap an item and then its destination as an alternative. Number/letter markings accompany colors. Input uses Roblox [GUI input events](https://create.roblox.com/docs/reference/engine/classes/GuiObject#InputBegan) and [InputObject](https://create.roblox.com/docs/reference/engine/classes/InputObject) positions; relative pointer deltas preserve the GUI inset. Multiple touches cannot release another finger's drag. Task changes, pauses, focus loss, menus, hazards, resize and destruction cancel held input.

Speaker cues use the installed Roblox `rbxasset://sounds/volume_slider.ogg` at three pitches; listening still needs Studio/device verification. Memory and speaker demonstrations use a server timestamp with a 0.8-second preparation lead. Answers before its end are rejected; replay resets progress and starts a new demonstration, while the overall 120-second task timeout remains. The existing client update advances cues; reduced flashes uses text-only pad indicators. Circuit solution angles and unmeasured probe readings stay server-side. These rules and simulated controls are locally tested; Studio is still required for real mouse/touch/gamepad feel, readability, camera framing and multiplayer latency.

Search the shop for a discarded timecard, unmarked tape, and small brass key. The key opens a locked archive drawer. Each record unlocks personal evidence through the existing profile API; rereading grants nothing extra. Finding all three records in the current run makes **The Night Archivist** available at survival, below answered-call and high-suspicion outcomes in priority. Objects and their owned text/geometry are temporary modeller-replaceable content.

New server modules: **WorkPuzzles**, **ShopSecrets**. New client modules: **PuzzleView**, **StationInteraction**. Sync the updated **Core/Network** too: PuzzleInput uses six scalar fields: `RunId, Action, OrderId, WorkId, Move, PuzzleRevision`. Restocking has no OrderId. Puzzle revisions reject delayed clicks; the operator and physical station/tool/seat remain server-checked.

1. **Arrival and directive:** spawn outside the shop, open the STAFF DOOR, enter, and use the TIMECLOCK. Clock-in requires being inside, within five studs. Every active staff member clocks in and acknowledges the rules before the first customer arrives. Training has no customer timeout or scripted scares; the clock waits for the first completed repair.
2. **Repair:** accept at INTAKE, sit at REPAIR BENCH, and diagnose the phone. Stand up, walk through the STOCKROOM doorway, and take the indicated Battery, Speaker, or Keypad from its shelf. Collection equips a physical Tool. Bring it back and **PLACE REPLACEMENT**, then sit to fit it. The component tweens from the tray into its exact phone slot. Reassemble and tighten all four screws, install the government package, and test. Stand and return the phone at INTAKE. E, touch prompts, and nearby HUD actions all use the same server checks.
3. **Night:** the first training return starts a six-minute clock from midnight to 6 AM. Later nights start after briefing. Job-specific patience never falls below 120 seconds; tickets show the device, complaint, service profile, diagnosed part and quoted fee. Training pays $45. Missed orders raise suspicion. The supply crate replenishes the currently needed part.
4. **Evidence:** five chapter customers contain linked Ward 7, Station Nine, transport, monitoring-room and Ministry archive clues. Report/Hide/Investigate needs a strict majority of living staff or resolves after 18 seconds. Timeout ties prefer Report, then Hide, then Investigate; no votes means Report. Investigation unlocks that customer's server-issued clue. Future clues stay server-side until discovered.
5. **Disturbances:** restore a blackout, silence the disconnected phone, present records to an inspector, and shelter from a visitor. Hazards stop new arrivals, suspend approaching customers, stand seated staff, and cancel unfinished work. Existing customer patience and team-vote deadlines pause; the night clock continues. Service reopens after a six-second quiet period. Warnings have response deadlines. Ignoring disturbances causes damage; the final visitor is fatal outside the marked storage shelter. Answering the phone is an explicitly labeled dangerous alternative.
6. **Results:** living staff survive at dawn; all staff dying ends the night immediately. Dead players cannot work after respawning and watch a living teammate until results. The summary shows team repairs, missed customers, earnings, personal repairs, team status, decisions, and save status.
7. **Continue/new run/return:** continuing requires every remaining survivor to ready on results; a new run requires all remaining staff. A fresh RunId prevents stale actions/outcomes crossing nights. Lobby return requires visible confirmation and a recorded result; existing save/freeze/teleport code handles transfer. Studio runs its print-only return preview.

Published admission requires the reserved-server ticket. Interrupted runs do not fabricate outcomes. Studio players arriving after a night starts spectate until a new run. The latest owner request sets the supported capacity to 1-4.

## Modules

| File | Responsibility |
| --- | --- |
| `GServer/Session/GameConfig` | Night length, customers, directive, hazards, interaction distances, work durations |
| `GServer/Customers/CustomerCatalog` | 270 server-only identities, 12 devices, 12 service profiles, chapter-filtered clues and shuffled decks |
| `GServer/Session/ModeRules` | Three-night Story chapters, Endless continuation, introductions, directives and capped pressure |
| `GServer/World/WorldLayout` | Connected room shells, asset-labelled furnishings and station room bounds |
| `GClient/Interface/DialogueController` | Expiring typed dialogue, speaker labels, pagination and reduced-motion display |
| `GServer/Repair/WorkshopService` | Physical repair/testing Seat, authentic carried Tools, component cloning and cleanup |
| `GServer/Session/ShiftService` | Authoritative tutorial, orders, stock, work, votes, damage, results, replay |
| `GServer/Story/EndingRules` | Eight deterministic epilogues resolved only for earned personal outcomes |
| `GServer/World/WorldService` | Temporary shop, customers, inspector/visitor, lights, prompts, spawning |
| `GServer/Session/GameService` | Admission/profile integration, save requests, snapshots, world adapter |
| `GServer/Repair/RepairTemplates` | Reusable fallback phone template, authored model cloning, owned-template cleanup |
| `GClient/Session/SessionController` | Remotes, bounded HUD updates, spectating, request ownership, cleanup |
| `GClient/Repair/PhysicalRepairView`, `PhysicalRepairTasks` | Local 3D task geometry, pointer-plane dragging, gesture validation, fallback and cleanup |
| `GClient/Repair/RepairPresentation` | Repair camera transitions, component/objective highlight, progress, input and camera restoration |
| `GClient/Repair/RepairAssembly` | Local replacement-part fitting tweens and visibility restoration |
| `GServer/Repair/RepairTasks` | Authoritative probe, pairing, circuit, dial and timed memory rules |
| `GServer/Repair/BenchTasks` | Sixteen additional task rules, screw turns, meter dwell and form retesting |
| `GClient/Repair/BenchTaskView` | Pooled extra controls, screw faces, wave traces, meter and local speaker tones |
| `GClient/Repair/RepairTaskView` | Pooled task layouts, drag/tap inputs, wire connections, rotary indicators and memory cues |
| `GClient/Effects/HorrorController` | Pooled scare face, text cue, optional audio, age filtering and cleanup |
| `GClient/Interface/HUDController` | Terminal HUD, directive, tickets, team vote, warnings, results, controls |

Prompts and HUD actions both require server distance, alive/data-ready state, current order, and valid phase. One work reservation per bench prevents duplicate repairs while allowing independent jobs. Bench work also requires the server's real Seat occupancy and Humanoid seated state. Standing, moving away, disconnecting, or a disturbance cancels unfinished work. Shelf/crate interactions require being inside the parts room and within five studs; bench interactions allow six studs and require the correct room.

Collection reserves one stock and issues one authentic, non-droppable Tool. Server-owned identity links it to its player/run/order; copied Tool attributes do not grant authority. Deposit transfers it to the bench, where any seated teammate can fit it. Cancellation preserves a deposited component. Death/disconnect/lost tools return unused carried stock exactly once. Expiry/results/replay remove owned tools and return unfitted parts. A successful fit consumes the reserved part once; a completed return pays once.

**Co-op:** a repairer can remain seated after diagnosis while another player collects and deposits the replacement. The carrier's name and delivery state appear in snapshots/HUD. Solo players follow the same loop using the stand control. There is two independent repair/testing chairs and order/work reservations; teammates select the same bench for handoffs.

The catalog contains 270 records, 204 ordinary. Story decks limit evidence to their chapter; ordinary identities provide most jobs. Device labels and coats vary, but use the same temporary phone/customer geometry. This is authored prototype content, not a complete branching campaign.

## Networking and persistence

Existing `DontPickUpGameNet.Request` accepts:

- `GetPrototype`: personal snapshot; unadmitted callers receive only a loading message.
- `PrototypeAction`: `{ RunId, Action, OrderId? }`. Workshop actions include `Sit`, `Stand`, `Collect`, and `DepositPart`. `Collect` may include `Part`; it must match the diagnosed fault and actual shelf. Voting uses `{ RunId, Action = "Vote", OrderId, Choice }`. Event responses use `{ RunId, Action, EventId }`.
- Existing `ReturnLobby` after results, plus existing `SetSetting` and session `GetState`.

`StateChanged` sends `Kind = "Prototype"` snapshots when the run revision changes, coalesced by the quarter-second server tick, plus a five-second refresh and immediate action responses. Idle ticks do not generate revisions. Clients reject older revisions. Personal `Seated`, `SeatVisit`, and `CarriedPart`, plus order `PartDelivered`, `PartCarrier`, `Paused`, and `PatienceRemaining` describe the workshop flow. Work snapshots expose owner UserId, Station, StartedAt, and EndsAt. Hidden future orders and sensitive-device flags remain server-side. World prompts derive actions from server state. Common rate and scalar-payload limits remain intact.

## Repair presentation and templates

Sync **all of GServer and GClient**, including `CustomerCatalog`, `Workshop`, `RepairTemplates`, `RepairPresentation`, `EndingRules`, `RepairAssembly`, and `ScarePresentation`. No asset uploads or animation IDs are required.

- Sitting eases the camera above the phone over 0.32 seconds (nearly vertical view, 45-degree landscape FOV, limited extra distance and wider FOV for portrait screens to stay below the roof) and keeps it there between steps. Standing normally eases back over 0.24 seconds; urgent exits restore immediately. Bench work requires remaining seated.
- **Q, gamepad B, jump, or STAND UP** leaves the chair and cancels unfinished bench work. Movement, real Humanoid death, character/camera replacement, opening the Roblox menu, a shop disturbance, rules/voting/results UI, or teardown also releases the camera. A dismissed seat visit does not recapture the camera. Existing Scriptable cameras are not taken over. Reduced motion leaves the ordinary camera available with the seated repair UI.
- One reusable AlwaysOnTop Highlight marks the objective through walls. At the bench it marks the diagnosed Battery, Speaker, or Keypad in amber until fitted, and Screen for diagnosis/software/testing. Standing players see the required shelf highlighted. Missing component names fall back to the phone model. Hazards redirect it to their response station.
- Sitting hides the side cards and displays a repair panel with the fault/next step, progress bar, and stand control. Between work steps the panel remains visible without a looping tween. The bar follows the authoritative deadline, not a client-issued completion or reward. Repeated snapshots do not restart it. Evidence modals close during hazards so emergency controls remain usable.
- Roblox `GuiService.ReducedMotionEnabled` and the existing `PlayerData.Settings.ReducedFlashes` setting suppress camera motion while retaining progress and highlights. There is no shake, strobe, blur, or permanent render callback. Camera/FOV/subject/focus are restored on release; pending tween callbacks are disconnected and ownership-checked. See Roblox's [camera API](https://create.roblox.com/docs/reference/engine/classes/Camera) and [reduced motion setting](https://create.roblox.com/docs/reference/engine/classes/GuiService#ReducedMotionEnabled).

Keep the authored source template here (no fallback is generated):

```text
ReplicatedStorage
  Assets
    RepairPhonePrototype (Model; pivot at bottom center)
      Body (BasePart)
      Screen (BasePart)
      Battery (BasePart)
      Speaker (BasePart)
      Keypad (BasePart)
      Contact1 (BasePart)
      Contact2 (BasePart)
      Contact3 (BasePart)
      Contact4 (BasePart)
    ScareSound (optional Sound; use an audio asset owned/permitted by your experience)
```

The server reuses the saved world phones and reads visible component transparency from this source template. Keep the component names and bottom-center pivot. Authored templates and placed phones are never deleted by teardown.

`Workspace.Prototype.DPU_Prototype.Bench.RepairCamera` and `.RepairFocus` are Attachments defining the close-up view and focal point. Adjust them to fit a replacement phone. Retain both saved attachments. Fitting clones only the diagnosed component locally, hides the original and tray, lifts the clone into alignment, then lowers it to the authored component CFrame. Late snapshots enter the remaining tween stage. Cancellation, hazards, death, reduced motion, results, and cleanup restore the captured visibility. The next Contact1/2/3/4 is highlighted while securing; absent targets fall back to the model. This uses [local-only part transparency](https://create.roblox.com/docs/reference/engine/classes/BasePart#LocalTransparencyModifier). Screws turn in the puzzle UI; authored hand rigs remain future work.

## Optional activities, scares, and endings

## Randomized night and scare debugging

Production uses `GServer/Horror/EventDirector`. Tutorial is safe, then the first **90 seconds after midnight** contain no director events or jumpscares (including the radio). The first interruption occurs after another 0-15 seconds and is harmless. Existing fixed timestamps apply only when `GameConfig.Director.Enabled = false`.

- Randomized types: **Knocks**, **Shadow**, **DeadAir**, **Blackout**, **Call**, **Inspection**, **Visitor**. Minor event expiry itself never deals damage; a separately announced later attack scare can injure its chosen target. Knocks play at the staff door; dead air plays at the radio; shadows appear outside the window.
- Decisions choose weighted events, duration, and a 28-52 second next interval. Active events/recovery postpone the next decision; quiet rolls can skip one. No consecutive identical event; each kind has an 85-second cooldown. Visitors cannot occur before 180 seconds. Higher suspicion increases inspection weight.
- At most five director events and two planned personal scares per night. After the first event, a decision has a 45% scare chance while that budget remains. Damage and player-triggered radio scares separately retain their 20-second personal cooldown. Completing a counteraction can cancel a scheduled hit.
- Pending targets/timing stay server-side. Debug output appears before the hit; the client only receives the dispatched cue with a 0.25-second lead. Replay/results clear pending work, and unavailable/cooling targets are skipped. The random stream is private; no random rolls run every frame.
- Non-training phones now receive randomized puzzle seeds; the first training phone remains predictable for learning.

### Attack consequences and outside exposure

- A scheduled/radio jumpscare now queues one **25 HP** server hit at dispatch +0.6 seconds; its visual cue starts at +0.25 seconds. The victim stands up and their own work/focus closes. Unrelated teammate work continues. The hit records an eight-second injury notice, updates Humanoid health, and uses normal death, carried-part recovery, spectator and ending settlement if HP reaches zero. Existing hazard damage remains its own single hit; its accompanying scare does not apply extra damage. Shelter protects staff from visitor attack cues during the shelter event.
- Damage is independent of client rendering, menu visibility or reduced-motion settings. Duplicate ticks/health callbacks cannot repeat an impact. Departures, results and new nights discard unprocessed hits. A new scare cannot dispatch too close to dawn to resolve its hit. There is no client damage/completion remote. Death results include the actual cause.
- `GServer/Horror/OutdoorRisk` runs per player through the existing server tick, checking world position at most once a second. `PrototypeWorld:Outside` checks the avatar against the shop's local bounds (including roof height) with a one-stud doorway tolerance; translated/rotated shop origins work. Missing/dead characters and spectators cannot accumulate exposure. No client claims determine whether someone is outside.
- After the calm opening and first director interruption, outside exposure has **12 seconds of grace**, then a roll every **8 seconds**. Chance starts at **12%**, adds **0.8 percentage points per exposed second after grace**, and caps at **65%**. Future rolls/chances stay private. No random rolls happen every frame, during grace or while another event blocks arming.
- A successful roll starts a visible **seven-second escape countdown** and points to the staff door. Entering the shop before the sampled deadline cancels the threat. Staying outside commits an attack for **35 HP** before night second 180 or **100 HP** afterward. Escapes/attacks have a **30-second personal cooldown**. Indoor teammates are unaffected. Active outdoor countdowns postpone new shared disturbances; they do not pause another staff member's normal repair or earn rewards.
- Tuning lives in `GameConfig.ScareDamage`, `ScareImpactDelay`, and `OutsideRisk`. Keep the tutorial/calm gates and reaction window. Debug output now also includes outdoor COMING/CANCELLED and one HIT line with remaining HP. Ordinary knocks/shadows and the first false alarm remain atmospheric warnings without a damage jump effect.

`GameConfig.DebugScares = true` logs in Studio. `DebugScaresInLive = false` keeps published diagnostics off. Expected Output:

```text
[DPU][Scare] COMING kind=Signal player=PlayerName in=2.75s
[DPU][Scare] DISPATCHED: scheduled scare
[DPU][Scare] CANCELLED: disturbance ended before the scare
```

Scares use a pooled hooded face with teeth, one 0.14-second viewport-camera lunge, three framing/pitch variants, and an 0.8-second fade. The player's world camera stays with its current controller. The default sting uses `rbxasset://sounds/impact_explosion_03.mp3`; local Roblox installations were checked for this content file. Default anomaly sounds also use installed Roblox content. Audio still needs listening checks in Studio and on devices. No uploaded sound is required.

Performance checks cover zero idle assembly scene lookups, zero extra calm-period random rolls, and reuse of prompt bindings across twenty puzzle/profile revisions. The director, audio beats and expiry reuse existing bounded ticks; no new permanent render loop or per-frame network messages. These checks do not measure real frame time.

- Open/close the staff door. After clock-in, tune three radio channels and switch the bench light, including between customers or during disturbances. Records on the counter activate for inspections. Restocking between customers fills the lowest shelf, two units at a time, up to eight. Activities do not grant repairs, money, or evidence unlocks.
- Night damage can trigger a brief personal scare. The dead-air radio channel can trigger once per staff member per night. A shared 20-second personal cooldown prevents stacking; training is safe. Scares reuse the saved low-poly face in a [ViewportFrame](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame), never the world camera. Old snapshots are discarded and repeated IDs do not replay. The normal effect lasts 0.8 seconds; reduced motion/flashes shows silent text for 1.5 seconds. Menus clear it.
- Add `ReplicatedStorage.Assets.ScareSound` before Play to replace the default impact audio. The local clone uses at most 0.6 volume multiplied by MasterVolume and is destroyed when the cue ends; the authored Sound is preserved. Default impact/anomaly Sounds are reused and stopped between cues.
- Eight Story conclusions appear above the result stats. Priority is **Missing Employee** for death; for survivors at the end of night five, **The Line Is Still Open** if anyone answered, **Under Observation** at suspicion 50+, **The Night Archivist** after all three personal keepsakes, **After-hours Witness** after Investigate, **Civilian Protector** after Hide, **Loyal Employee** after Report, otherwise **Another Morning**. Decisions and discoveries accumulate across the short arc.
- Ending IDs use `RecordOutcome` and `Progress.Endings`; no schema change or reward remote. Dead teammates retain their personal death ending. Endless and interrupted survivors receive no Story ending. Next-night readiness preserves the run; NEW RUN clears it.

`Secure` starts an owned puzzle using `{ RunId, OrderId, Action = "Secure" }`. Reassembly and screw turns use the current WorkId and PuzzleRevision; obsolete Contact fields never advance progress. Distance, seating, screwdriver ownership, current step, expiry and cooldown remain server-checked. ClockIn is idempotent. Optional actions use their station and a shared per-action cooldown (radio three seconds, other activities one second).

## Performance changes and validation limits

- Gameplay validation stays on the quarter-second server tick. Scene/prompt bindings rebuild only when a revision changes; occupied stations disable their work prompt. Lighting advances once per game minute.
- Night time is derived locally from NightStartedAt/NightDuration and freezes at TimeFrozenAt. Network packets are not needed to advance the clock or work bar.
- The controller refreshes timed HUD text at most once per second between state updates, skips untimed idle refreshes, and only reapplies responsive layout when its viewport category changes. Highlights are reused and properties are written only when changed.
- TweenService interpolates camera/progress effects. One small RenderStepped callback exists only during a close-up/return to update camera focus and check local cancellation. There are no per-frame remotes, scene scans, or model clones.
- The deterministic ten-second idle fixture sends **2 refresh snapshots instead of the previous 20**. This measures scheduling, not real network bytes, FPS, server capacity, or latency. Studio and published multiplayer profiling are still needed before making lag claims.

The profile schema is unchanged. `RecordOutcome` records contributed repairs and survival/death once per player per earned night, using a fresh identifier and the night number. Dead spectators are not awarded further outcomes. Tutorial and evidence use existing APIs. Delayed recording retries; continuation and return wait until the result enters the profile. Save status is visible, failed saves retry, and transfers save again. Playtime stays owned by DataService.

Revenue, stock, suspicion, orders, and team decisions are **run-local**. This does not add persistent money or resumable campaigns. StudioSaving false uses session-only practice storage; published play uses the configured profile store. Interrupted survivors receive no invented death/survival outcome.

## Limits and checks

This is a saved-scene prototype with a short five-night Story and continuing Endless nights. The larger authored campaign, additional repair hardware and persistent shared checkpoints remain future work. Characters, props, repairs and clues are temporary. The world adapter now binds the copied Studio assets.

Run all 24 suites using `tests/Run.ps1`, as documented in README. The prototype suite includes 24 seeds per new task, stale-input rejection, task-chain completion, UI bindings, meter timing, prompt durations, and 1-4-player handoffs. `tests/Prototype.luau` covers complete survival, death/shelter, training, work cancellation, duplicate rewards/parts, voting, outcomes, interruption, replay, and authored world/UI bindings. Adapter tests use mocked services/instances and real vector math; they do not render Roblox.

Still test in Studio: scare-to-damage timing, outdoor escape near doorway boundaries, lethal outcome and reduced-motion/menu behavior with 1-4 clients, overhead portrait/landscape framing, local avatar/accessory restoration, 3D drag alignment and button fallback, screw/scrub gestures, physical-to-fitting visibility handoff, room routes and doorway clearance with real avatars, subtitle pagination/overlap, shared repair/testing-seat handoffs and camera restoration, audible speaker pitches, mobile drag targets, wave/meter readability, native prompt holds, four-screw closure, spawn/directive, doorway access and shelf reach, Tool grip/equipping, actual Seat occupancy, full solo repair, two-client part delivery, restocking, NPC movement, paused approaches, shelter geometry, lighting/clock, death/respawn/spectating, replay, mobile landscape text, and Output. Test every component highlight; Q/B/touch/jump exit; movement, menu, death and hazard cancellation; camera replacement; reduced motion; and back-to-back repairs. Use MicroProfiler and network statistics with multiple clients and a lower-end mobile device. Verify real saves and Lobby return separately in published clients. Physical behavior follows Roblox's [Seat API](https://create.roblox.com/docs/reference/engine/classes/Seat) and [Tool API](https://create.roblox.com/docs/reference/engine/classes/Tool).
