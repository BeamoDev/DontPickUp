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

Click/tap the phone within eight studs, or aim and press E/RT. Your SelectionHighlight marks the model before selection. The camera smoothly moves above/front of the telephone and looks toward its bounds center. It releases the mouse for the physical keypad and hides only your own avatar locally. The display's Enabled/Visible ancestor chain is revealed; its authored geometry, fonts and other styling stay intact. Everything changed locally is restored on exit.

The supplied camera and model positions were identical `(8.572, 0.768, 34.802)`, so they could not define a usable camera offset. With owner approval, the default uses local direction/offset **(0, 2.5, 2.4)**, a **45-degree FOV** and **0.35-second tween**. It increases viewing distance when needed to fit the phone bounds, including portrait displays. Moving or rotating Telephone also moves/rotates its framing; no supplied world position is hardcoded. Tune `GShared/Telephone/TelephoneConfig.CameraOffset`, FieldOfView and TweenSeconds for your model. Positive local Z selects its front side by default; flip Z if the imported pivot faces the other way. Orientation uses [Roblox CFrame basis vectors](https://create.roblox.com/docs/reference/engine/datatypes/CFrame#fromMatrix).

## Controls

- Click/tap the actual Key0–Key9 meshes to enter digits. Key* and Key# enter their symbols. Numbers stay local and are limited to 12 characters.
- KeyClear clears all digits. Keyboard numbers, Backspace and Delete are also supported.
- Controller: D-pad moves among the highlighted physical keys; A or RT presses the selected key. B closes.
- KeyClose, Q, B or the touch-accessible CLOSE PHONE button exits. Moving/jumping away, death, seating, respawn, opening Roblox menus, typing in another text box, losing focus, removing the phone or replacing the camera also exits.
- End clears the local entry. Dial/Enter shows ENTER NUMBER for empty input or NOT CONNECTED for entered digits. Call destinations, sounds, receiver movement, RedButton, CallStatus, incoming calls and server-side call consequences are not wired up in this step.

Touches dragged more than 18 pixels or held longer than 0.6 seconds do not press a key. Container clicks are blocked while using the phone. Reduced motion switches directly to the close-up without the camera tween. Keyboard/controller/touch controls share the same local digit state.

Ensure keys have **CanQuery = true** and are exposed above/through the phone's surrounding meshes. If a decorative plate covers them and absorbs the ray, adjust that plate's CanQuery so keys can be hit. The script does not modify model geometry, SurfaceGui.Face, welds or authored text styling. InputArea must show the supplied SurfaceGui on the intended face.

## Sync

Sync GClient and GShared with the current GServer (prototype remains off). **GameController.local.luau replaces ContainerController.local.luau** as the active LocalScript at the Game client root. Delete the obsolete ContainerController instance if Script Sync does not remove it. TelephoneInteraction and TelephoneConfig are ModuleScripts in their respective new Telephone folders. No Script is needed inside the telephone model; no new server module or remote is needed for local viewing/input.

This is local presentation only: other players do not see your partially entered number, and no call or shared gameplay result is claimed. Add server-authoritative visit/ownership/number validation before wiring dialing to real game consequences. The archived prototype remains independent.

## Verification

Run `tests/Telephone.luau`, Containers, Validate and existing suites. Telephone checks use mocked Roblox input/tweens and actual vector/CFrame math, including translated/rotated and portrait framing, tap/drag distinction, keypad limits, authored screen restoration, local avatar restoration and interrupted tweens. Studio still needs to verify the actual imported pivot, camera angle, readable screen face, physical key hitboxes, controller focus and mobile fit. No live Studio model edits or publishing are performed by the source change.
