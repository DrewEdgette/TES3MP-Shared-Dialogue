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

Shared Dialogue 0.3.0 reports `0.8.1-shared-dialogue.3` and uses protocol **14**.
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

## Optional Voices of Vvardenfell

VoV is not required. This build supports the legacy ESP that uses the native
`Say` command in dialogue result scripts, including `VoV-uniqueDialogOnly.esp`.
It does not add modern OpenMW Lua support to TES3MP 0.8.1.

The initiator's opening greeting and deliberate topic selections send live
response speech. Each listener plays the named file from their own `Data Files/Sound`
through the normal voice volume and NPC positioning. Both players need the
matching local voice files to hear the same line; the server needs no audio.
A missing file, absent mod, or unvoiced response is normal and stays silent.
Morrowind's existing `.wav` to `.mp3` fallback is preserved. Server content-list
requirements for ESPs still apply separately from optional sound-file playback.

Joining/rejoining restores the transcript without replaying any previous audio,
even the line currently being spoken. Future voiced responses play normally.
Advancing to a new response (including an unvoiced one), leaving, entering a
service or closing the conversation stops shared speech. Scrolling, topic-list
updates and spectator clicks cannot start speech.

## Shrine and other scripted speech

Native `Say` commands outside the greeting/topic capture also share their sound
and subtitle, including local/global scripts and service or answer result scripts.
This covers the deities' `Player->Say` lines without requiring VoV. Nearby living
players in the same cell receive each new line within the configured radius.
For `Player->Say`, distance is measured from the activating player at that moment
and the voice plays directly for each listener. Other world objects and NPCs
use the speaking reference's position.

Listeners see a noninteractive subtitle when their own subtitles are enabled,
even if the initiating player disabled subtitles or their local audio file is
missing. No conversation window is required. These lines are live only, with no
replay on arrival, and do not run the shrine's scripts or duplicate quest rewards.
