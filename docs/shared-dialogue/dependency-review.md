# Dependency sources and builds

The Windows build uses pinned dependency inputs and packages matching source
materials with each release. These recipes target TES3MP 0.8.1 / OpenMW 0.47.0.

## Current build

| Component | Pinned source | Configuration |
| --- | --- | --- |
| FFmpeg | 4.4.8 | Shared MSVC libraries; GPL, version3, nonfree and automatic external-library detection disabled; zlib explicitly enabled |
| OpenSceneGraph / OpenThreads | 3.6.5, `af2cd9b52653500022c157e4ee6304776d0cc866` | Shared libraries; BMP, DDS, FreeType, JPEG, OSG, PNG, TGA and core serializers retained |
| OpenAL Soft | 1.20.1, `f5e0eef34db3a3ab94b61a2f99f84f078ba947e7` | Shared library; utilities, examples and optional SDL/PortAudio backends disabled |
| Image/font helpers | zlib 1.3.2, libpng 1.6.58, libjpeg-turbo 3.2.0, FreeType 2.14.1 | Shared libraries; external FreeType dependencies disabled; JPEG SIMD disabled |

No runtime source patches were applied to these archives. FFmpeg retains the
library major versions used by this engine. Programs, networking, filters,
encoders, muxers, hardware acceleration and external assembly are disabled;
the game uses decoding, audio resampling and video conversion. FreeType's own
bundled code and its licenses remain in its source archive and copied notices.

The complete build options live in
[`build-media-dependencies.ps1`](../../scripts/shared-dialogue/build-media-dependencies.ps1)
and [`build-ffmpeg.sh`](../../scripts/shared-dialogue/build-ffmpeg.sh).
Every source archive and the build-only MSYS Make download has a SHA-256 in
[`source-archives.json`](../../scripts/shared-dialogue/source-archives.json).
Downloads and extraction stay under the selected dependency directory.

FFmpeg's official release signature was verified with fingerprint
`FCF986EA15E6E293A5644F10B4322F04D67658D8`. The
[signature](licenses/ffmpeg-4.4.8.tar.gz.asc) and
[release public key](licenses/ffmpeg-release-key.asc) are retained. Routine
fetching verifies the pinned archive hash.

Boost, Bullet, MyGUI, SDL2 and LZ4 retain their original hash-pinned permissive
binary inputs. Their upstream version sources are also collected in the source
bundle via [`source-supplements.json`](../../scripts/shared-dialogue/source-supplements.json).
CrabNet and LuaJIT are built from their pinned Git revisions. RecastNavigation
uses the revision already pinned by the engine. This does not claim byte-for-byte
reconstruction of the unchanged prebuilt permissive libraries.

## Runtime and source packaging

The explicit runtime list contains 33 DLLs, including eight OSG plugins.
The import audit checks both engine
executables and every selected DLL, rejecting unresolved dependencies. Windows
system libraries and Microsoft's Visual C++ x64 runtime are listed separately
as prerequisites. Dynamic plugin loading is additionally exercised by tests.

`package.ps1` creates both upgrade ZIPs, a matching source ZIP and SHA256SUMS.
The source ZIP contains the complete current engine snapshot, original dependency
source archives, build recipes, generated FFmpeg configuration and runtime import
report. It records per-file hashes; each binary ZIP records the source ZIP's hash.
Local working-tree edits are included and disclosed in build metadata. Final
public packages should be regenerated from the reviewed release commit.

The source ZIP must accompany the binary ZIPs on the same release page. Keep
those files together when mirroring a release. GitHub's automatic source download
alone does not include the dependency source archives.

Game files used for local validation are excluded from all packages. See
[testing status](testing.md) for coverage and limits, and
[third-party notices](../../THIRD-PARTY-NOTICES.md) for licenses and attribution.

References: [FFmpeg's distribution guidance](https://ffmpeg.org/legal.html),
[FFmpeg Windows build documentation](https://ffmpeg.org/platform.html),
[OpenSceneGraph source](https://github.com/openscenegraph/OpenSceneGraph),
[TES3MP license](../../LICENSE).
