# Contributing to TES3MP Shared Dialogue

Use this fork's issue tracker for Shared Dialogue problems. It is maintained
independently of TES3MP/OpenMW; direct fork-specific support requests here.

## Bug reports

Include the exact client/server versions, operating system, server script version
and custom scripts, relevant mods, NPC/cell/topic, and reproduction steps. Say
which player was speaking and what the listener saw. Relevant log excerpts or
screenshots help; remove passwords, addresses and account data.

## Code changes

- Follow the surrounding upstream C++ style and keep changes focused.
- Spectator rendering must never execute dialogue scripts or service actions.
- Preserve server ownership checks and bounded packet/state validation.
- Add regression coverage when changing sessions or networking. A changed wire
  format requires a protocol bump on both ends and compatibility notes.
- Run the [documented build and tests](docs/shared-dialogue/building.md).
- State what changed and what was tested. GUI changes also need an in-game check.

Do not commit game data, accounts, logs, dependency downloads, executables or
build directories. Source contributions follow the repository's existing license.
The [upstream contribution guide](CONTRIBUTING.upstream.md) is retained as
historical context; Shared Dialogue's scope and review take place here.
