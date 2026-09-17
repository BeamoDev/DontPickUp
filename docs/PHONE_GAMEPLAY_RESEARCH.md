> Historical design/research material. The generated-game implementation described here has been retired. See [CURRENT_ARCHITECTURE](CURRENT_ARCHITECTURE.md) for active systems and deployment.

# Customer-phone gameplay research

Reviewed 2026-09-15. This is a research and implementation-gap review, not a claim that the proposed interactions are playable.

**Subsequent implementation:** six-digit fax collection and usable customer phones are now implemented; see CURRENT_ARCHITECTURE. The owner subsequently set Story to five nights and confirmed four colored wire pairs. The current phone supports CIVIC WATCH installation, browsing, calls, answer/ignore, team refusal and recovered records. The gap table and proposals below preserve the research baseline, rather than describe the latest runtime. Authored campaign expansion and Studio verification remain outstanding.

## Owner correction

The owner likes the current repair flow. Preserve it. Government software installation, answering customer-phone calls and looking through the customer's phone are core interactions that the prototype still needs. Optional deeper lore does not mean these interactions can be replaced by unrelated puzzles or room documents.

Keep the owner's 1980s setting, 1-4-player cooperation, short instructions, ordinary jobs and existing bench flow. The inspiration is a reference, not authority to change those decisions.

## Sources and limits

