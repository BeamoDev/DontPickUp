# Authored phone repair

Tag the **whole Phone Model** with `PhoneRepair`. Do not also tag it `Fax`, `throw`, or another interaction type. Keep the model, meshes, textures and existing folders in Studio; no replacement phone is generated. Sync all three Game roots together and restart Play so the new `RepairDrag` event and controllers load.

Required hierarchy (all named leaves are BaseParts or MeshParts):

```text
Phone [Model, tag PhoneRepair]
  Phone
  Screen
  Battery
  BackCover
  Screws/
    Screw1, Screw2, Screw3, Screw4
  Pipes/
    EntryPoint1, EntryPoint2, EntryPoint3, EntryPoint4
    ExitPoint1, ExitPoint2, ExitPoint3, ExitPoint4
  Wires/
    Red, Yellow, Blue, Pink
  Keys/ ... authored keys, unchanged
  SimTray ... unchanged
```

Other body parts move with the phone. The scripted source-folder rule applies to `src`, not to this authored model hierarchy. Intended world hit surfaces need CanQuery enabled. Endpoints must be separate parts placed on the exposed back/interior of the phone. Wires should be authored along their finished paths; scripts reveal those meshes rather than generating replacement wiring.

## Sequence

The player is locally anchored and the original camera pose/FOV is captured by InspectionCamera. The server reserves the phone for that player, lifts it into a front camera view, turns it 180 degrees, rotates and withdraws the four screws, fades them to Transparency 1, moves the cover away, slides the battery out, and lays the pieces on the table. Screws become visible again in the loose-parts row. The camera then eases into a fitted workbench view.

Hold and drag from an **ExitPoint to its matching EntryPoint**:

| Start | Finish | Revealed wire |
| --- | --- | --- |
| ExitPoint4 | EntryPoint1 | Red |
| ExitPoint3 | EntryPoint2 | Yellow |
| ExitPoint2 | EntryPoint3 | Blue |
| ExitPoint1 | EntryPoint4 | Pink |

These are the owner-specified pairings in `GShared/Repair/RepairDefinition`. Wires can be completed in any order. The local line and destination marker guide the drag; a correct release reveals that wire's actual world mesh for everyone. Wrong releases leave it hidden. Adjacent endpoints have non-overlapping snap radii.

After all four wires, drag the battery into its marked slot, then the back cover, then all four screws into their corresponding holes (screw order is unrestricted). Installation eases into place; screws rotate as they seat. Finally the complete phone returns to its original table pose. Its repaired wires remain visible and the same phone cannot start another repair until it is rebound/reset. No rewards or saved story progress are added.

Mouse and touch use press/drag/release. A second finger cancels the current drag. Controller left stick moves the repair cursor; hold A or RT to drag and release to drop. E works with the current mouse position. Q/B or CLOSE REPAIR cancels and returns to first person. Closing, focus/menu loss, death, respawn, model removal, lost eligibility and timeout restore the authored assembly; an incomplete repair restarts from scratch. Cancellation does not leave the character anchored.

## Ownership and cleanup

- `GShared/Repair/RepairDefinition`: public pairings, drag bounds and step eligibility.
- `GShared/Repair/RepairRig`: strict authored-part lookup, bounded model size/part count.
- `GServer/Repair/PhoneRepairService`: reservation, state order, revisions, bounded drag coordinates, drop validation and completion.
- `GServer/Repair/RepairMotion`: captured part transforms, temporary joint disabling, disassembly layout and restoration.
- `GClient/Repair/PhoneRepairController`: camera phases, instructions and session lifecycle.
- `GClient/Repair/RepairDragController`: input delegated by the existing central controller, ray/endpoint picking, preview line, and drag/drop requests.

The server animates actual world parts. Battery, cover and screw dragging is replicated through server movement; only the wire preview line is local. Changed drag coordinates are limited to 20 messages/second and clamped to a server-created table plane. No client CFrames, arbitrary parts, rewards or completion flags are accepted. One shared server heartbeat exists only while repair sessions are active. The existing central post-camera update owns client repair input/hover; there are no per-phone input or render listeners.

`Request` handles BeginRepair, RepairGrab and RepairDrop. Session/drag tokens and revisions reject stale or duplicate actions. `RepairDrag` carries a drag token and two bounded plane coordinates. A token without coordinates cancels that token's session or drag, independently of the gameplay request-rate bucket. CancelRepair/RepairRelease requests remain token-checked equivalents. Session timeout is 180 seconds; an individual drag times out after 15 seconds.

Internal welds/joints/constraints are temporarily disabled, then restored to their captured Enabled values. Externally connected phones are rejected. No authored joints are deleted; see Roblox's [joint Enabled API](https://create.roblox.com/docs/reference/engine/classes/JointInstance#Enabled). Original anchoring, query/collision/touch flags, frames and transparency are restored on cancellation. On successful completion only repaired wire transparency changes to zero.

## Studio verification

The screenshot establishes names, not mesh orientation or scale. Layout uses the Phone body's thinnest axis as its face normal, chooses its front sign from Screen versus BackCover, and uses the long body axis as the top. The original model's bottom bounds establish the table height. Verify this against the imported mesh before tuning RepairMotion offsets.

Test the actual front/back orientation, complete screw rotations/fade, cover and battery clearance, table contact, wire endpoint placement, all four visible wires, readable camera framing on phone/tablet, and return to first person. Test with two players: only one may reserve the phone, observers should see the animation/assembly drags, and interruption/disconnection must restore it. Also test under network emulation and streaming. Local tests use mocked services and cannot establish these visual or replication results.

Phone repair now uses a dedicated overhead wire close-up fitted to all eight installed endpoints with viewport-aware margins and 38-degree FOV. After the fourth wire, it eases back to the wider assembly view (45-degree FOV). Repair camera transitions take 0.55 seconds; reduced motion still skips them. `GClient/Repair/RepairViewConfig` owns this framing. Lift, flip, layout and final return interpolate a common body transform to preserve the phone assembly; quintic easing softens part motion and installation. Verify actual endpoint scale, portrait/landscape framing, imported mesh clearance and replication in Studio.

Wire previews are 8-pixel lines anchored at the exact press position on the starting socket height. Cursor rays intersect that fixed world-Y plane for both preview and drop coordinates. The GUI segment uses its midpoint as the rotation centre, avoiding direction-dependent offsets; the destination label sits above its socket.

Wire previews copy the authored wire mesh Color. Drops select the actual socket surface or nearest socket within 18 pixels (26 on touch), with other sockets competing so a wrong endpoint cannot snap to the correct one. A matched socket sends its exact server-provided planar centre; preview snapping uses the same selection. Server token, stage, revision, bounded coordinates and wall validation remain in force. The arbitrary 0.1-second server drag cutoff was removed so quick gestures and back-to-back arrivals can complete. Failure feedback remains visible for 1.5 seconds. Verify with actual mesh geometry, touch input and network emulation in Studio.

Socket acceptance validates inspection access through a server-derived point above the work area, then down to the upper socket surface. It no longer uses the frozen character head-to-socket diagonal, which can cross a desk edge. Both path segments retain normal wall/terrain blocking, without excluding scenery.
