# Ministry repair shop gameplay

The enabled Prototype runtime now uses `GameConfig.ShopDirection = true`. This builds on the restored shift, two benches, physical telephone, authored HUD, private phone pages, NPC actors, team voting, inspections and existing endings. It does not start a second gameplay stack. The retained earlier rules can be exercised with `ShopDirection = false`; the historical regression fixtures select that explicitly.

## Playable loop

Clock in, read one nightly directive and collect one reusable repair kit. Accept a customer's Phone, remove four screws with one turn each, remove the back cover and slide the battery out. Diagnose its single fault, fetch that component from Storage and deposit it at the bench. Replace the faulty component, reinstall the battery and cover, then tighten four screws. No unrelated cleaning, SIM, fuse or memory puzzle is appended to these repairs. The existing authored drag and screw controls are reused, including their button/controller fallback.

Checking the repaired phone produces a component-specific discovery: a speaker offers a saved recording, a battery powers up into an incoming call, and a keypad offers call history. Listening or searching is optional. An unmarked phone can go straight to FINISH; a required update must be installed or explicitly skipped by team decision. The final working-phone check leads to the existing six-digit pickup call and customer return.

The current component set remains Battery, Speaker and Keypad. No new screen component, photo browser, voiced audio or additional repair models are required. Physical repair gestures use meshes from Assets.Devices.Phone. Speaker/keypad components use Storage pickup art and optional authored mount attachments. Button/controller fallback keeps the same server rules.

## Government policy and records

Five short directives rotate by night: update red-marked phones; no deleted-record recovery; no private calls after curfew; update every device; report archive evidence. Only the current directive is shown. CIVIC WATCH first presents itself as a security update; its permissions page exposes microphone access and automatic reporting.

Call history, contacts, recorded-message transcripts, service history and deleted-record recovery are server-owned. Only the opened page is sent to the operator. Service history records the technician's employee identifier. Recovery takes six server-timed seconds and leaves an employee access log even if the player leaves and reopens the phone. Installation takes two server-timed seconds. Page revisions reject stale inputs.

Contacts are revealed by opening the relevant page. Their six-digit numbers start with zero, separating them from pickup tickets. Dial them on `Workspace.Prototype.DPU_Prototype.Fax`; unrevealed guesses are rejected. The same physical session validates distance, standing state, admission and lifetime. A connected call uses the existing receiver animation and shows subtitles only to the caller. No chat or microphone is recorded; anomaly transcripts use authored dialogue.

Report, Hide and Investigate need a strict majority of living teammates. Solo needs one vote. A tie or empty deadline renews the vote instead of reporting somebody automatically. Software exceptions and evidence choices remain separate decisions. Investigation opens the recovery workflow; it does not bypass its timer.

Returned required updates and clean inspections build government trust. Trust of at least two grants one extra part of each type next shift, spaces disturbances farther apart and substitutes a quiet knock for a scheduled outage. Missing required updates, hidden evidence and prohibited access leave discrepancies. Inspectors raise suspicion for those records; missing an inspection records a discrepancy rather than damaging everybody for paperwork. Existing choices/suspicion feed the retained ending resolver.

## Solo and multiplayer

Solo has at most one active order, a minimum 18-second intake gap, longer patience and paused orders during inspections. New arrivals pause during disturbances. Multiplayer supports two overlapping orders on the existing benches, independent of which player performs each activity. During an inspection, existing multiplayer repair work continues while someone handles the papers. Losing a coworker during the inspection switches to solo pacing and pauses the remaining work safely.

The director retains a quiet opening, capped to three disturbances and one scheduled scare per shift under this direction. Minor disturbances do not clear everybody's bench work. Every mechanic uses the existing shift tick, event scheduling and central client interaction controllers.

## Returning case and anomalies

Once per Story night, after an ordinary order, Mara's MW-041 case links the shifts. Her broken speaker reveals a missing worker's message. Reporting it brings Officer Vale with the same device; protecting/investigating it brings Mara back. A later clerk, courier and final copy connect transfer records to the surveillance archive. The original decision is retained so a later choice cannot silently undo the customer's disappearance. One worker hears a warning before the officer arrives; solo receives that warning with a full twelve seconds before his arrival.

Other catalog customers and humor are retained. Most ordinary jobs have no evidence. Rare anomaly variants include an authored intake line recorded with tomorrow's date, an impossible earlier service under the technician's identifier, a battery-removal whisper, and an identical customer standing outside during pickup. The duplicate uses the same authored NPC appearance and is removed when that order changes or the world shuts down.

Story choices, government trust and access logs persist across nights of the current run, not across server restarts. Existing profile progression, evidence unlocks and idempotent shift outcomes still use the unchanged persistence system. This is a playable implementation of the direction, not a completed narrative campaign with bespoke art/audio for every branch.

## Optional authoring and verification

No fixed map or UI is generated. Existing `Secret_Directive` shows tonight's directive when inspected; its existing text label is updated if present. `Secret_RepairLog` shows current service discrepancies and supply priority. An optional red `ServiceSticker` BasePart/Decal inside each saved bench phone is shown only for required updates. Without it, the intake notice, objective and phone page still clearly identify required updates. Optional custom component geometry and voice recordings can replace the existing task pieces/transcripts later.

`tests/ShopDirection.luau` exercises actual shift actions, full repair-to-pickup flow, privacy, contact calls, majority voting, separate software/evidence choices, continuing-story branches, policy rewards and solo/multiplayer inspection changes. The complete `tests/Run.ps1` includes this suite, historical compatibility suites, imports/layout/compilation and Core parity.

Studio still needs a solo shift, a two-player shift with simultaneous bench work/inspection, phone receiver and private subtitles, touch/controller dragging, optional stickers, NPC orientation/duplicate cleanup, next-night story continuity and final closing/results. Local mocks do not verify live model geometry, animation permissions, published networking, teleports or DataStores.

Current device flow: every order is a Phone from Assets.Devices.Phone. Remove four screws, cover and battery before diagnosing; collect one replacement from Storage, fit it, reinstall battery/cover/screws, then perform the existing software/test/callback steps. Server state still scopes work by bench, operator, order and revision. Future device types can extend the explicit DeviceId; none are selected yet.
