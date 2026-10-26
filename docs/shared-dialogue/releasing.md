# Preparing a public release

Release packages are generated locally from the source checkout using the
[pinned dependency recipes](dependency-review.md). The scripts do not push
commits, create tags or upload files.

## First GitHub publication

1. Create a fork of `TES3MP/TES3MP` named **tes3mp-shared-dialogue** in the intended
   account. Keep the existing upstream history.
2. Add the new fork as `origin` in this checkout. `upstream` refers to TES3MP.
3. Push the reviewed `0.8.1` branch to the fork and make it the default branch.
   There is no need to open an upstream pull request or copy the outer workspace.
4. Enable Issues and Actions on the fork. Check the first hosted workflow result.
5. Set the description to "Shared NPC conversations for TES3MP, with live
   spectator dialogue, visible topics, and conversation history."
6. Check the README's relative Releases link after publication.

## Generate local packages

After the [build and tests](building.md):

```powershell
./scripts/shared-dialogue/check-repository.ps1
./scripts/shared-dialogue/package.ps1
```

Outputs go to `dist/release`:

- `tes3mp-shared-dialogue-0.1.0-windows-x64-client.zip`
- `tes3mp-shared-dialogue-0.1.0-windows-x64-client-server.zip`
- `tes3mp-shared-dialogue-0.1.0-sources.zip`
- `SHA256SUMS.txt`

The script audits runtime imports, verifies source downloads, packages the full
current source snapshot, and checks every ZIP entry against its source file.
Each binary ZIP contains installation instructions, notices, a file manifest,
`BUILD-INFO.json` and the runtime dependency report. Extra JSON/text files beside
the ZIPs are local inspection copies of this metadata.

`-Candidate` instead writes binaries with a candidate suffix under
`dist/candidates`. Both modes produce matching source materials and remain local.

## Publish the reviewed release

1. Review and commit the intended source/documentation changes. Update
   `scripts/shared-dialogue/release.json`, the version header, changelog and
   compatibility notes together if the version changes. The first intended tag
   is `sd-v0.1.0`.
2. Rebuild from that exact clean commit and regenerate the packages. This makes
   `resources/version` and build metadata identify the release commit. Run
   repository checks, session/packet tests, the live fixture and runtime tests;
   complete the relevant rendered checks in [testing.md](testing.md).
3. Review the package inventory. Game assets, accounts, saves, personal configs,
   logs, portable markers and development-only binaries must remain excluded.
   Test upgrading a copy of a supported installation and restoring its backup.
4. Create the annotated tag and publish as a prerelease initially. State the
   Windows x64 target, TES3MP base, matching-client/server requirement and known
   limitations. Hosted CI must be checked separately; local tests do not prove
   that the GitHub workflow passed.
5. Attach **all three ZIPs and SHA256SUMS.txt** to that same release. The source
   ZIP is part of the distribution; GitHub's automatic source archives do not
   replace it. Preserve the pairing when mirroring downloads.
6. Include this notice near binary downloads, linking the actual source asset:
   "This software uses FFmpeg under the LGPLv2.1 or later. Matching FFmpeg and
   other dependency sources are included in this release's sources.zip."

Players only need their appropriate binary ZIP. The source ZIP is provided for
developers and redistribution; it is not extracted into a player's installation.
