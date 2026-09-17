# Authored settings in Game and Lobby

The existing Game and Lobby entrypoints start `Settings/SettingsController`. No new LocalScript or opening button is added. It finds a complete GuiObject named `Settings` beneath PlayerGui, including when its screen arrives late or is replaced after respawn. Put the same authored hierarchy in each place:

```text
Settings                         Frame/ImageLabel; authored position, size and visibility
  Frame
    Music / Toggle               TextButton or ImageButton
      Ball                       GuiObject
      Title                      TextLabel
      UIStroke
    SFX / Toggle                 same children
    CameraShake / Toggle         same children
  Close                          ImageButton or TextButton
```

Music/SFX/CameraShake are sibling rows under Frame; the shorthand above does not imply additional required folders. All decorative labels, images, layout constraints and styling remain authored.

## Toggle and close behavior

ON uses Ball position `(0.8, 0, 0.5, 0)`, left-aligned `ON`, background/image tint `(85,171,84)` and stroke `(121,255,114)`. OFF uses `(0.2, 0, 0.5, 0)`, right-aligned `OFF`, grey `(85,85,85)` and stroke `(121,121,121)`. Position and colors tween for 0.18 seconds; obsolete tweens cancel on another click. Mouse, touch and controller use the same Activated event.

Close follows Kingdom Wars' 0.44-second Back/In movement to 18 pixels below the current position. It then hides the frame and restores its position while hidden. It does not resize or scale your frame. Roblox reduced motion makes these transitions immediate. Your opening code can set `Settings.Visible = true` again; this system does not create, show or animate an opening button. Parent visibility/ScreenGui.Enabled is respected.

The visible frame sets the local `PlayerGui.DPU_SettingsOpen` flag, releasing the Game pointer and blocking world/puzzle input through existing controllers. Close keeps that block through its animation. Teardown cancels tweens, disconnects listeners and restores owned property changes. Rapid writes are serialized and coalesced; rejected requests revert the displayed switch to its confirmed value. Toggles stay inactive until profile loading finishes. `PlayerGui.DPU_SettingsError` exposes the last request error for future UI feedback without adding a new panel.

## Actual effects and saving

- Music and SFX independently mute existing and newly added Sound instances under SoundService, Workspace and PlayerGui. Playback is not stopped or restarted. Their original/latest authored volume is restored when enabled.
- Mark music using a `Music` SoundGroup, a Music/BGM/Soundtrack sound or ancestor name, or an `AudioCategory = "Music"` attribute on the sound/ancestor. Other sounds are SFX; an explicit sound `AudioCategory = "SFX"` overrides inherited music classification. Use the sound's attribute to change its category at runtime. No sounds or music tracks are generated.
- CameraShake disables the existing scare viewport camera lunge/rotation/FOV motion while keeping the static image, captions and sound. Ordinary inspection/camera transitions remain available. Lobby has no existing shake effect; it saves the same preference for Game. Future shake effects can consume the local `Player.DPU_CameraShake` attribute.

The existing server `SetSetting` endpoint validates boolean `MusicEnabled`, `SFXEnabled`, and `CameraShake` values. Profiles use schema 3; versions 1/2 migrate without losing progression, credits, other settings or outcome receipts. A previously zero MusicVolume initializes MusicEnabled to false. Existing DataStore names, save locks, autosaving and Studio practice behavior are preserved. Practice-mode changes stay in that server session as before; live persistence still needs published-place verification. Deploy the updated server Core to both places together.

These client-only modules live in `common/CommonClient/Interface`, mapped into `GClient/Interface` and `LClient/Interface`. Run `tools/SyncCommon.ps1` after editing the common source. `tests/Run.ps1` checks deployment parity, profile migration, effects, input, teardown, interrupted closing and late GUI replacement.

Studio verification: place the authored frame in both places, expose it with your own opening code, click/tap each toggle, close/reopen, respawn, and confirm real music classification, SFX muting and camera behavior. No live hierarchy, imported music or published DataStore has been inspected by the local tests.
