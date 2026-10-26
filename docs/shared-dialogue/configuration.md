# Configuration and compatibility

## Listening radius

```ini
[Dialogue]
radius = 420
```

Distance is measured in **3D Morrowind world units from the NPC**, using its
position at the start of the session. Players must be in the same cell. The
radius applies to automatic invitations and manual joining/rejoining. Invalid,
nonpositive or nonfinite values fall back to 420.

The server reads `tes3mp-server-default.cfg` beside the executable, then its user
`tes3mp-server.cfg` overrides. Put the setting in the configuration already used
by your server and restart it. Ordinary Windows installs retain TES3MP's usual
user configuration locations. With the optional `tes3mp-portable.txt` marker,
user files live in the adjacent `user` directory. Upgrade ZIPs do not enable
portable mode.

After joining, walking beyond the starting radius alone does not close a listener's
window. Leaving the cell, death or leaving the conversation does.

## Network compatibility

Shared Dialogue 0.1.0 reports `0.8.1-shared-dialogue.1` and uses protocol **12**.
Every client and the server must use the same Shared Dialogue release; stock
TES3MP is incompatible. TES3MP checks the protocol, complete version string and
commit identifier stored in `resources/version`. Upgrade the whole group,
including that supplied resource file. Keep it together with the executables
from the same release.

Future wire-format changes must bump the protocol on both client and server.

## Server scripts

Official CoreScripts reads and copies received object lists before forwarding
dialogue choices. That preserves the session identifier, so its normal path
needs no changes. The pinned development revision is
`3e397a11eaf7d0d4ff08df4bb9925e67748b4db8`.

Custom scripts rebuilding `ObjectDialogueChoice` packets from scratch can lose
that identifier. Prefer the standard read/copy/forward flow and test custom
handlers. The server rejects choices without the correct speaker, NPC and
session. Journal-sharing settings remain controlled by server scripts.

## Services and interruptions

Listeners see activity labels for barter, spell buying, spellmaking, enchanting,
training, travel, repair, persuasion and companion inventory. Service contents
and controls are not mirrored.

A player already using a menu declines automatic invitations and can join later
by activating the NPC. New arrivals can also join manually. Goodbye, disconnect,
death or cell change ends the speaker's session. A listener can always leave
without ending it.
