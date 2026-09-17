# Authored telephone camera and keypad

Add the **Fax** tag to the supplied telephone Model anywhere under Workspace; its name can be anything. Keep its parts anchored/queryable as appropriate for a stationary prop. The central [tag system](TAGGED_INTERACTIONS.md) selects it, and its existing parts and UI are reused:

```text
Telephone (Model)
  Key0 ... Key9 (BaseParts / MeshParts)
  Key*
  Key#
  KeyClear
  KeyClose
  Dial
  End
  Phone, CallStatus, Telephon/Fax, etc. (preserved artwork)
  InputArea
    SurfaceGui
      Frame
        TextLabel
```

Click/tap the phone within eight studs, or aim and press E/RT. Your SelectionHighlight marks the model before selection. The camera smoothly moves above/front of the telephone and looks toward its bounds center. It releases the mouse for the physical keypad and hides only your own avatar locally. The display's Enabled/Visible ancestor chain is revealed; its authored geometry, fonts and other styling stay intact. Normal exits tween camera position, focus and FOV back to first person before restoring native camera ownership. Everything changed locally is restored on exit.

The supplied camera and model positions were identical `(8.572, 0.768, 34.802)`, so they could not define a usable camera offset. With owner approval, the default uses local direction/offset **(0, 2.5, -2.4)**, a **45-degree FOV** and **0.35-second tween**. It increases viewing distance when needed to fit the phone bounds, including portrait displays. Moving or rotating Telephone also moves/rotates its framing; no supplied world position is hardcoded. Tune `GClient/Effects/TelephoneConfig.CameraOffset`, FieldOfView and TweenSeconds for your model. Negative local Z faces the front of the supplied fax; the positive-Z view was behind it. Orientation uses [Roblox CFrame basis vectors](https://create.roblox.com/docs/reference/engine/datatypes/CFrame#fromMatrix).

## Controls

- Click/tap the actual Key0–Key9 meshes to enter digits. Key* and Key# enter their symbols. Numbers stay local and are limited to 12 characters.
- KeyClear clears all digits. Keyboard numbers, Backspace and Delete are also supported.
- Controller: D-pad moves among the highlighted physical keys; A or RT presses the selected key. B closes.
- KeyClose, Q, B or the touch-accessible CLOSE PHONE button exits. Moving/jumping away, death, seating, respawn, opening Roblox menus, typing in another text box, losing focus, removing the phone or replacing the camera also exits.
- End hangs up and clears the entry. Dial/Enter connects 67, 1984 and 404; empty input shows ENTER NUMBER and unrecognised digits show NOT CONNECTED. Connected calls lock digit editing until End or Close. Incoming calls, audio and server-side consequences remain future work.

Touches dragged more than 18 pixels at any point (including away then back) or held longer than 0.6 seconds do not press a key. Container clicks are blocked while using the phone. Reduced motion switches directly to the close-up without the camera tween. Keyboard/controller/touch controls share the same local digit state.

Ensure keys have **CanQuery = true** and are exposed above/through the phone's surrounding meshes. Non-collidable trim is skipped within the inspected phone. Collidable plates block; author cosmetic trim non-collidable or query-excluded instead of weakening wall occlusion. The script does not modify model geometry, SurfaceGui.Face, welds or authored text styling. InputArea must show the supplied SurfaceGui on the intended face.

## Sync

Sync all three Game roots. `GClient/Startup/GameController.luau` is the active LocalScript; remove older root GameController/ContainerController instances using the move manifest. TelephoneController and TelephoneConfig are ModuleScripts in GClient/Telephone. TelephoneController delegates all camera ownership to GClient/Camera/InspectionCamera and receives input exclusively from InteractionController. No Script is needed inside the telephone model; no new server module or remote is needed for local viewing/input.

This is a local easter-egg call state machine: other players do not see private digits/receiver motion. No real-world call or shared gameplay consequence occurs. Add server validation if calls later affect gameplay. The generated prototype has been retired.

## Verification

Run `tests/Telephone.luau`, Containers, Validate and existing suites. Telephone checks use mocked Roblox input/tweens and actual vector/CFrame math, including translated/rotated and portrait framing, tap/drag distinction, keypad limits, authored screen restoration, local avatar restoration and interrupted tweens. Studio still needs to verify the actual imported pivot, camera angle, readable screen face, physical key hitboxes, controller focus and mobile fit. No live Studio model edits or publishing are performed by the source change.

## Receiver and future subtitles

Recognised routes live in `GClient/Effects/TelephoneCalls`. After the brief route-specific dial delay, the call enters Connected once. Dial cannot duplicate an active call, and ending/closing before connection prevents a late Connected event. Physical KeyClose calls the same Close method as the screen button, including while dialing/connected. The named End key is included in controller navigation.

The direct `Phone` child can be a BasePart/MeshPart or multipart Model. ReceiverMotion creates a local anchored/query-excluded visual, hides the authored receiver using LocalTransparencyModifier, and eases the visual above/behind the camera. End or leaving the phone eases it back to its model-relative home before restoring exact visibility. Clone-only joints/scripts/effects/tags are removed before parenting; the authored fax and welds stay untouched. Reduced motion completes immediately. Teardown/removal cleans up safely.

`PlayerGui.DPU_GameInteractions.TelephoneCallChanged.Event` exposes `{Phase, Number, Id, SubtitleKey, SessionId}`. Dialing/Connected/Ended events share one fresh SessionId. The future subtitles adapter should start on Connected and cancel on Ended. The current change intentionally provides the hook and route keys without generating a subtitle UI or audio.

Run `tests/Telephone.luau` and `tests/ReceiverMotion.luau` with all active suites. Verify imported Phone geometry, pickup path and physical KeyClose in Studio.
