# Shared Dialogue changelog

## 0.1.0 — first public release candidate

Based on TES3MP 0.8.1 / OpenMW 0.47.0, commit
`49be5b6405d6ab427e06ed350cf76c715a1f3bdd`.

- Server-owned NPC sessions with exclusive speaker authority.
- Nearby same-cell spectator invitations, default radius 420 from the NPC.
- Full resolved history, passive answer choices and service status.
- Leave and manual rejoin with history replay.
- Blue noninteractive keywords and a scrollable mirrored topic list.
- Ownership checks on executable dialogue-choice packets.
- Cleanup on goodbye, death, cell changes and disconnect.
- Bounded state/packets with automated regression coverage.
- Optional portable mode and documented Windows build/package workflows.
- Source-built FFmpeg 4.4.8, OpenSceneGraph 3.6.5 and OpenAL Soft 1.20.1,
  with pinned image/font dependencies, runtime import checks, matching source
  archives and reproducible build instructions for release packaging.

Reported version: `0.8.1-shared-dialogue.1`. Protocol: **12**.

Upstream history: [TES3MP](../../tes3mp-changelog.md), [OpenMW](../../CHANGELOG.md).
