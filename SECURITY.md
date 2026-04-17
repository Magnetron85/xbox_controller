# Security Policy — xbox_controller

## Overview

`xbox_controller` is a local-only AutoHotkey v2 script that translates Xbox controller input into keyboard, mouse, and window-activation events on a single Windows workstation. It is intended for use in radiology reading rooms, including HIPAA-regulated environments.

## Data Handling

This tool:

- **Does not** transmit any data over the network. No outbound connections, no telemetry, no update checks.
- **Does not** read or write patient health information (PHI). It sees controller button state only.
- **Does not** capture or log keystrokes typed into PACS, PowerScribe, or any other application.
- **Does** read and write two files in the install directory:
  - Profile JSON files under `profiles/` (user-authored button mappings and preferences).
  - Optional debug logs if explicitly enabled in source.

## Software Supply Chain

This repository ships:

- AutoHotkey v2 source scripts (`.ahk`) — human-readable; no compiled binaries.
- JSON configuration files — plain text.
- Reference-only compiled v1 binaries under `ahk_v1_priors/` (not executed by this project).

Users are responsible for auditing the scripts before running them and for ensuring that the AutoHotkey v2 runtime itself is obtained from a trustworthy source (https://www.autohotkey.com/).

## Runtime Permissions

The script performs the following system interactions:

| Interaction | Purpose |
|---|---|
| `SendInput` / `Click` | Synthesize keyboard and mouse events to the active window |
| `WinActivate` | Bring a target window (e.g., InteleViewer, PowerScribe) to foreground |
| `SetCursorPos` | Move the mouse cursor in response to right-stick input |
| `XInputGetState` / `XInputSetState` | Read controller state and drive vibration |
| `GetWindowRect` (via AHK built-ins) | Position the HUD overlay |

No administrative privileges are requested. The script runs under the normal user account.

## Vulnerability Disclosure

To report a security issue, please open a private GitHub Security Advisory on this repository, or email the maintainer. Please do not disclose details in public issues until a fix is available.

## Scope

This project does not claim compliance with HIPAA, SOC 2, or any other regulatory framework. Organizations deploying it in clinical environments are responsible for their own risk assessment, including whether AutoHotkey scripts are permitted by local IT policy.
