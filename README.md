# TES3MP Shared Dialogue

Fork of [TES3MP](https://github.com/TES3MP/TES3MP) that lets nearby
players follow the same NPC conversation in Morrowind. One player talks and everyone
nearby sees the full dialogue as it happens.

Based on TES3MP **0.8.1 / OpenMW 0.47.0**. This is a client and server engine modification, not an
ESP or a server-only Lua mod.

![A spectator following an NPC conversation, with blue keywords and a visible topic list](docs/shared-dialogue/images/spectator.jpg)

The spectator can read and scroll both panels. Only the speaker can advance the dialogue.

## What changes

- Opening a conversation automatically opens a spectator window for available
  players in the same cell within **420 world units of the NPC**.
- Spectators see the full conversation, blue keywords, answer choices and the
  speaker's current topic list. They can scroll the transcript and topic list
  independently; only the speaker can select a topic or answer.
- Spectators can leave at any time. Activate the same NPC to rejoin while the
  speaker is still talking, with the complete current history restored.
- An NPC already in a conversation admits additional players as spectators.
- Optional Voices of Vvardenfell support: listeners hear voiced greetings and
  selected topics when they have the same local audio files. Missing files and
  unvoiced responses stay silent; rejoining never replays earlier speech.
- Barter, travel, enchanting and other services display an activity status for
  listeners while the speaker uses the normal service window.
- Goodbye, cell changes, death and disconnect clean up the relevant sessions.
  A spectator leaving does not end the speaker's conversation.

Automatic invitations are skipped while a player is already in another menu
or conversation. They can activate the NPC to join later. Audio files and service
contents are not transferred. Journal sharing remains controlled by server scripts.

Voice support targets VoV's legacy `Say`-based ESP, including
`VoV-uniqueDialogOnly.esp`. VoV is optional and is not bundled. See
[voice compatibility](docs/shared-dialogue/configuration.md#optional-voices-of-vvardenfell).

## Configuration

The server can change the radius with:

```ini
[Dialogue]
radius = 420
```

An explicit existing value overrides the default. See
[configuration and compatibility](docs/shared-dialogue/configuration.md) for
file locations, custom server scripts and protocol details.

## Download and install

Use this repository's **[Releases](../../releases)** page for published downloads.
Before the first release is published, follow the [build guide](docs/shared-dialogue/building.md).
GitHub's automatic **Source code** downloads are for building the project; they
are not playable installations.

| Download | Use |
| --- | --- |
| Windows x64 (`windows-x64.zip`) | Everyone: joining players and hosts |
| Source bundle (`sources.zip`) | Developers and redistributors |

One complete package includes the client, server and the usual TES3MP launcher,
setup wizard and server browser. **No existing TES3MP installation is needed.**
Morrowind game files and mods are not included; use your own installed copy.

- **New players:** extract the ZIP, run `openmw-wizard.exe` to select your
  Morrowind installation, then use `tes3mp-browser.exe` to join your host.
  Use `openmw-launcher.exe` for game settings and your server's mod list.
- **Existing players and hosts:** extract into a **new folder** and keep the old
  one as a backup. Normal Windows user settings are reused. Copy any customized
  local `.cfg` files; hosts should replace the new `server` folder with a copy of
  their existing one to retain scripts, accounts and saves. Portable installations
  also need their existing `user` folder and `tes3mp-portable.txt`.
- **Hosts:** run `tes3mp-server.exe` from that same package.

See [installation and upgrades](docs/shared-dialogue/installation.md) for the
steps, including relative game-data paths and rollback. Everyone must use the
same Shared Dialogue build; stock TES3MP clients and servers cannot participate.

The Windows build uses [FFmpeg](https://ffmpeg.org) under the LGPLv2.1 or later.
Its matching source is included in the `sources.zip` asset on the same
[Releases](../../releases) page. See the [dependency inventory](THIRD-PARTY-NOTICES.md).

## Development and support

- [Build from source](docs/shared-dialogue/building.md)
- [Implementation](docs/shared-dialogue/architecture.md)
- [Testing status and limitations](docs/shared-dialogue/testing.md)
- [Shared Dialogue changelog](docs/shared-dialogue/changelog.md)
- [Contributing and reporting bugs](CONTRIBUTING.md)
- [Release preparation](docs/shared-dialogue/releasing.md)

Report Shared Dialogue issues in **this fork's issue tracker**. Include the
client/server version, server scripts and mods, and steps to reproduce.

## Credits and license

Copyright (c) 2008-2015, OpenMW Team.

Copyright (c) 2016-2022, David Cernat & Stanislav Zhukov.

TES3MP Shared Dialogue builds on the work of the [TES3MP team](tes3mp-credits.md)
and [OpenMW contributors](AUTHORS.md). It is independently maintained and is not
an official release or endorsement by either project or Bethesda Softworks.
The original introduction is retained in [README.upstream.md](README.upstream.md).

The existing [GPLv3 license with TES3MP's additional terms](LICENSE) is preserved.
See [third-party notices](THIRD-PARTY-NOTICES.md) for dependencies. Morrowind game
assets belong to their respective rights holders. Game data needed to play is not
distributed here; the screenshot demonstrates the interface.
