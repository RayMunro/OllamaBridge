# Changelog

All notable changes to OllamaBridge are documented here.

## 1.3.0 (2026-09-26)

- Fixed LAN discovery finding no Ollama instances. The build script only signed the raw binary, not the assembled app bundle, so macOS couldn't seal `NSLocalNetworkUsageDescription` into the app's identity and every network scan silently failed. The whole bundle is now properly signed.
- Hardened local-IP detection to ignore link-local (169.254.x.x) addresses from idle interfaces, such as an unconnected Thunderbolt Bridge, which could otherwise point the scan at the wrong subnet.

If you're upgrading from an earlier build that hit the "no instances found" bug, run `tccutil reset LocalNetwork com.raymondmunro.ollamabridge` once so macOS re-prompts for Local Network permission cleanly.

## 1.2.0 (2026-09-11)

- Remote host no longer defaults to a placeholder IP; a fresh install starts empty and Start requires one to be set.
- Added local network discovery: click the magnifying-glass button next to Host to scan your Mac's subnet for Ollama servers (probes `/api/version` on port 11434) and pick one from the results.

## 1.1.0 (2026-09-11)

- Added a model picker: choose from models installed on the remote server, with refresh.
- Added deleting a model from the remote server, with confirmation.
- Shows the computed manifest path for the selected model, based on a configurable models directory.
- Added app branding: name and copyright shown prominently in the main window.
- Added a custom app icon.
- Packaged as a proper `.pkg` installer.

## 1.0.0 (2026-09-11)

First release. A macOS menu bar app that transparently proxies `localhost:11434` to a remote Ollama server on your network.

- Transparent TCP proxy: `localhost:11434` to a remote Ollama server on your LAN.
- Model management: list, pull (with live progress), delete.
- Remote version check.
- Menu bar quick access and full settings window.
- Launch at login.
