# Installation and rollback

## Requirements

- An existing TES3MP **0.8.1 Windows x64** installation.
- Your own Morrowind game files and the server's required content/mod list.
- The same Shared Dialogue build on every client and the server.
- Microsoft's [Visual C++ v14 x64 Redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist).
  Use the current x64 installer if Windows reports a missing `MSVCP140.dll` or
  `VCRUNTIME140.dll`. It may already be installed on your machine.

Version 0.1.0 reports `0.8.1-shared-dialogue.1`, protocol **12**. Other TES3MP
versions, VR, Linux and macOS game builds have not been validated for this release.

## Joining players

1. Close TES3MP and back up the installation you are upgrading.
2. Download the **client** ZIP from this fork's Releases page.
3. Extract it beside `tes3mp.exe`. Replace the supplied files and preserve their
   subfolders, including `osgPlugins-3.6.5` when included. Do not copy only the
   executable from a bundle that also supplies DLLs. Also replace the supplied
   `resources/version` file; it is part of TES3MP's connection compatibility check.
4. Start TES3MP normally and connect to the matching server.

Joining players do not need to run or update a server.
The separate `sources.zip` contains development and redistribution materials;
players do not need to extract it to play.

## Host

1. Stop the server and client. Back up the installation and server `data`
   directory, including campaign and player accounts.
2. Extract the **client-server** ZIP into that installation.
3. Keep the existing server scripts, accounts, saves, content list and connection
   settings. The upgrade does not replace them.
4. Review the optional `[Dialogue]` radius setting and restart the server.
5. Have every player upgrade before connecting.

Standard CoreScripts needs no changes. Custom scripts that rebuild dialogue-choice
packets from scratch need review; see [compatibility](configuration.md).

## Using the feature

Stand near the same NPC and let one player activate them. Nearby available players
become listeners. Only the speaker can select topics, answer questions or open
services. Listeners can Leave at any time and activate the same NPC to catch up
while the conversation is still active. History ends with the session; it is not
a permanent dialogue log.

## Troubleshooting

- **Missing DLL:** extract the entire matching package. Do not download individual
  DLLs from unrelated DLL sites.
- **Version mismatch:** update the host and every client together.
- **No automatic window:** check cell, NPC distance and open menus. Try activating
  the NPC manually.
- **Unexpected range:** explicit server settings override the default. Restart
  the server after changing them.
- **Custom script failure:** report the script version, NPC, topic and reproduction
  steps without uploading passwords or account data.

## Rollback

Stop both programs and restore the backed-up installation, including its original
executables and libraries. Keep the group on matching builds. Restore campaign
data only if you also intend to undo progress made since that backup. The feature
does not introduce a new saved transcript format in campaign data.
