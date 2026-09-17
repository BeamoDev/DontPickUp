# Authored dialogue UI

Customer order handoff and return now drive conversations through the existing controller. The old ten-second automatic test conversation is disabled (`GClient/Interface/DialogueConfig.TestEnabled = false`). It can be enabled explicitly for a standalone UI preview. The saved Subtitles setting is respected; it defaults to true. See [CUSTOMER_ORDERS](CUSTOMER_ORDERS.md) for the playable bench loop.

Required authored instances:

```text
StarterGui
  HUD [ScreenGui]
    Dialogue [Frame]
      Frame
        CharacterViewPort
          ViewportFrame
      Title [TextLabel]
        Frame
          UIStroke
      Paragraph [TextLabel]

ReplicatedStorage
  Assets
    NPC [rigged Model with Humanoid or AnimationController]
```

Title, Paragraph and CharacterViewPort can be nested within Dialogue; the resolver finds their authored descendants. The `assets` spelling is accepted as a fallback for the asset folder, and lowercase `npc` is a compatibility fallback for `NPC`. No replacement HUD or character is generated. Missing UI waits for the authored instances and produces one diagnostic; it does not block other Game systems.

## Presentation

- Subtitles becomes visible and eases to `UDim2.fromScale(1, 1)`. The first entrance starts fully transparent, matching later entrances. On close it fades/collapses to `(1, 0)` and becomes invisible. Authored positions, anchors, child geometry, fonts and decorative instances are retained; the transition adds only a temporary ten-pixel exit offset.
- When the speaker changes, the old panel animates out before the new portrait/title/text are installed and the panel animates in again. Consecutive lines from the same speaker keep the panel open.
- Title and Paragraph use `MaxVisibleGraphemes` for separate typewriter reveals. Full text is assigned up front so wrapping does not shift as letters appear. Title uses TextScaled with a single line to fill its authored rectangle; assigning the full name before the typewriter reveal keeps its size stable. Paragraph also uses TextScaled, with wrapping enabled. Both labels fit their authored rectangles automatically; no runtime TextSize override is applied.
- `NPC` displays the `NPC` body with the title Customer (change this in DialogueConfig). `You`, `YOU`, and `I` all display the current local avatar and title **You** in faint green. Customer uses faint orange; You uses faint green.
- The viewport owns one WorldModel and Camera. It clones the source character, strips scripts/effects from the copy, restores visibility hidden by first person on the copy, and fits a stable camera to the body bounds with room for animation. Source characters and their original Archivable values remain intact. Avatar appearance changes refresh an active You portrait.
- Reduced motion reveals text and switches sizes immediately while preserving reading time. Finishing, replacement, disabled subtitles, HUD removal and teardown cancel obsolete work and clean up portraits/connections. HUD replacement does not replay the join demo.

