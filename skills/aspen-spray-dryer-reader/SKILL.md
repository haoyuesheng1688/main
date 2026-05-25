---
name: aspen-spray-dryer-reader
description: Attach to an already-open Aspen Plus desktop session on Windows, inspect the live Aspen UI, capture the current Aspen window, and read spray dryer values such as outlet temperature, inlet temperature, airflow, and related results from the visible model. Use when the user says Aspen is installed/open locally and asks to connect to Aspen, read current 雾化塔 or 喷雾塔 values, or pull numbers from the active Aspen results page without rebuilding the model.
---

# Aspen Spray Dryer Reader

Use this skill to read live values from an already-open Aspen Plus session, especially spray dryer data shown in the current desktop UI.

Assume Windows, PowerShell, and a user-visible Aspen Plus window. Prefer attaching to the existing UI session instead of opening a fresh Aspen instance.

## Workflow

1. Run [scripts/find_open_aspen_process.ps1](./scripts/find_open_aspen_process.ps1) to locate the visible Aspen window and capture its `ProcessName`, `Id`, and `MainWindowTitle`.
2. If multiple Aspen windows are open, prefer the one whose title matches the user's current model name.
3. Run [scripts/search_aspen_ui_text.ps1](./scripts/search_aspen_ui_text.ps1) to confirm the expected tree nodes or tabs exist, for example `DRYER`, `结果`, `流股结果`, `摘要`, `出风温度`, or user-provided equipment names.
4. If the target result is visible on screen, run [scripts/capture_aspen_window.ps1](./scripts/capture_aspen_window.ps1) and inspect the saved screenshot with the image viewer tool to read the numeric value directly from the current Aspen page.
5. Report the value with its exact unit and the visible source label, for example `出风温度 46.1982 C`.
6. If the value is not visible yet, use UI automation to select the relevant tree node or result tab first, then capture the window again.

## Quick Rules

- Treat the currently open Aspen UI as the source of truth when the user asks for the "current" value.
- Prefer reading visible labels such as `出风温度`, `汽相温度`, `出口温度`, `Outlet Temperature`, or stream result headings over inferring from nearby numbers.
- Quote the visible field name in the answer so the user knows exactly what was read.
- Keep the reply short when the user only asks for a single number.
- If Aspen shows warning banners like `结果含警告` or `尚未运行问题`, mention that status briefly after the numeric answer.

## Common Targets

- `DRYER` block result pages
- `流股结果` under the spray dryer block
- stream result tabs like `S6`, `S14`, `S34`, or the model's named exhaust stream
- right-side custom tables that summarize dryer inputs and outputs

## PowerShell Helpers

List visible Aspen windows:

```powershell
& ".\skills\aspen-spray-dryer-reader\scripts\find_open_aspen_process.ps1"
```

Search the current Aspen UI for useful labels:

```powershell
& ".\skills\aspen-spray-dryer-reader\scripts\search_aspen_ui_text.ps1" `
  -Terms DRYER,结果,流股结果,出风温度,汽相温度
```

Capture the active Aspen window to a PNG in the current workspace:

```powershell
& ".\skills\aspen-spray-dryer-reader\scripts\capture_aspen_window.ps1"
```

Capture a specific Aspen window to a custom path:

```powershell
& ".\skills\aspen-spray-dryer-reader\scripts\capture_aspen_window.ps1" `
  -ProcessId 24604 `
  -OutputPath ".\aspen_dryer_result.png"
```

## Fallback Strategy

If the UI does not expose the number cleanly:

1. Search for the exact result tab and select it with UI automation.
2. Capture a fresh screenshot and read the visible table.
3. Only if needed, fall back to Aspen COM or ROT inspection to locate the underlying file or live object.
4. Do not claim a value came from the live UI if it was actually read from a copied or reopened file.

## Deliverable

Return:

- the requested value
- the unit
- the visible field name or tab where it was found
- any brief warning state shown by Aspen that may affect trust in the result
