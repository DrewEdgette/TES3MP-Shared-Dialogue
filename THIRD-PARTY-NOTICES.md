# Third-party notices

TES3MP Shared Dialogue is a modified TES3MP/OpenMW engine. The original [LICENSE](LICENSE),
[authors](AUTHORS.md), [TES3MP credits](tes3mp-credits.md) and source notices are
retained. The project does not claim ownership of upstream code or game assets.

## Dependency inventory

The build's archive hashes and Git revisions are recorded in
[`dependencies.json`](scripts/shared-dialogue/dependencies.json) and
[`source-archives.json`](scripts/shared-dialogue/source-archives.json).
The Windows release builds FFmpeg, OpenSceneGraph, OpenAL Soft and their
image/font dependencies from the pinned source archives.

| Dependency | Version/source | License information |
| --- | --- | --- |
| Boost | 1.71.0, vc142 Windows libraries | [Boost Software License 1.0](docs/shared-dialogue/licenses/Boost.txt) |
| Bullet | 2.89, double-precision Windows build | [zlib-style license](docs/shared-dialogue/licenses/Bullet.txt) |
| CrabNet / RakNet | Pinned TES3MP revision | [BSD-style license](docs/shared-dialogue/licenses/CrabNet.txt) |
| LuaJIT / Lua | Pinned LuaJIT revision | [MIT notices](docs/shared-dialogue/licenses/LuaJIT.txt) |
| LZ4 | 1.9.2 library | [BSD 2-clause](docs/shared-dialogue/licenses/LZ4.txt) |
| MyGUI | 3.4.0 | [MIT](docs/shared-dialogue/licenses/MyGUI-MIT.txt) |
| OpenSceneGraph / OpenThreads | 3.6.5 | [OpenSceneGraph Public License / LGPL terms](docs/shared-dialogue/licenses/OpenSceneGraph.txt) |
| SDL2 | 2.0.12 | [zlib license](docs/shared-dialogue/licenses/SDL2.txt) |
| OpenAL Soft | 1.20.1 | [LGPL](docs/shared-dialogue/licenses/OpenAL-Soft.txt) |
| FFmpeg | 4.4.8, shared libraries; GPL, version3 and nonfree options disabled | [LGPLv2.1](docs/shared-dialogue/licenses/FFmpeg-LGPLv2.1.txt), [upstream license overview](docs/shared-dialogue/licenses/FFmpeg-LICENSE.md) |
| zlib | 1.3.2 | [zlib license](docs/shared-dialogue/licenses/zlib.txt) |
| libpng | 1.6.58 | [PNG Reference Library License](docs/shared-dialogue/licenses/libpng.txt) |
| libjpeg-turbo | 3.2.0, SIMD disabled | [BSD/IJG notices](docs/shared-dialogue/licenses/libjpeg-turbo-LICENSE.md), [IJG README](docs/shared-dialogue/licenses/README.ijg) |
| FreeType | 2.14.1, under the FreeType License | [FTL](docs/shared-dialogue/licenses/FreeType-FTL.txt), [included component notices](docs/shared-dialogue/licenses/FreeType-components.txt) |
| RecastNavigation / Detour | `e75adf86f91eb3082220085e42dda62679f9a3ea` | [zlib-style license](docs/shared-dialogue/licenses/RecastNavigation.txt) |
| osg-ffmpeg-videoplayer | Included upstream source | [MIT](docs/shared-dialogue/licenses/osg-ffmpeg-videoplayer.txt) |
| OpenMW input control, LuaBridge, PicoSHA2, Base64 | Included upstream source | [Embedded MIT notices](docs/shared-dialogue/licenses/embedded-components.txt) |

CoreScripts and Lua-io2/sol2 are used for the isolated local development runtime;
upgrade ZIPs do not replace the player's existing server scripts or those modules.
Their licenses remain in the pinned source checkouts. innoextract and MSYS Make
are build tools only and are not shipped in upgrade ZIPs. Font licenses remain in `files/mygui`;
upgrade packages retain the installed engine resources instead of bundling fonts.

This software uses libraries from the [FFmpeg project](https://ffmpeg.org) under
the LGPLv2.1 or later. The matching unmodified source and build configuration
are included in the release's `sources.zip` archive. The engine's own license
remains unchanged.

Portions of this software are copyright © 1996-2025 The FreeType Project
(https://freetype.org). All rights reserved. FreeType also includes BDF/PCF,
HarfBuzz-derived code and bundled zlib code; their notices are preserved.

This software is based in part on the work of the Independent JPEG Group.
No changes were made to the IJG-derived files in FFmpeg or libjpeg-turbo.

## Source and build materials

Publish `tes3mp-shared-dialogue-0.1.0-sources.zip` alongside the two binary ZIPs
and `SHA256SUMS.txt` on the same release page. It contains the current engine
source, the complete archives for rebuilt dependencies, pinned CrabNet/LuaJIT
sources, supplementary sources for the unchanged permissive dependencies, and
build recipes/configuration. Each binary package identifies its source archive
and hash in `BUILD-INFO.json`.

The source bundle retains the original files and embedded notices. The
supplementary Boost/Bullet/MyGUI/SDL2/LZ4 archives identify their upstream version
sources; these libraries still use the original hash-pinned prebuilt inputs.
They are not claimed to be newly rebuilt or byte-for-byte reproducible here.

Microsoft's Visual C++ runtime is a prerequisite, obtained through Microsoft's
redistributable installer. It and Windows system libraries are identified
separately in `RUNTIME-DEPENDENCIES.json` and are not bundled.

See the [dependency build details](docs/shared-dialogue/dependency-review.md) and
[release procedure](docs/shared-dialogue/releasing.md).
