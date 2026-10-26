# Testing status

## Verified

- Shared dialogue, passive blue keywords and the mirrored topic list were
  tested in a two-person TES3MP playthrough.
- Windows x64 Release client/server compilation.
- Session tests for ownership, replay, state/history limits, topic replacement
  and the 420-unit 3D distance boundary.
- Production serializer tests for UTF-8, every byte truncation of a valid message,
  malformed sizes/actions, topic limits and fresh decode state.
- **87** live checks against an isolated server and four headless clients:
  filtering, ownership, spectator permissions, topic updates, replay, death,
  cell transitions and disconnect cleanup.
- Two rendered clients: automatic opening, matching text, inert blue keywords
  and topic entries, wheel/scrollbar operation, leave/rejoin including new topics,
  role reversal, session closure and Training status.
- The Windows client/server built with the documented dependency recipes passed
  both CTest targets, the 87 live checks and a two-window spectator smoke check.
  Release ZIPs passed entry-by-entry SHA-256 verification.
- Source-built runtime checks passed: PNG/JPEG/BMP/TGA/DDS image round trips,
  FreeType font loading, OSG serialization, OpenAL null-backend context/buffer,
  generated PCM WAV decoding/resampling and PNG decoding/conversion.
- Sample decoding/conversion also passed for 17 copied Morrowind BIK files,
  one MP3 and one WAV. Each probe reads up to 200 packets and requires a decoded
  frame for every audio/video stream; this is not full cutscene playback coverage.
- Two rendered clients in a fresh runtime using the packaged DLLs
  showed matching text, passive blue keywords and topic lists, and mirrored
  a speaker's topic selection.

Rendered automation used a disposable localhost Lua fixture and `ForceGreeting`
to open the real NPC window. Human playtesting additionally exercised normal use.

## Limits

- DLC quest coverage, all mods and all custom server scripts are not exhaustive.
- Windows x64 is the validated game platform; VR/Linux/macOS remain unvalidated.
- The translated `@topic#` code path is supported, but rendered tests used English.
- Service contents and voice audio are not mirrored. Activity labels are English.
- History lasts only for the session, subject to the [documented limits](architecture.md).

## Running tests

Follow [building.md](building.md). `test.ps1` runs CTest, starts its own
localhost-only server on UDP 25576 (stopping only that process afterward), and
runs the runtime library probes. No game assets are needed.

To add sample decoding checks using your own local media:

```powershell
./scripts/shared-dialogue/test-runtime.ps1 -MediaFiles 'C:/your-copy/Data Files/Video/mw_intro.bik'
```

The media stays on your machine and is never included in the release packages.
`audit-runtime.ps1` checks all selected DLL/executable imports; `package.ps1`
runs that audit and verifies each ZIP entry against its source file.

The manual `game-server.lua` fixture has no accounts or campaign persistence.
Use `start-ui-test.ps1` only locally; it binds to 127.0.0.1:25577. Its `command.txt`
accepts `talk0`/`talk1` (open/rejoin), `setup0`/`setup1` (controls) and
`topics0`/`topics1` (teach only the named player some topics to verify
speaker-specific mirroring).

Before gameplay changes or new platform releases, use copied campaign data to
check a fresh quest/journal update, forced choices, simultaneous activation,
services, custom scripts, death/teleport/disconnect and representative DLC quests.
Record the exact build and what was exercised.