- [Official Steam description](https://store.steampowered.com/app/4878690/Dont_Pick_Up/?l=english), read directly. It connects device repair with private information, changing daily regulations, reporting, surveillance of workers and endings determined by choices. It also places the wider crisis outside the shop window. This supports making device access and compliance part of ordinary work. The description alone does not establish an exact software-installation interface or customer-call sequence.
- [Owner-supplied gameplay video](https://www.youtube.com/watch?v=LNVV4C_K9LQ): **A Phone Repair Horror Game Where The Government Listens...**, Brokenskull, 35:13. Its public metadata was retrieved. Direct caption/transcript requests failed; the owner then supplied the timestamped transcript, which was read in full through the outro. The findings below use that transcript, not independently viewed footage. Transcription errors affect some names and item labels. Separate the commentator's theories from instructions and outcomes reported in the transcript.
- [Complete owner design](../AGENTS.md#complete-game-design-owner-supplied), especially Main gameplay loop, Daily regulations, Information and evidence, and Evidence decisions. This explicitly calls for software installation, deliberate access to private content, linked discoveries and consequences. These requirements are stronger evidence for our adaptation than assumptions about the video.

## What the current source actually does

| Interaction | Current implementation | Missing experience |
| --- | --- | --- |
| Government program | `PrototypeConfig` tells staff to add it. `WorkPuzzles.New("Install", ...)` selects number copying or a wave/number/button puzzle; the cartridge is required. | No named program, visible installation state or meaningful distinction between required software and optional phone access. |
| Phone contents | `RepairFlow:_completeWork` automatically turns a sensitive installation into an Evidence vote. `ShiftSnapshot` sends that vote's message. | No phone menu, messages, contacts or records to open; discovery is automatic. |
| Calls | `ShiftActions` handles the disconnected shop-phone event. Answering that event causes damage and records an answered call. | No customer-phone contact calls, caller conversation or answer/ignore interaction; no call to arrange collection. The shop hazard does not cover these requirements. |
| Investigation | The team vote changes suspicion; Investigate shows recovered text and awards existing evidence. | No additional phone content to examine after choosing to investigate. |
| Daily rules | `ModeRules.Directive` changes the displayed night number and adds mode/tip text to the same base rules. | No actual per-night software/access policy. Different headings do not constitute changing regulations. |

## Findings from the supplied transcript

| Video section | Supported observation | Implication for our game |
| --- | --- | --- |
| [01:05](https://www.youtube.com/watch?v=LNVV4C_K9LQ&t=65) and [03:49](https://www.youtube.com/watch?v=LNVV4C_K9LQ&t=229) | Notices instruct the worker to repair devices and avoid wasting parts. The worker first tries to power on a dead phone. | Let the ticket and daily rules explain the job; check actual functions before replacing parts. |
| [05:11-06:12](https://www.youtube.com/watch?v=LNVV4C_K9LQ&t=311) | After replacing a battery, the phone starts. The player reads messages and calls contacts, including security and family, with dialogue responses. | Repair unlocks an actual usable device. Outgoing calls and replies matter alongside incoming calls. |
| [07:32-09:33](https://www.youtube.com/watch?v=LNVV4C_K9LQ&t=452) | Reading the judge's messages reveals personal and political connections. Calling the clerk explains her situation and arranges collection. | A phone can support ordinary work, character discovery and optional intrusion through the same controls. |
| [10:29](https://www.youtube.com/watch?v=LNVV4C_K9LQ&t=629) | Calling the harbor office gets the repaired phone's owner to return. | CALL CUSTOMER belongs in the return flow, with the correct number clearly available. |
| [11:48](https://www.youtube.com/watch?v=LNVV4C_K9LQ&t=708) | A new notice requires replacement batteries of a specified version and storage of removed batteries. | Regulations must change accepted actions and parts handling, not just headings. Do not add this entire inventory system merely to deliver phone browsing. |
| [15:55-16:25](https://www.youtube.com/watch?v=LNVV4C_K9LQ&t=955) and [20:27](https://www.youtube.com/watch?v=LNVV4C_K9LQ&t=1227) | A contact call with a customer's mother creates a message the worker can pass on when the customer returns; the customer objects to snooping. | Optional calls can produce personal, sometimes funny consequences without combat or an evidence vote every time. |
| [17:33-17:47](https://www.youtube.com/watch?v=LNVV4C_K9LQ&t=1053) | The transcript records an Accept action and the choice to remain quiet during phone use. | This supports call-response choices, but the precise incoming-call presentation cannot be established from the transcript alone. |
| [21:07-21:18](https://www.youtube.com/watch?v=LNVV4C_K9LQ&t=1267) | The day's notice instructs the worker to call **0042 from a customer's phone** for a mandatory firmware update. | Installation can be a concrete phone/service action. The transcript does not clearly show completion of this update, its progress screen or prove its hidden surveillance behavior. Government monitoring software is also an explicit owner requirement for our adaptation. |
| [25:20-26:26](https://www.youtube.com/watch?v=LNVV4C_K9LQ&t=1520) | The player navigates a different phone's contacts, pictures and messages, finding people and phrases connected to earlier customers. | Device contents should form links across customers. Different models may expose different functions; avoid a modern touchscreen redesign. |
| [33:14-34:18](https://www.youtube.com/watch?v=LNVV4C_K9LQ&t=1994) | A verification visitor asks about a phrase encountered in private content. Arrest follows. The final review lists message-reading and call counts alongside repair and regulation mistakes. | The game observes conduct as well as repair results. The exact arrest trigger is not proven: this playthrough also includes repair/regulation mistakes, and the commentator's explanation is a theory. |
| [34:22-34:38](https://www.youtube.com/watch?v=LNVV4C_K9LQ&t=2062) | The commentator wants clearer guidance on permitted calls rather than indiscriminately trying every number. | Preserve uncertainty about the story while making controls, required work and current rules clear, especially for younger players. |

The central design lesson is that restoring function gives the player access to somebody else's life. Software, dialing, contacts and messages are functional uses of the repaired object. Story emerges from how the player uses that access. More unrelated repair puzzles will not fill this gap.

## Proposed player experience

Retain intake, diagnosis, parts, physical repair and reassembly. At the existing Install step, power up the repaired phone and expose its service menu. Follow with testing, a simple call to arrange pickup and return. Do not add a second station or a long compulsory browsing checklist. This is a proposed adaptation, not an assertion that the video uses this exact state sequence.

1. **Install the government program.** Identify the program and the current order's requirement. For our existing cartridge, use CONNECT CARTRIDGE, then INSTALL GOVERNMENT PROGRAM, followed by PROGRAM INSTALLED. Alternatively, the video's service-number instruction suggests a guided CALL UPDATE SERVICE action on the phone. Pick one clear installation method for the first slice; do not stack both as mandatory chores. Explain the fictional program in a short sentence and keep any verification code short and visible. A generic number puzzle alone does not communicate this job.
2. **Let the player open the phone.** A small period-styled screen or service-terminal interface offers MESSAGES, CONTACTS and RECORDINGS where the device supports them. Most contents should be ordinary: an appointment, a shopping reminder, a family message. Back/close should be obvious. Browsing is optional; routine repairs must remain quick.
3. **Make calls usable.** Let players select a contact and press CALL, with short subtitled dialogue and a few clear replies. Occasionally show an incoming caller or UNKNOWN CALLER with ANSWER and IGNORE. Ordinary calls can add personality; unusual calls can connect to a customer or clue. A clearly labelled CALL CUSTOMER action should use the ticket's correct pickup contact after testing, so required work never means guessing through an address book. Customer calls must have their own state and consequences, separate from the existing dangerous shop-phone event. Do not make every call a jumpscare or automatically apply the shop phone's damage/ending rule.
4. **Make discovery precede the decision.** Opening a suspicious item or hearing a relevant call reveals the clue. Then offer the existing team decision with plain labels: TELL THE GOVERNMENT, KEEP IT SECRET, LOOK CLOSER. Looking closer should expose an additional relevant record rather than only a reward notice. Preserve earned evidence identifiers and solo voting.
5. **Connect software/access rules to the current shift.** Introduce one rule at a time. Future examples: install the program on marked devices, do not open private records, or report a named contact. These are proposed content rules, not claims about the reference video. Deliberate refusal or actions that commit the team's story need the same clear team-choice protection as evidence decisions.

Teach installation on the safe training phone. Let an ordinary message demonstrate the menu before introducing a suspicious one. An entire phone must not become suspicious merely because it has readable content.

## Implementation boundaries for the next gameplay change

- Keep order-local phone state/content on the server under the existing bench reservation. Scope inputs to the run, order, work/visit and revision; validate operator, seating, range, phase and interruptions. Preserve isolation between both benches and cooperative handoffs.
- Keep undiscovered records, future calls, policy evaluation and consequences in `GServer`. A reusable phone view and public button definitions can live in `GShared`; that does not make the private content catalog shared.
- Add explicit program status, currently opened page, discovered records and current-call state. Send only the content authorized for the active interaction. Teammates may receive a discovered clue needed for voting without receiving the whole phone.
- Reserve UI space within the existing repair close-up. Release the mouse for the phone controls; preserve V, stand/close, touch/controller and reduced-motion behavior. Phone controls must not overlap a physical puzzle or compete for the camera.
- Keep server completion authoritative and retry-safe. An animation reaching 100 percent, a client clock or a supplied completion flag cannot install the program or award a clue.
- Record meaningful actions separately: required service/pickup calls, optional contact calls, records opened, software completion and rule violations. Opening the menu must not count as reading every record. Repeated snapshot delivery cannot create extra actions. A call required by the job should not silently count as forbidden snooping. Consequences need their own tested rules; do not infer them from the reference player's arrest.
- Meaningful validation: ordinary install/test/return; optional browsing; discovered clue before voting; both call choices; repeat/stale inputs; two benches; teammate handoff; interruption/death/disconnect; no hidden-content leak; no accidental use of shop-call damage/endings. Follow with rendered Studio checks on mouse, touch and controller.

No runtime changes were made for this research pass. The supplied transcript review is complete; actual footage/UI details and the original game's hidden outcome conditions remain unverified.
