# Don't Pick Up repository instructions

These instructions apply to the entire repository. Current source and the latest owner request override historical implementation notes.

## Current architecture and workflow

- The owner restored the full prototype and then saved its generated map/UI as authored Studio assets. Bind these assets; do not regenerate the fixed map or UI. Use Workspace.Prototype.DPU_Prototype, ReplicatedStorage.Assets.Devices.Phone, ReplicatedStorage.Remotes and the saved StarterGui screens. See docs/PROTOTYPE_ASSETS.md. `GServer/Session/GameConfig.Enabled = true` is now the default. Startup selects exactly one Game mode: the authored shift runtime or the retained authored interaction/order systems. Do not run both HUD/camera/input stacks together. Preserve authored Studio assets. See `docs/PROTOTYPE_RESTORATION.md`; older retirement notes are historical.
- Read `README.md`, `docs/CURRENT_ARCHITECTURE.md`, `docs/SOURCE_CHANGES.md`, the current file tree and Git status before edits. Preserve unrelated local changes and authored Studio models/UI/media. Read the full owner context below before changing gameplay or narrative.
- Keep exact roots `GClient`, `GServer`, `GShared`, `LClient`, `LServer`, `LShared`; G is Game and L is Lobby. Every file follows `src/<Root>/<SystemName>/<Script>`. Roots contain only system folders; systems contain only scripts/modules, never subfolders. Keep docs/tools/tests outside src.
- Script Sync mappings: each place's Client root goes under StarterPlayer.StarterPlayerScripts, Server under ServerScriptService, Shared under ReplicatedStorage, retaining the root name. Game and Lobby must never run together in one place. Live Studio hierarchy still needs verification.
- Entrypoints: each place has `Client/Startup/Bootstrap.local.luau` and `Server/Startup/Bootstrap.server.luau` beneath its G/L root. Other runtime files are ModuleScripts. GameController and QueueController start explicitly. Update imports/tests and tests/SourceMoves.json when moving scripts; remove obsolete deployed scripts, never authored assets.
- Shared holds public definitions and geometry query policy actually used by client and server. Camera math/config, views and client requests belong in Client. Billboard rendering used only by the Lobby server belongs in Server. Never expose profiles, admission logic, private catalogs, generated answers, unrevealed content or authoritative gameplay in Shared. Common packages outside src are deployment source only, not additional Studio roots.
- `common/CommonServer` and `common/CommonClient` are canonical. project.sources.json maps common modules into the six existing runtime roots; tools/SyncCommon.ps1 generates these deployment copies and -Check verifies parity. Edit common sources, not generated copies. ProfileStore is the existing first-party save-lock implementation. Preserve DataStore namespace, migrations, practice saves, leases, admission safeguards and outcome idempotency. Do not claim persistence, teleports or multiplayer verification from local mocks.
- Run `tests/Run.ps1` (optionally `-Lune <executable>`). This checks imports/layout/compilation, common package parity, actual bootstrap wiring with mocks, persistence/concurrency, queues, first person, detection, containers/labels, tags/drinking, fax/TV cameras and throws. The restored Prototype, PhoneGameplay, Pickup, Improvements and Engagement suites are active again, alongside ShiftPhases and PrototypeStartup. Closing permits existing accepted orders for 60 seconds, blocks new intake and settles results once.

## Authored Game interactions (when GameConfig.Enabled is false)

