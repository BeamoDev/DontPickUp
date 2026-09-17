# Authored rules and game loss panels

The enabled Prototype runtime now uses these existing Game UI objects. Keep the spelling/casing, including `TonightsRules` without an apostrophe:

```text
StarterGui.HUD
  Frames
    TonightsRules                 GuiObject (ImageLabel is supported)
      Understood                 ImageButton or TextButton
      Section1                   TextLabel
      Section2                   TextLabel
      Section3                   TextLabel
    GameLost                     GuiObject
      Lobby                      ImageButton or TextButton
      Retry                      ImageButton or TextButton
      Mugshot                    ImageLabel
      Nights                     TextLabel
      PhonesFixed                TextLabel
      TimeWorked                 TextLabel
```

Keep authored Titles, Tint, aspect constraints, artwork and decorations. The original panel Size and Position are the open targets. Entry eases from 88% size and 0.1 screen-height lower over 0.35 seconds; exit shrinks/downward over 0.22 seconds. Reduced motion applies immediately. Text styling, sizing and scaling are untouched. HUD stays enabled across respawns. Settings shares Frames and is not hidden by panel cleanup.

Successful server ClockIn opens tonight's rules; Understood sends the existing ReadRules acknowledgement. The three lines contain the repair task, the current server-owned government directive and the ringing-phone warning. The warning follows the current gameplay, which makes answering dangerous during the shift as well as after closing. The existing rules shortcut reopens this card. Required acknowledgement cannot be bypassed by closing a local UI.

Personal death opens GameLost immediately, including while teammates are alive. Frames.BackgroundTransparency eases to 0.2, then restores its authored value after restarting. Stats use exactly four spaces between name and value. Nights counts completed nights; PhonesFixed counts completed phones this player contributed to across the run; TimeWorked is real clocked-in time in minutes:seconds, excluding time on the results screen. These totals freeze server-side at death.

Solo Retry starts a new run through the existing Replay action after outcome settlement. Multiplayer retains the existing end-of-run ready vote; Retry is inactive while living teammates continue. It does not interrupt their work. Lobby uses the existing validated ReturnLobby/TravelService path to place 110554757455252 after outcome settlement, even when teammates remain alive. TravelService still handles profile saving and teleport failures. Studio returns a preview response instead of a real teleport. Pending requests disable repeated button input.

Mugshot loads the local player's Roblox headshot and converts its pixels to grayscale once using EditableImage. It never applies a grayscale effect to the world or other UI. Enable **Allow Mesh / Image APIs** in the experience's security settings for published use, subject to Roblox's access requirements. If image editing is unavailable or its memory budget is exhausted, the regular headshot remains visible and Output explains the fallback. `Mugshot.DPU_GrayscaleReady` indicates whether conversion succeeded. Owned editable image memory is released on teardown. See [Roblox EditableImage documentation](https://create.roblox.com/docs/reference/engine/classes/EditableImage).

Keep DPU_PrototypeHUD: it still supplies intro, votes, successful results, repair controls and other unmigrated screens. Missing new cards fall back independently to the legacy UI; no replacement UI is generated. These cards are connected to the enabled Prototype shift lifecycle, not the alternate authored interaction demo.

## Verification

`tests/HUDPanels.luau` covers real shift actions, cumulative/frozen server stats, solo/team restart gates, settlement before Lobby return, authored frame transitions, cancellation, input ownership, duplicate-button suppression, grayscale RGBA conversion, asynchronous teardown and API failure fallback. `tests/Run.ps1` includes it with the existing suites.

Still verify in Studio: the exact saved HUD hierarchy and draw order; mouse, touch and gamepad buttons; clock-in and Understood; death with a teammate still working; solo retry; repeated nights; reduced motion; correct mugshot and grayscale API access. Published testing is required for live profile saves and the actual Lobby teleport. No authored Workspace parts need deleting for this change.
