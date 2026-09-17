# Authored briefing, clock-in and shift result panels

The enabled Prototype runtime now uses these existing Game UI objects. Keep the spelling/casing, including `TonightsRules` without an apostrophe:

```text
StarterGui.HUD
  Frames
    Briefing                     GuiObject (ImageLabel is supported)
      Understood                 ImageButton or TextButton
      Section1                   TextLabel (keep authored TextScaled)
      Title                      TextLabel
    ClockIn                      GuiObject (ImageLabel is supported)
      Back                       ImageButton or TextButton
      Start                      ImageButton or TextButton
      Mugshot                    ImageLabel
      Night                      TextLabel
      EmployeeName               TextLabel
      EmployeeNumber             TextLabel
    TonightsRules                 GuiObject (ImageLabel is supported)
      Understood                 ImageButton or TextButton
      Section1                   TextLabel
      Section2                   TextLabel
      Section3                   TextLabel
    ShiftComplete                GuiObject
      Lobby                      ImageButton or TextButton
      NextNight                  ImageButton or TextButton (optional child Label)
      AnomaliesSpotted            TextLabel (shows reported evidence count)
      PhonesFixed                TextLabel
      TimeWorked                 TextLabel
      Nights                     optional TextLabel
    GameLost                     GuiObject
      Lobby                      ImageButton or TextButton
      Retry                      ImageButton or TextButton
      Mugshot                    ImageLabel
      Nights                     TextLabel
      PhonesFixed                TextLabel
      TimeWorked                 TextLabel
```

Keep authored Titles, Tint, aspect constraints, artwork and decorations. The original panel Size and Position are the open targets. Entry eases from 88% size and 0.1 screen-height lower over 0.35 seconds; exit shrinks/downward over 0.22 seconds. Reduced motion applies immediately. Text styling, sizing and scaling are untouched. HUD stays enabled across respawns. Settings shares Frames and is not hidden by panel cleanup.

Briefing displays the existing short Story/Endless introduction before clock-in. Only Understood is wired; Section1 contains all briefing information, with RichText enabled and muted green instructions, amber time targets and red government references. The current introductions contain 25-55 words, checked for every Story chapter and Endless night, to keep TextScaled usable. Server copy is escaped before adding color tags. Authored font, scaling, sizes, position and decorations stay unchanged. Understood acknowledges locally for the current run, eases the card down and never skips server clock-in or rule acknowledgement. Repeated snapshots do not reopen it. When DPU_PrototypeHUD.Briefing is absent, this card also supplies vote instructions and successful results. Understood closes the vote notice so the authored world vote parts can be used, or readies up after a successful shift. The harmful-call warning closes without answering; clicking the receiver again within ten seconds confirms. No extra buttons are created.

Inspecting the physical Timeclock opens ClockIn with the same entry/exit animation as the other cards. Start submits the current server FocusId to ClockIn; Back, Q or controller B close the inspection without stamping. Pending requests cannot double-submit. Walking away, death, menu interruptions and expired focus release the card. The legacy DPU_PrototypeHUD.Timecard is hidden when the new card is available and remains a fallback for places without it. Keep Department, both Title labels, button Label children and other decoration as authored.

EmployeeName is the local player's account username (Player.Name), not DisplayName. EmployeeNumber displays the server-published DPU_EmployeeNumber attribute; until it arrives, the card shows ---- and Start is disabled. Night uses the current server shift number. Mugshot uses the same grayscale headshot path and access fallback described below.

Employee identity is an integer from 1000 to 9999, assigned randomly by the server on first successful profile acquisition, normally in Lobby. The assignment is committed in the same UpdateAsync as the save lease, before Ready is published, so a crash or ambiguous storage response cannot reroll a committed number. Schema 4 migrates schema 1/2/3 profiles without losing progress, settings or receipts. Game direct-entry uses the same path, and both places read the existing profile namespace. Numbers are persistent per player, not globally unique. No client endpoint sets identity. Studio with StudioSaving=false remains memory-only: restarting Play creates a new practice profile; published persistence or the isolated StudioSaving namespace must be used to check rejoining.

Successful server ClockIn opens tonight's rules; Understood sends the existing ReadRules acknowledgement. The three lines contain the repair task, the current server-owned government directive and the ringing-phone warning. The warning follows the current gameplay, which makes answering dangerous during the shift as well as after closing. The existing rules shortcut reopens this card. Required acknowledgement cannot be bypassed by closing a local UI.