- CollectionService tags are exact: `Drink`, `Fax`, `Container`, `throw`, `tv`, `PhoneRepair`. Container/Fax/tv/PhoneRepair tag whole Models; Drink/throw can tag a Model or BasePart. Nearest tagged ancestor owns the hit. Preserve tag-removal/reparent identity invalidation, server admission/alive/standing/range/visibility/revision/cooldown validation and reservations.
- `GClient/Interaction/InteractionController` owns all world and physical fax input. It delegates to TelephoneController, ThrowController and PhoneRepairController. Do not add independent object input listeners or per-object render loops. One active post-camera hover query and one pooled authored SelectionHighlight are shared. The first-person dot consumes that hover result without extra rays/remotes.
- Raw mouse/touch positions use `ViewportPointToRay`; locked mouse/controller use viewport center. UI/menu/text focus blocks selection. `GShared/Interaction/InteractionQuery` skips untagged non-collidable decoration with a 12-hit cap, but stops at collidable walls, terrain or another interactable. Within inspection it can also skip non-collidable trim belonging to that model. Intended target surfaces require CanQuery. Decorative parts should be non-collidable/query-excluded; wall occluders must be queryable and collidable. Do not make walls click-through to improve hit rates.
- Touch taps must remain within 18 pixels throughout the gesture and finish within 0.6 seconds. Dragging away then back is still a drag. A second finger cancels. Preserve captured runtime identity/revision and exactly one request per activation. Never retry a toggle/throw automatically. Throwables use click/tap to carry and a second click/tap to launch; releases alone never throw and camera dragging cancels only the tap gesture.
- All close-ups use `GClient/Camera/InspectionCamera`: tween CFrame, Focus and FOV both into the shot and back to first person. Anchor the local character root before entry, preserve its prior Anchored/AutoRotate settings, and restore them after return or immediate interruption. Relock the mouse when closing starts, respecting menus/text focus. Retain ownership/input blocking through exit, cancel obsolete tweens, follow external character displacement on return, restore local avatar transparency and native camera settings. Reduced motion switches immediately; death/respawn/replaced camera/teardown release immediately. No camera snap on ordinary close. ContainerViewConfig, TelevisionViewConfig and TelephoneConfig own client-only framing.
- Containers: first click enters a view of the full tagged Model; later clicks toggle direct BasePart/MeshPart children named Box or Box plus digits. Descendant handles and matching Label parts resolve to the Box. Move boxes 0.8 studs along the cabinet Model pivot's local negative Z from their original CFrame in 0.35 seconds; preserve anchored/queryable requirements, authored welds, rotations and paired label offsets. Independent labels tween; welded loose labels follow their Box. Never weld to the fixed cabinet. Server owns movement. See `docs/CONTAINERS.md`.
- Fax: preserve exact Key0-Key9, Key*, Key#, KeyClear/KeyClose, Dial and End mappings, plus `InputArea.SurfaceGui.Frame.TextLabel` text and visibility chain. Digits stay local. TelephoneCalls defines 67/1984/404 routes with Dialing/Connected/Ended events and future SubtitleKey hooks; unknown numbers say NOT CONNECTED. Physical KeyClose uses the same Close path as the UI, and End hangs up. ReceiverMotion animates a local copy of Phone above/out of view then back, preserving authored joints/visibility. No subtitle UI/audio, server gameplay consequence or reward is added. See `docs/TELEPHONE.md`.
- PhoneRepair: whole authored Phone model, separate from Fax. PhoneRepairService reserves one player/model and owns disassembly, wire visibility and ordered reassembly. Exit4 -> Entry1 Red; Exit3 -> Entry2 Yellow; Exit2 -> Entry3 Blue; Exit1 -> Entry4 Pink. Battery then BackCover then all four Screws, any screw order. Keep authored keys/SimTray/joints; temporarily disable internal joints and restore on completion/cancel. RepairDrag uses token-scoped bounded table coordinates; no client CFrames or completion claims. One server session heartbeat, central client input. See `docs/PHONE_REPAIR.md`.
- TV: lowercase `tv`, a level bounds-fitted view from local -Z; Q/B/STOP WATCHING and normal interruptions close. No gameplay remote or mutation to authored screen/media. Verify imported orientation in Studio.
- Drinks reserve server-side, fade authored parts/decals from their initial transparency to 1 over 0.5 seconds, and delete only after all tweens finish. No rewards. Tag removal cancels/restores pending fades.
- Throws: server token-scoped reservations, fixed server speed/arc (72 forward plus 8 upward), server-owned physics and hold cleanup. Never accept client force/speed/positions; ThrowAim accepts token-scoped finite unit direction only, at most eight changed updates per second, with separate server throttling and occlusion. Preserve second-click/cancel-before-grab-reply handling. ThrowEffects owns only a narrow white trail and temporary collision filters; preserve authored welds/effects. No damage/reward/respawn. See `docs/THROWING.md`.
- Dialogue: bind authored HUD.Subtitles (Title, Paragraph and CharacterViewPort.ViewportFrame), never replace its layout. GClient/Interface owns presentation only. Demo after ten seconds is controlled by DialogueConfig.TestEnabled. NPC uses ReplicatedStorage.Assets.npc; You/YOU/I use the local avatar, title You in pale green. Paragraph is fixed size with TextScaled=false and MaxVisibleGraphemes typing. Subtitles tweens to size (1,1) and out to (1,0); speaker changes exit then enter. Preserve ancestor visibility, cancel obsolete transitions, restore source Archivable, strip cloned scripts, and clean up owned portrait models/cameras. See docs/DIALOGUE.md.
- FirstPersonCamera owns cursor policy: faint six-pixel white dot, center lock, V/manual release, automatic release for menus/modals/text/focus and close-ups. Preserve touch/controller native input, reduced-motion pulse and teardown restoration. Local modals use PlayerGui.DPU_ModalOpen.

## Lobby and project direction

- Preserve authored Queue UI geometry, Selected markers and mode UIStroke colors. QueueView lives in LClient/Interface; QueueRequests lives in LClient/Matchmaking; LobbyWorldService/QueueGeometry/QueueBillboard live in LServer/World; both sides consume LShared/Matchmaking/QueueDefinitions.
- Preserve server-owned queue membership, immediate Enter.Touched handling with bounds fallback, stable member slots, single departure deadline, EntryId-scoped requests, capacity/readiness checks and Studio teleport preview. Only Status.TextColor3 changes on signs; do not recolor authored borders or change text sizing/wrapping.
- Lobby place ID `110554757455252`; Game place ID `111652489432168`. Verify same-experience configuration before published teleport testing. Maximum party size is 4; all required future gameplay must work solo.
- Repair/observation/communication/choice/consequence remain the design pillars. Keep younger-player tasks short and concrete. The owner-supplied context below is design direction, not a claim that retired repair/night/story implementation is currently active. Latest owner limits (1-4 players, actual authored systems) supersede older examples.

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
