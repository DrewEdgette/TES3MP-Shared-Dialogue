# Building on Windows x64

A normal checkout contains everything specific to this fork. No sibling checkout,
existing runtime ZIP, Morrowind installation or account data is needed to compile
or run the automated tests. Outputs stay inside the checkout by default.

## Prerequisites

Install these tools yourself before running the scripts:

- Windows x64 and PowerShell 5.1 or 7.
- Visual Studio 2022, any edition including Build Tools, with **Desktop development
  with C++** and a Windows SDK. Scripts discover it through `vswhere`.
- CMake **3.27.x**, Git for Windows (including its bundled Bash), curl, Windows
  `tar.exe` and 7-Zip. Git, CMake, curl and tar must be on PATH.

The legacy CMake project is not validated with CMake 4. Scripts do not install
tools or change persistent machine settings.
FFmpeg's makefiles require a path without spaces. Use a checkout path without
spaces, or an NTFS volume with working short names; the build script resolves
short paths automatically. It stops with an explanation if neither is available.

## Build and test

Run from the repository root:

```powershell
./scripts/shared-dialogue/fetch-dependencies.ps1
./scripts/shared-dialogue/build-dependencies.ps1 -Jobs 4
./scripts/shared-dialogue/build.ps1 -Jobs 4
./scripts/shared-dialogue/test.ps1 -Jobs 4
```

The manifests pin SHA-256 hashes and source revisions. Downloads are cached in
`deps/downloads`. Hash mismatches or tracked Git dependency edits stop fetching.
Boost's archive is unpacked with innoextract; its installer is not run.

The dependency build compiles FFmpeg, OpenSceneGraph, OpenAL Soft, zlib, libpng,
libjpeg-turbo and FreeType from source into `deps/built`. A pinned MSYS Make
executable runs through Git's existing Bash runtime; no MSYS installation is
required. Other dependencies retain the original pinned inputs. The initial
dependency build takes longer than subsequent incremental builds. Keep extracted
source trees unmodified when creating releases; use a fresh dependency directory
after changing source versions or experimenting with dependency patches.

Executables appear in `build-shared-dialogue/Release`. Dependencies live in `deps`
and temporary files in the build directory. Lower `-Jobs` if memory is limited.
Scripts accept `-DependenciesPath` and `-BuildPath` for explicitly chosen paths;
use the same paths across commands. Do not reuse a CMake directory belonging to
another source checkout.

## Local runtime and packages

```powershell
./scripts/shared-dialogue/stage-runtime.ps1
./scripts/shared-dialogue/package.ps1
```

The runtime is isolated under `build-shared-dialogue/runtime`, with a portable
marker and no game data. Supply your own copied game files and configure this
runtime manually for rendered testing. Automated tests do not need them.
`stage-runtime.ps1 -RuntimePath <path>` can stage another disposable runtime.

Packaging writes two Windows upgrade ZIPs, a matching source ZIP and checksums
under `dist/release`. The explicit runtime file list excludes settings, saves,
game assets, portable markers and debug plugins/symbols. The source ZIP also
collects supplementary dependency source archives, so its first generation may
download several hundred megabytes. `-Candidate` uses `dist/candidates` instead.
See [release preparation](releasing.md) for the source materials that must
accompany binary downloads. No script uploads files or creates releases.

## CI

The Windows workflow runs these same build and test commands and uploads test
logs, not binaries. A lightweight Linux job checks renderer-independent sessions;
that does not validate the complete Linux game. The first hosted workflow run
occurs after pushing to GitHub; local verification does not establish a hosted pass.
