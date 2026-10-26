TES3MP Shared Dialogue - source and build materials

engine/ contains the complete source snapshot used for this local package,
including documentation and build scripts. SOURCE-MANIFEST.json records every
file's SHA-256. BUILD-INFO.json in the matching binary ZIP identifies its Git
base revision and whether unpublished working-tree edits were included.

dependency-archives/ contains the original source archives for the rebuilt
FFmpeg, OpenSceneGraph, OpenAL Soft and their image/font dependencies. None of
their runtime source files was patched. Their build options and installation
layout are recorded in engine/scripts/shared-dialogue/build-media-dependencies.ps1
and build-ffmpeg.sh; generated FFmpeg configuration is under build-records/.

The archive also includes the pinned CrabNet and LuaJIT sources, RecastNavigation,
and the upstream version sources of the unchanged permissively licensed Boost,
Bullet, MyGUI, SDL2 and LZ4 dependencies. Their original binary-input hashes remain
in dependencies.json. Build tools and Microsoft system/compiler runtimes are not
part of the distributed game libraries. The MSYS Make download is a build tool
only; its pinned hash and URL are in source-archives.json.

For normal builds, use a Git checkout of this fork and follow
engine/docs/shared-dialogue/building.md. Copy these dependency archives into that
checkout's deps/downloads to reuse them instead of downloading them again.
The build still fetches the pinned permissive binary inputs and Git sources.
If building solely from engine/, initialize a local Git repository first; client
and server built from that checkout must share their generated resources/version.
Replacing a shared library does not require changing TES3MP's version file.

Publish this source ZIP alongside both binary ZIPs and SHA256SUMS.txt on the same
release page. Preserve the archive and matching sources when mirroring binaries.
See engine/THIRD-PARTY-NOTICES.md for attribution and complete license texts.
No Morrowind game data, campaign data, accounts or personal configuration is included.