Roblox's [MaxVisibleGraphemes documentation](https://create.roblox.com/docs/reference/engine/classes/TextLabel#MaxVisibleGraphemes) describes the stable-layout typewriter behavior. The portrait uses the ViewportFrame's AbsoluteSize when fitting its camera, since [viewport cameras do not report screen pixel dimensions](https://create.roblox.com/docs/reference/engine/classes/Camera#ViewportSize).

## Runtime ownership

All code is client-only under `GClient/Dialogue`:

| Module | Responsibility |
| --- | --- |
| DialogueConfig | Demo flag/timing, line text, speaker aliases, font size and reveal speeds |
| DialogueController | Authored UI binding, Play/Stop lifecycle, one active typing connection and delayed demo |
| DialogueView | Existing UI visibility, text fields and cancellable show/hide transitions |
| DialoguePortrait | Owned viewport camera/model, body framing, animation tracks and avatar refresh |

GameController creates one controller before waiting for gameplay networking, so the presentation test is independent of profile/network startup. Future client systems can receive this controller and call `Play({ { Speaker = "NPC", Text = "Hello." }, { Speaker = "You", Text = "Hi." } })`. Play replaces the current sequence. Stop closes it. Destroy releases owned instances and restores the authored UI settings.

This is presentation, not a story-state or reward system. No server remote or gameplay decision is introduced. Fax `TelephoneCallChanged` hooks remain available for later call-specific dialogue; the timed test does not invent call outcomes or automatically bind the fax routes.

## Checks

`tests/Dialogue.luau` checks the timer, nested visibility chain, automatic text scaling, title/body reveals, speaker transitions, viewport ownership, You aliases/color, avatar refresh, HUD replacement, reduced motion, cancellation and teardown with mocked Roblox services. The local fixture uses ASCII lines; Roblox supplies the runtime Unicode grapheme iterator.

Studio still needs to verify the actual NPC rig and animation assets, face textures and accessories, portrait framing, HUD layering, mobile line wrapping and transition appearance. Sync the updated GameController and all four Dialogue modules into the Game place. The existing NPC asset and HUD hierarchy must be present there.

Dialogue portraits now fit the full body with animation margins and prefer exact `ReplicatedStorage.Assets.NPC` (lowercase npc remains a fallback). AnimationController/skinned NPC models do not require a Head. Only the cloned rig root is anchored; source models remain untouched. `DialogueConfig.NPCAnimations` contains only Running, Angry, Nervous, HeadNodAgree, AngryIdle and HappyIdle. Lines optionally select `Animation = "HappyIdle"`, `"HeadNodAgree"`, `"Nervous"`, `"Running"`, etc.; the test uses HappyIdle and HeadNodAgree. You always uses the stock R6/R15 Roblox idle. Tracks stop and are destroyed on speaker changes/close. Verify asset permissions, matching rig/bones, animated framing and actual playback in Studio; local mocks cannot render animation assets.

Both viewport clones now use fixed Model pivots from `DialogueConfig.PortraitTransforms`: NPC position `(-176.935, -0.063, -51.505)`, orientation `(90, 180, 0)` degrees; You position `(-176.935, -0.063, -51.505)` (shared with NPC), orientation `(0, -90, 0)` degrees. Orientations use Roblox Orientation order (YXZ). Automatic fitting and resize-driven reframing are removed. The viewport camera now uses the exact owner-specified position `(-163.297, 6.866, -51.514)`, orientation `(-2.676, 90.098, 0)` degrees and FOV `10`. These values are configured once in DialogueConfig; speaker changes do not reset or auto-fit the camera. The previous camera reference is restored on teardown, and authored lighting is preserved. These coordinates apply only to the viewport clones, never the live player or source NPC. Existing animation playback remains.

Latest presentation: transitions fade backgrounds, text, images/viewport and strokes while sliding the whole Subtitles frame 18 pixels down on exit and back to its authored Position on entry. The frame Size and text styling (TextScaled, TextSize, wrapping, font, rich text, localization and colours) are not overridden. Content and the existing typewriter reveal still update. Speaker changes swap content while faded out; same-speaker lines keep the panel open.

Speaker title colours: You `RGB(166, 202, 161)` (faint green); Customer `RGB(224, 185, 143)` (faint orange). `NPC` and `Customer` speaker keys share the Customer portrait/title. Only title colour changes; existing text sizing, camera placement and fade/slide transitions are retained.

## Current prototype customer assets

`ReplicatedStorage.Assets.NPC` is now a Folder of authored customer Models. Prototype orders carry a server-selected appearance ID so world customers and their subtitle portraits match, including for duplicate source names. Existing single-Model NPC setups remain supported. Customer titles stay pale orange and You stays pale green. Current presentation preserves authored text settings, card layout, and the existing viewport Camera CFrame/FOV; earlier auto-fitting, lowercase asset, fixed-text-size and card-size notes above are historical.

The current card is `HUD.Dialogue`, containing `Title`, `Paragraph` and `CharacterViewPort.ViewportFrame`, optionally inside `Frame`. Both Game modes prefer this card. `DPU_PrototypeHUD.DialogueSubtitles` and `HUD.Subtitles` remain compatibility fallbacks; the active session hides both unused legacy cards and restores their visibility on teardown. The old subtitle cards can be deleted once the new card is present. Existing viewport cameras are reused unchanged; if none exists, the existing DialogueConfig pose and FOV initialize an owned camera. No authored UI is generated or renamed.


## Monochrome portraits

Both customer and player viewport clones use `PortraitGrayscale`, with neutral viewport lighting/tint. The authored camera CFrame, FOV, framing, model transforms, clothing and animation selection remain unchanged. Base-part/body colors become grayscale; supported MeshPart and Decal/Texture images are converted to equal-RGB pixels with alpha preserved. A SurfaceAppearance color map can be converted into the clone's mesh texture; world/source models are never edited.

Conversion is best-effort: Roblox Image API permissions, asset access and device memory limits apply. Classic Shirt/Pants/ShirtGraphic and SpecialMesh textures cannot be assigned EditableImages by this path, so their original textures remain visible. `DPU_GrayscaleReady` and `DPU_GrayscalePartial` on the runtime portrait report complete versus partial conversion. No gray tint is claimed to desaturate unsupported textures.

One worker per portrait caches duplicate texture IDs, processes small strips, and caps allocations at eight images / one million retained pixels. Speaker changes destroy owned images; obsolete or late loads cannot apply to the replacement speaker. There are no per-frame texture conversion loops. GameLost uses the same RGBA conversion helper for its single headshot; see HUD_PANELS.md and [Roblox's EditableImage API](https://create.roblox.com/docs/reference/engine/classes/EditableImage).
