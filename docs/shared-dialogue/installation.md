# Installation and upgrades

## Requirements

- **64-bit Windows**. A previous TES3MP installation is not required.
- Your own installed Morrowind game files and the server's required expansions/mods.
- Microsoft's [Visual C++ x64 Redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist), if not already installed.
- The same Shared Dialogue build on every client and the server.

Version 0.2.0 reports `0.8.1-shared-dialogue.2`, protocol **13**. VR, Linux and
macOS game builds have not been validated for this release.

## Fresh installation

1. Download `tes3mp-shared-dialogue-0.2.0-windows-x64.zip` from this fork's Releases
   page and extract the entire archive into a writable folder.
2. Run **openmw-wizard.exe** and select your existing Morrowind installation.
   This is the normal OpenMW/TES3MP setup wizard. Your game files stay separate.
3. Use **openmw-launcher.exe** to check game settings and enable the content
   required by your host, in the correct order.
4. Open **tes3mp-browser.exe** and connect to your host. For a direct connection,
   set the destination address and port in `tes3mp-client-default.cfg` and run
   **tes3mp.exe**. Existing user overrides take priority over defaults.

The complete package includes the normal client, server, launcher, wizard,
server browser, engine interface resources and CoreScripts. Morrowind's game
files and VoV are not included. The separate `sources.zip` is for developers;
players do not need to extract it.

## Upgrading an existing installation

Use a separate folder so new defaults cannot overwrite your existing files.
Supported base: **TES3MP 0.8.1 Windows x64** or an earlier Shared Dialogue build.

1. Close the old client, server and launchers. Keep the entire old installation
   as your backup. Back up **Documents\My Games\OpenMW** as well, because normal
   TES3MP installations share that user-settings location.
2. Extract the complete new ZIP into a **new folder**.
3. Copy your old installation's customized root `.cfg` files into the new folder,
   replacing the supplied defaults. Do not copy old executables, DLLs or
   `resources/version` over the new build.
4. **Hosts:** rename the new package's `server` folder to `server-stock`, then
   copy your complete old `server` folder into the new installation. This keeps
   the campaign, accounts, required mod list, custom scripts and server libraries
   together. If your `[Plugins] home` points elsewhere, keep that path and back up
   that server directory instead.
5. **Portable installations:** also copy the old `user` folder and
   `tes3mp-portable.txt`. Ordinary installations automatically reuse
   **Documents\My Games\OpenMW**; do not add a portable marker to those.
6. If your configuration uses relative game-data paths (such as `./Data Files`),
   copy those local game/mod folders too, or update their paths in the normal
   launcher/configuration to point to the existing files. Do not delete the old
   folder. Check the enabled mod list and server port before playing.
7. Have every player upgrade before connecting. Run the normal executables from
   the **new** installation.

Existing `.cfg` settings, scripts, accounts and saves are carried forward rather
than replaced by the bundled defaults. This is a normal folder-based TES3MP
installation; there is no custom installer, launcher or automatic migration.

Standard CoreScripts needs no changes. Custom scripts that rebuild dialogue-choice
packets from scratch need review; see [compatibility](configuration.md).

## Hosting

Run **tes3mp-server.exe**. The included CoreScripts defaults require Morrowind,
Tribunal and Bloodmoon, and listen on UDP **25565**. A fresh server's accounts
and campaign state are stored under `server/data`. Required content/checksums
are in `server/data/requiredDataFiles.json`; game rules are in `server/scripts`.

Join your own server using `localhost`. Other players need a reachable address;
internet hosting may require port forwarding and Windows Firewall access.
Existing hosts keep their existing configuration. See [configuration](configuration.md)
for the dialogue radius, configuration locations and script compatibility.

## Troubleshooting

- **Missing DLL:** extract the entire package. Install Microsoft's x64 runtime
  if Windows names `MSVCP140.dll` or `VCRUNTIME140.dll`; do not download loose DLLs.
- **Version mismatch:** update every player and the host from the same release.
- **Content mismatch:** match your host's game/mod versions and load order.
- **No automatic dialogue:** check the cell, NPC distance and other open menus;
  activate the NPC to join manually.
- **Unexpected radius:** existing explicit server settings still override the default.

## Rollback

Close the new client and server and return to the old installation. Restore the
backed-up user configuration if it changed. Keep all players and the host on
matching builds. A campaign played in the new folder has newer data there;
returning to the old server data rolls back that progress. Preserve a copy of
both before deciding which campaign state to keep.
