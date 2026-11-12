# Testing status

## Verified

- Shared dialogue, passive blue keywords and the mirrored topic list were
  tested in a two-person TES3MP playthrough.
- Windows x64 Release client/server compilation.
- Session tests for ownership, replay, state/history limits, topic replacement
  and the 420-unit 3D distance boundary.
- Production serializer tests for UTF-8, every byte truncation of a valid message,
  malformed sizes/actions, topic limits and fresh decode state.
- **146** live checks against an isolated server and four headless clients:
  filtering, ownership, spectator permissions, topic updates, replay, death,
  cell transitions, disconnect cleanup, live voice relay, duplicate/stale voice
  rejection, unauthorized speech and transcript replay without voice data;
  standalone player/object `Say`, multi-line subtitles, no sender echo, range/cell
  filtering, server-held player positions and dead sender/recipient rejection.
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
- VoV: two rendered clients played a real Caius greeting and blue-keyword response
  through the native sound manager. Synthetic local dialogue checked a missing
  speaker file, a file available only to the speaker, a completely unvoiced
  response, WAV-to-MP3 fallback, stopping old speech, inert spectator clicks,
  leave/rejoin without replay, and new speech after rejoin. No missing-file audio
  errors appeared. Reopening history restored text only.
- With VoV and the synthetic dialogue plugin disabled on the initiator, the
  ordinary greeting and keyword response worked with zero shared voice events
  or audio-loading errors, including for a spectator with VoV installed.

Rendered automation used a disposable localhost Lua fixture and `ForceGreeting`
to open the real NPC window. Human playtesting additionally exercised normal use.

On 2026-11-12, two rendered protocol-14 clients in a disposable fixture displayed
matching standalone `Player->Say` subtitles using native Azura sound files.
The listener's sound manager confirmed successful playback of both intro lines
and positional NPC `Say`. A missing file still displayed its subtitle, with no
missing-file error on the receiving client. A standalone line during a shared
NPC conversation displayed once without changing the transcript or closing it.
These commands exercise the shrine speech path; a complete shrine quest playthrough
and reward/journal progression were not part of this smoke check.

## Complete Windows package checks

- Standard client, server, launcher, setup wizard, browser and INI importer built.
- Fresh package contains engine interface resources, CoreScripts and Lua-io2,
  and excludes personal settings, saves and Morrowind game data.
- All six executables and 47 DLLs pass the runtime import audit.
- Archive contents pass per-file SHA-256 verification. Packaged CoreScripts
  reaches `OnServerPostInit` on an isolated localhost server.
- Standard Qt tools pass Windows startup smoke checks using isolated settings.
  This verifies startup, not every wizard/browser interaction.
- The documented side-by-side migration preserves byte-identical configuration,
  custom scripts, server libraries, accounts and saves in disposable fixtures;
  the original installation remains untouched.

Run `./scripts/shared-dialogue/test-package.ps1 -PackagePath <windows-zip>` after
packaging. It creates disposable fixtures under the build directory. Native Qt
startup checks require a normal Windows desktop; first-run dialogs may appear
briefly and are closed by the test. No custom launcher or installer is shipped.

## Limits

- DLC quest coverage, all mods and all custom server scripts are not exhaustive.
- Windows x64 is the validated game platform; VR/Linux/macOS remain unvalidated.
- The translated `@topic#` code path is supported, but rendered tests used English.
- Service contents are not mirrored. Activity labels are English. Voice support
  covers native `Say` scripts, including the legacy VoV ESP; modern OpenMW Lua voice mods are not
  supported. Voice files are never supplied or transferred by this fork.
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
It also accepts `say0`, `saynext0`, `sayactor0` and `saymissing0` to exercise
player-targeted deity speech, a subsequent line, positional NPC speech and a
subtitle with unavailable audio. Replace the trailing digit with the sender's
player ID. Enable subtitles in the test clients; the fixture requires your own
Morrowind files for native voices.

Before gameplay changes or new platform releases, use copied campaign data to
check a fresh quest/journal update, forced choices, simultaneous activation,
services, custom scripts, death/teleport/disconnect and representative DLC quests.
Record the exact build and what was exercised.
