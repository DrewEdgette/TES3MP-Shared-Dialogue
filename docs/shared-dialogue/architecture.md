# Shared Dialogue architecture

This patch is based on TES3MP commit
`49be5b6405d6ab427e06ed350cf76c715a1f3bdd` (0.8.1).
Its reported version is `0.8.1-shared-dialogue.1`, protocol 12.

## Ownership and presentation

`components/openmw-mp/Dialogue.hpp` defines the shared data model, bounded
transcript store, actor identity, and range check. An actor is keyed by canonical
cell name, reference ID, reference number, and multiplayer number. Session IDs
are monotonically increasing within the server process.

`PacketPlayerDialogue` is a reliable ordered player packet with bounded raw UTF-8
strings. `Request` precedes running any greeting. The server grants one owner
and subscribes available nearby listeners; a request for an occupied NPC returns
its transcript as a spectator. `Append` carries resolved response/message text,
and `State` carries noninteractive answer labels, the owner's current ordered
topic list, and service status. `Open` includes these fields for replay. `Leave`
removes a listener; only the owner can `End`, append text, or change state.

`apps/openmw-mp/SharedDialogue` validates readiness, death, cell, and range;
routes messages; and releases sessions on disconnect or cell changes. It retains
history even if no spectators are listening. Like upstream TES3MP, the server
does not simulate NPCs; the initiating client supplies the NPC position, which
is compared with server-held player positions. This is intended for cooperative
play, not a new anti-cheat boundary for the rest of TES3MP.

The normal `DialogueWindow` has a spectator mode. It displays response objects
directly and disables both visible controls and action handlers. It does not
execute `startDialogue`, `questionAnswered`, restocking, or `goodbyeSelected`
for spectators. The initiator continues to run the original dialogue manager
after the server grants ownership. Choice selection is included in the displayed
history, and services keep the parent session alive while updating a status label.

Spectator responses use the owner's topic list for keyword matching, including
translated `@topic#` markup. They render matching words with ordinary blue styles,
never interactive link IDs. The sidebar uses `MWList::setSelectionEnabled(false)`
to prevent item activation and keyboard focus while keeping scrolling enabled.
Topic changes are sent with state changes, without consulting the spectator's
dialogue manager or executing scripts. Changing roles restores item selection.
The default listening radius is 420 engine world units from the NPC.

The existing executable `ObjectDialogueChoice` packet now includes the session
ID. The server requires matching ownership, actor, and session before dispatching
the Lua callback. The client also checks those values, so a delayed response
cannot activate a topic in a later conversation with the same NPC. Official
CoreScripts' copy-and-send flow preserves the new field without Lua changes.

Late grants are rejected when the requesting window was closed or superseded.
Pending windows are inert and time out after 15 seconds. Spectators can exit
even when the owner is answering a forced question. A listener already using a
menu declines an automatic invitation and can manually join later.

Each transcript permits 4,096 entries or 4 MiB of text; individual strings permit
32 KiB, and state permits 128 answer labels and 4,096 topics totaling at most
256 KiB. Invalid topic state is rejected without partially updating the session.
Exceeding history limits ends the
conversation with a message rather than silently losing earlier dialogue.
The server retains no transcript after the owner ends the session.

## Windows isolation

`components/files/windowspath.cpp` recognizes an opt-in `tes3mp-portable.txt`
marker beside the executable. With it present, all application user paths resolve
under `user` beside that executable and the registry install-path lookup is
skipped. Without the marker, upstream path behavior is preserved. The packaging
script creates the marker before running anything. Build temp files are also
kept inside the containing workspace.

See [building.md](building.md) and [testing.md](testing.md) for build instructions and test evidence.