Personal death opens GameLost immediately, including while teammates are alive. Frames.BackgroundTransparency eases to 0.2, then restores its authored value after restarting. GameLost.Nights now contains only the numeric value; its other existing stat fields retain their previous formatting. Nights counts completed nights; PhonesFixed counts completed phones this player contributed to across the run; TimeWorked is real clocked-in time in minutes:seconds, excluding time on the results screen. These totals freeze server-side at death.

Successful server results show ShiftComplete instead of the generic Briefing/results view. AnomaliesSpotted is the number of unique customer evidence reports resolved as Report by the team this night; individual votes, software-install decisions and repeated callbacks do not increase it. PhonesFixed is the team's completed-phone count for the night. TimeWorked is the local employee's clocked-in time for this night, including preparation and closing but excluding earlier nights and time on results. The server freezes all employee summaries before settlement publishes snapshots. The three value fields show only numbers or mm:ss, leaving the separate Label objects untouched. Optional ShiftComplete.Nights shows completed nights as a bare value.

NextNight sends the existing Replay ready vote; it waits for the other required employees in multiplayer. Its optional Label displays NEXT NIGHT, NEW RUN, WAITING FOR TEAM or PLEASE WAIT. Lobby uses the validated ReturnLobby path. Both actions remain disabled until server settlement/readiness permits them. The card uses the same entry/exit tween and 0.2 background dimming as GameLost. Clock.Night, ClockIn.Night and GameLost.Nights also display bare values such as 1, with no NIGHT prefix or zero-padding.

Solo Retry starts a new run through the existing Replay action after outcome settlement. Multiplayer retains the existing end-of-run ready vote; Retry is inactive while living teammates continue. It does not interrupt their work. Lobby uses the existing validated ReturnLobby/TravelService path to place 110554757455252 after outcome settlement, even when teammates remain alive. TravelService still handles profile saving and teleport failures. Studio returns a preview response instead of a real teleport. Pending requests disable repeated button input.

Mugshot loads the local player's Roblox headshot and converts its pixels to grayscale once using EditableImage. It never applies a grayscale effect to the world or other UI. Enable **Allow Mesh / Image APIs** in the experience's security settings for published use, subject to Roblox's access requirements. If image editing is unavailable or its memory budget is exhausted, the regular headshot remains visible and Output explains the fallback. `Mugshot.DPU_GrayscaleReady` indicates whether conversion succeeded. Owned editable image memory is released on teardown. See [Roblox EditableImage documentation](https://create.roblox.com/docs/reference/engine/classes/EditableImage).

Keep DPU_PrototypeHUD: it still supplies repair controls, objectives, warning text and other unmigrated screens. Its old Briefing, TeamSignals, Clock, Scare and Timecard are optional after the corresponding HUD cards are present. Missing new cards fall back independently to the legacy UI; no replacement UI is generated. These cards are connected to the enabled Prototype shift lifecycle, not the alternate authored interaction demo.

## Verification

`tests/Validate.luau` covers identity assignment, all historical schema migrations, Lobby/Game acquisition and lost storage replies; `tests/Concurrency.luau` checks that published identity matches the committed record. `tests/HUDPanels.luau` covers the new card with the real station controller, missing identity, username selection, Back/Start, duplicate suppression, stale focus, cleanup, and real shift actions, cumulative/frozen server stats, solo/team restart gates, settlement before Lobby return, authored frame transitions, cancellation, input ownership, duplicate-button suppression, grayscale RGBA conversion, asynchronous teardown and API failure fallback. `tests/Run.ps1` includes it with the existing suites.

Still verify in Studio: the exact saved HUD hierarchy and draw order; mouse, touch and gamepad buttons; clock-in and Understood; death with a teammate still working; solo retry; repeated nights; reduced motion; correct mugshot and grayscale API access. Published testing is required for live profile saves and the actual Lobby teleport. No authored Workspace parts need deleting for this change.

HUD.Objective is preferred over DPU_PrototypeHUD.Objective. Its Frame wrapper can contain the objective TextLabel (Text is preferred; a differently named TextLabel is supported). Use is optional. Hidden wrapper ancestors are revealed; authored TextScaled, size, position and styling remain unchanged. Existing world interaction controls continue to work without a Use button.
