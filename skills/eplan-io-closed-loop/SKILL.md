---
name: eplan-io-closed-loop
description: Connect to an already open EPLAN Electric P8 project on Windows, discover the active project, export a read-only PLC IO point list, and summarize the closed-loop input/output map as CSV and text. Use when the user asks to connect to EPLAN, Electric P8, a live EPLAN project, or wants PLC IO points, IO closure, module/address listings, or a reusable export workflow.
---

# EPLAN IO Closed Loop

Use this skill to turn a live EPLAN Electric P8 session into a repeatable IO export workflow without mutating the project.

Assume Windows, PowerShell, and an already open EPLAN project. Prefer a read-only offline DataModel session for extraction. Do not edit the live project unless the user explicitly asks for modifications.

## Workflow

1. Confirm that an `EPLAN` process is open.
2. Resolve the active project path from the EPLAN main window title.
3. Run the read-only export script in a child `powershell.exe -STA` process.
4. Produce `eplan_io_points.csv` and `eplan_io_summary.txt` in the requested output directory.
5. Report module counts, direction counts, and a few representative points.

## Bundled Scripts

- `scripts/find-open-eplan-project.ps1`
  Resolve the active `.elk` file from the open EPLAN window title. Use this first when the user says EPLAN is already open.
- `scripts/export-eplan-io.ps1`
  Open the project through the EPLAN offline API in read-only mode and export the PLC IO list.
- `scripts/run-open-project-io-export.ps1`
  Wrapper that finds the project, passes paths through environment variables, and launches the export script in a child STA PowerShell process.

## Default Command

Run this when the user simply wants the current project's IO list:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\skills\eplan-io-closed-loop\scripts\run-open-project-io-export.ps1" -OutputDir "C:\path\to\output"
```

If the project path is already known, pass it explicitly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\skills\eplan-io-closed-loop\scripts\run-open-project-io-export.ps1" -ProjectPath "C:\Projects\Example.elk" -OutputDir "C:\path\to\output"
```

## Output Files

- `eplan_io_points.csv`
  One row per PLC IO point with module type, PLC box, terminal, address, symbolic address, data type, function text, and page.
- `eplan_io_summary.txt`
  Project path, output path, PLC box count, IO point count, direction counts, and module-kind counts.
- `eplan_io_error.txt`
  Present only when the export script throws.

## Important Rules

- Keep the extraction read-only. Use `ProjectManager.OpenMode.ReadOnly`.
- Set `LockProjectByDefault = $false` before opening the project.
- Pass `EPLAN_PROJECT_PATH` and `EPLAN_OUTPUT_DIR` through environment variables before launching the child script.
- Use the child `powershell.exe -STA` wrapper even if the parent shell is already PowerShell. This avoids fragile hosting differences.
- Treat the export as successful when the CSV and summary exist, even if the child process returns a non-zero exit code. The EPLAN API host can return odd process codes after a successful export.
- Expect Chinese project paths. Avoid hardcoding them directly inside `.ps1` source when a wrapper can pass them through environment variables.

## Interpretation Rules

- Infer `Direction` from module prefix when EPLAN leaves `PLCIOENTRY_DIRECTION` empty:
  - `AI`, `DI` => `Input`
  - `AQ`, `DQ` => `Output`
- Trim internal formatting prefixes from `FunctionText` by keeping only the content after the last `@` and removing the trailing `;`.
- Treat `ConnectionEndpoints` and `ExternalConnections` as optional enrichment only. In many projects, EPLAN exposes the PLC addresses but not explicit field-side closure through these APIs.

## What To Report

Include:

- project path
- generated file paths
- PLC box count
- IO point count
- counts by `AI`, `AQ`, `DI`, `DQ`
- counts by `Input` and `Output`
- a few representative points such as `I0.0`, `Q0.0`, `IW0+`, or `QW0+`

If the user asks for a field-device closed loop and the CSV has empty `ConnectionEndpoints`, say that the module/address/function loop is exported successfully, but field-side source/target closure is not exposed by this project through the current API path.
