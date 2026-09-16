# Repair-shop improvement plan

## Baseline inspected before implementation

The checkout already contains modified files and new repair, subtitle, layout and outdoor-risk modules. These working versions are the baseline; no checkout/reset is part of this work.

Lobby owns authored queue pads and UI, parties, profile loading, and private-server dispatch. Game admits the complete roster before starting. Each place has one bootstrap, its own remotes and a deployment copy of the server Core. LServer/Core is canonical. The shared source roots are currently empty.

GamePrototype adapts ShiftService to profiles, world geometry and networking. ShiftService currently owns a single order/work reservation, tutorial, night clock, votes, injuries, optional actions, outcomes and snapshots. Workshop validates real seats and Tool identities. RepairTasks/BenchTasks implement authoritative puzzles. Clients render those puzzles using button and physical presentations. Test fixtures exercise rules and mocked adapters; they do not render Roblox.

The loop is clock in, acknowledge rules, accept, diagnose, collect/deposit a part, repair, reassemble, install, test and return. Night one has safe training. Story continues for three nights; Endless continues until the team cannot continue. Outcomes are personal, while campaign state is server-local.

## Preserve

- Simple jobs, cooperative handoffs, solo completion, authored Lobby assets and existing minigames.
- Strict admission, leased profiles, stale-input rejection, real tool/seat checks and once-only outcomes.
- Calm opening, mostly ordinary customers, accessibility fallbacks and cleanup of local camera/effects.
- Existing Story/Endless progression and earned evidence/ending identifiers.

## Design changes

The latest owner direction takes priority: an odd, sometimes funny night job. Short customer/employee exchanges carry personality; optional readable records carry the deeper mystery. Do not require reading an archive to finish a repair. Introduce work gradually, use short objectives and retain existing task types as variety rather than stacking every mechanic on every phone.

Recurring optional records connect Mara Ellis, Nina Vale, employee 07, Ward Seven, Station Nine and the Municipal Communications Office. Found text is disclosed only after a valid inspection. Existing archive discoveries keep their save identifiers.

Small objects use click/tap interaction with controller support and visible feedback. Doors and large emergency equipment may retain prompts. Both interaction paths reach the same server validation. A dangerous call requires an explicit choice.

## Proposed source structure

Keep exact L/G environment roots and root bootstraps. Organize Game server modules into Services, Shifts, Customers, Repair, Anomalies, Lore and World; Game client modules into Controllers, UI, Repair, Interactions, Dialogue, Effects and Networking. Organize Lobby modules into Parties, Queues, UI and Networking. Keep Core as the canonical/mirrored server foundation. Do not replicate future customer content, dialogue catalogs, hidden lore or puzzle answers merely to populate Shared. Only genuinely shared definitions belong there.

## Stages and validation

1. Move existing modules, update every import/test path and improve the fixture loader for nested folders. Compile and run the existing baseline suites.
2. Add a bounded server dialogue sequence, short authored exchanges, personal lore inspection state and an accessible reader. Test secrecy, expiry, repeated discovery and interruption.
3. Replace small-object prompts with direct interaction and feedback through the existing request boundary. Test stale actions, range, player state, input paths and cleanup.
4. Isolate repair orders/work by station, preserve shared shift/vote/outcome rules and cooperative transfers. Test simultaneous work, stale cross-station inputs, loss/death and shared hazards.
5. Run complete local shifts and regression suites; update deployment instructions and a complete move/change manifest.

Actual rendered mouse/touch/gamepad behavior, teleports, live storage, audio and multiplayer performance require Studio/published checks. Report those separately from local tests.

## Implementation result

All five stages are implemented locally. The 35 moves are listed in SOURCE_CHANGES.md; CURRENT_ARCHITECTURE.md gives the required Studio folder migration. The final local run passed 10,805 assertions across six suites and compiled 82 Luau files. Static requires resolve, there is one bootstrap per server environment, and the two Core copies match. Local validation includes a complete two-worker shift and isolated bench jobs; it is not evidence of rendered Studio behavior or published services.

Remaining manual work is Studio sync and playtesting on real desktop/touch/controller input, published party travel/storage checks, and replacement of prototype art/document props with authored assets. These were not performed through a live connection.
