---
name: tia-openness-bag-pulse
description: Use when working in an open Siemens TIA Portal V17 project through Openness, especially for SCL bag pulse logic, PLC/HMI tag tables, TP1200 screens or popup screens, WinCC VB scripts, cycles, text lists, graphic lists, data records, alarm records, scheduled tasks, structured HMI tag naming, import/export loops, compile checks, or repeatable skill packaging.
---

# TIA Openness Bag Pulse

Use this skill to turn a user request like "connect to TIA and build a bag pulse dust collector", "create a TP1200 button and a popup screen", or "verify HMI VB script/cycle/text-list import and export" into a repeatable Openness workflow.

Assume the work happens on Windows with PowerShell, an already-open TIA Portal session, and a CPU that supports SCL blocks. Prefer creating new blocks and tag tables over mutating unrelated existing logic.

## Workflow

1. Inspect the local Openness environment.
2. Attach to the open TIA Portal process.
3. Discover the target project, PLC software object, existing blocks, and existing tag tables.
4. Generate or update the SCL source files in the current workspace.
5. Import the source into TIA with Openness, creating blocks, DBs, HMI screens, HMI popup screens, VB scripts, cycles, text lists, graphic lists, or HMI tag tables.
6. Create or update the PLC tag table for field IO and status words.
7. Compile the generated PLC blocks when PLC logic changed.
8. Export generated HMI objects or PLC blocks for verification.
9. Save the project.
10. Report what was created, what addresses were used, and whether OB1/Main or HMI screens were changed.

## Quick Rules

- Prefer `C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.dll` when V17 is installed. If V17 is missing, search under `C:\Program Files\Siemens\Automation\Portal*` for `Siemens.Engineering.dll` and use the newest matching PublicAPI version.
- Use PowerShell and load the DLL with `Add-Type -Path`.
- Enumerate TIA processes with `[Siemens.Engineering.TiaPortal]::GetProcesses()`.
- Attach to an existing UI session instead of opening a new hidden TIA process when the user says Portal is already open.
- Find PLC software through `DeviceItem.GetService[SoftwareContainer]()` rather than assuming the PLC sits at a fixed device-item depth.
- Prefer adding new blocks with distinct names such as `FB_BagPulseDustCollector`, `DB_BagPulseDustCollector`, `DB_BagPulseDustCollector_IO`, and `FC_BagPulseDustCollector_IO`.
- Compile newly generated blocks first. Then compile the PLC software object to confirm the whole software tree is clean.
- Save the TIA project after a successful compile.

## Default Deliverable

Unless the user asks for a different structure, generate these objects:

- `FB_BagPulseDustCollector`: the reusable core SCL FB
- `DB_BagPulseDustCollector`: instance DB for the FB
- `DB_BagPulseDustCollector_IO`: parameter and status DB for HMI/operator tuning
- `FC_BagPulseDustCollector_IO`: IO wrapper that maps field signals to the FB and writes outputs/status back out
- `Main` or `OB1`: call the IO wrapper only when safe to do so

Keep the core behavior conservative:

- Default `BagCount := 4`
- Make `PulseTime`, `ValveInterval`, and `CyclePause` adjustable
- Support manual pulse and pressure-difference requests
- Support enabled-bag selection and optional per-bag pulse time

Read [references/default-io-map.md](./references/default-io-map.md) when the user does not provide an IO list and you need a ready-made closed loop.
Read [references/tia-v17-shortcuts.md](./references/tia-v17-shortcuts.md) when the user asks for TIA Portal V17 shortcuts or when keyboard-driven UI navigation is faster than hunting through menus.
Read [references/hmi-screen-popup-import.md](./references/hmi-screen-popup-import.md) when the user asks to create or verify TP1200/HMI screens, simple buttons, popup screens, or HMI XML import/export through Openness.
Read [references/hmi-structured-tag-naming.md](./references/hmi-structured-tag-naming.md) when HMI variable names must be easy to trace from the property pane back to PLC DBs, for example `DB_ActivePopup_Heater01_ActiveID`.
Read [references/hmi-plc-linked-tags.md](./references/hmi-plc-linked-tags.md) when HMI tags should be moved from internal variables to direct PLC-linked variables with `Connection` and `ControllerTag`, for example `DB_ActivePopup.Valve01.Visible`.
Read [references/hmi-popup-sim-800x800.md](./references/hmi-popup-sim-800x800.md) when the user asks to continue the `HMI弹窗 [FB1]` / `DB_Components` / `DB_ActivePopup` popup simulation, create an 800x800 popup, bind internal Int HMI tags, add button `SetTag` actions, or verify the known-good `Codex_Popup_Sim_800x800_IO2` workflow.
Read [references/hmi-advanced-objects.md](./references/hmi-advanced-objects.md) when the user asks about VB script import/export, HMI tag-table fixes for SmartTags, cycles, text lists, graphic lists, data records, alarm records, scheduled tasks, or the `记录` / `计划任务` / `周期` / `文本和图形列表` nodes.
Read [references/hmi-data-record-audit-vb.md](./references/hmi-data-record-audit-vb.md) when the user asks to learn, verify, or extend data records, operation logs, audit trails, `ReadFile_DATA1`, `ReadFile_Audit`, or archive-display screens such as `C1_数据记录` / `C2_操作日志`.
Read [references/wincc-rt-professional-scripts.md](./references/wincc-rt-professional-scripts.md) when the user mentions WinCC RT Professional, RT Prof, PC station, `HMI-5X`, `ScriptLib`, `.bmo`, `.bac`, `USEDVBSMODULES.CVB`, or upper-computer/HMI scripts that do not expose TP1200-style `HmiTarget`.
Read [references/wincc-rtpro-data-record-vb.md](./references/wincc-rtpro-data-record-vb.md) when a WinCC RT Professional data-record page such as `D2_数据记录` must add or verify a VB-driven archive field such as `环境检测 -> PV_HJ环境氧浓度检测`. For RT Professional source edits, default to the manual body-file handoff: generate `full` and `body_only` files for the user to paste between the fixed `Sub ...()` and `End Sub` skeleton lines.

## Safe Edit Policy For Main/OB1

- Inspect existing `Main`/`OB1` first.
- If OB1 is empty or effectively empty, replacing it with a simple SCL caller is acceptable.
- If OB1 contains real user logic, do not overwrite it silently.
- In a populated OB1, prefer one of these:
  - export the block first and preserve a backup in the workspace
  - add a single new FC/FB call if you can do it without disturbing existing logic
  - otherwise stop short of OB1 mutation and tell the user the generated caller block is ready to be inserted

Report explicitly whether `Main`/`OB1` was changed.

## PowerShell Pattern

Use short inspection commands first:

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'Portal|Siemens|TIA' }
Get-ChildItem -Path 'C:\Program Files\Siemens' -Recurse -Filter Siemens.Engineering.dll -ErrorAction SilentlyContinue
```

When attaching through Openness, use a helper like this:

```powershell
$dll = 'C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.dll'
Add-Type -Path $dll
$process = [Siemens.Engineering.TiaPortal]::GetProcesses() | Select-Object -First 1
$tia = $process.Attach()
```

For PLC discovery, prefer a recursive walk over device items and a reflected generic `GetService` helper when PowerShell has trouble calling the generic method directly.

## Block Import Pattern

Generate source files in the current workspace, then import them through `ExternalSourceGroup`.

Recommended source files:

- `BagPulseDustCollector_OpennessImport.scl`: core FB, instance DB, IO DB, IO wrapper FC
- `Main_Call_BagPulseDustCollector.scl`: optional OB1/Main caller

Recommended sequence:

1. Create or find the external source.
2. Call `GenerateBlocksFromSource(KeepOnError)`.
3. Compile the generated blocks individually.
4. Compile the PLC software object.

If block export fails because blocks are inconsistent, compile first and retry export only if you actually need the export.

Read [references/generated-objects.md](./references/generated-objects.md) when you need the default block naming and responsibility split.

## Tag Table Pattern

Create a dedicated PLC tag table, for example `BagPulseDustCollector_IO`, and keep the IO mapping there. Avoid mixing these tags into the default system clock tag table.

Use the default map from [references/default-io-map.md](./references/default-io-map.md) unless the user supplies a plant-specific address list.

If the target project already uses those addresses, stop and ask for the actual IO allocation instead of guessing.

## HMI Screen Pattern

For TP1200 or HMI requests, find `Siemens.Engineering.Hmi.HmiTarget` through the HMI device item's `SoftwareContainer`. Use `ScreenFolder.Screens` for normal screens and `ScreenPopupFolder.ScreenPopups` for popup screens.

Use XML import for simple generated HMI objects:

- `assets/hmi-screen-templates/hmi_import_Codex_Button_Test.xml`: normal screen with one button
- `assets/hmi-screen-templates/hmi_import_Codex_Popup_500x500.xml`: 500x500 popup screen

After import, export the new HMI screen or popup to verify that the object exists and that key attributes such as `Width`, `Height`, and the button object name are present.

For the verified `HMI弹窗 [FB1]` simulation, use these scripts in order:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\import-popup-sim-int-tagset.ps1" -OutputRoot ".\tia_popup_touch_sim"
powershell -ExecutionPolicy Bypass -File ".\scripts\create-popup-sim-visual-screen.ps1" -OutputRoot ".\tia_popup_touch_sim" -ScreenName "Codex_Popup_Sim_800x800_IO2" -BindIntSet
powershell -ExecutionPolicy Bypass -File ".\scripts\create-popup-sim-visual-screen.ps1" -OutputRoot ".\tia_popup_touch_sim" -ScreenName "Codex_Popup_Sim_Runtime" -ScreenNumber 21 -ScreenWidth 1280 -ScreenHeight 740 -AsNormalScreen -BindIntSet
powershell -ExecutionPolicy Bypass -File ".\scripts\import-popup-sim-int-tagset.ps1" -OutputRoot ".\tia_popup_touch_sim" -UseStructuredTagNames -SkipTagNames "DB_ActivePopup_Heater01_ActiveID"
powershell -ExecutionPolicy Bypass -File ".\scripts\create-popup-sim-visual-screen.ps1" -OutputRoot ".\tia_popup_touch_sim" -ScreenName "Codex_Popup_Sim_Runtime_Named" -ScreenNumber 22 -ScreenWidth 1280 -ScreenHeight 740 -AsNormalScreen -BindIntSet -UseStructuredTagNames -FocusComponent Heater01
powershell -ExecutionPolicy Bypass -File ".\scripts\compile-current-hmi-target.ps1" -OutputRoot ".\tia_popup_touch_sim"
```

For TP1200, do not import an `800 x 800` object as a normal screen. Import it as `Hmi.Screen.ScreenPopup` through `ScreenPopupFolder.ScreenPopups`.
If runtime interaction needs a directly openable normal screen, use `1280 x 740` with `-AsNormalScreen`; this target rejected both `800 x 800` and `1280 x 800` normal-screen imports.
For traceable HMI tag names, use `-UseStructuredTagNames`. The naming pattern is `DB_Components_<Component>_<Field>` and `DB_ActivePopup_<Component>_<Field>`, for example `DB_ActivePopup_Heater01_ActiveID`. If the project already contains a manually created tag, pass it through `-SkipTagNames` and keep the existing object.
To connect generated HMI tags directly to PLC DB variables, use `scripts/import-popup-plc-linked-tagset.ps1`. It adds `Connection` and `ControllerTag` links, preserves `DoubleClickTime` as an internal helper because the exported PLC DB has no matching member, and can skip tags already created in `默认变量表`.

## HMI Structured Naming Pattern

Use structured names once the basic import path is stable and the user needs to find data from the HMI property pane.

- Component-side inputs: `DB_Components_<Component>_<Field>`, such as `DB_Components_Heater01_ClickTrig`
- Popup/status outputs: `DB_ActivePopup_<Component>_<Field>`, such as `DB_ActivePopup_Heater01_ActiveID`
- Known components in the current popup simulation: `Valve01`, `Heater01`, `Fan01`
- If a tag already exists, preserve it with `-SkipTagNames`; do not delete or overwrite manually created tags.

Read [references/hmi-structured-tag-naming.md](./references/hmi-structured-tag-naming.md) before adding component names or mapping the screen to real PLC DB members.

## HMI PLC-Linked Tag Pattern

Use this after structured naming is stable and the user wants the HMI variable table to show a PLC connection like `HMI_连接_1`, `PLC_1`, and `DB_ActivePopup.Valve01.Visible`.

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\export-hmi-tag-table.ps1" -OutputRoot ".\tia_popup_touch_sim" -TagTableName "Codex_Popup_PLC_Named_Int_Tags"
powershell -ExecutionPolicy Bypass -File ".\scripts\import-popup-plc-linked-tagset.ps1" -OutputRoot ".\tia_popup_touch_sim" -TagTableName "Codex_Popup_PLC_Named_Int_Tags" -ConnectionName "HMI_连接_1" -ReplaceExistingTable -SkipTagNames "DB_ActivePopup_Heater01_ActiveID"
powershell -ExecutionPolicy Bypass -File ".\scripts\compile-current-hmi-target.ps1" -OutputRoot ".\tia_popup_touch_sim"
```

Read [references/hmi-plc-linked-tags.md](./references/hmi-plc-linked-tags.md) before changing PLC-linked field mappings or adding Real/String links.

## HMI Advanced Object Pattern

For HMI VB scripts, cycles, text lists, graphic lists, and internal tag tables, use the bundled templates under `assets/hmi-advanced-templates` and the repeatable validation script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\invoke-hmi-advanced-loop.ps1"
```

In V17 TP1200 Comfort testing, Openness exposed `Cycles`, `TextLists`, `GraphicLists`, `TagFolder`, and `VBScriptFolder`, but did not expose direct collections for data records, alarm records, or scheduled tasks. For those nodes, document the boundary clearly and use GUI/manual XML samples if the user needs direct edits.

For projects where data records and audit trails are displayed by VB scripts, use `references/hmi-data-record-audit-vb.md`. The verified `三九-15` pattern is: configure the record row in TIA GUI, then close the loop through `变量归档` HMI display tags, `ReadFile_DATA1` SmartTags, C1 screen IOFields, exported readback, and HMI compile.

For WinCC RT Professional PC-station projects, use `references/wincc-rt-professional-scripts.md`. The verified `HMI-5X` pattern is different from TP1200: Openness exposed device compile but not `HmiTarget`/`VBScriptFolder`; script artifacts were found as compiled `ScriptLib/*.bmo`, `ScriptAct/*.bac`, and `Config/USEDVBSMODULES.CVB` under the project folder.

For WinCC RT Professional data-record field checks, use `scripts/verify-rtpro-data-record-field.ps1`. It reads the `.\WINCC` SQL databases and confirms the archive row, LT data-logging mapping, display HMI tags, D2 screen row, and VB module list without editing compiled `.bmo` files.

For RT Professional VB source-level changes when Openness does not expose `VBScriptFolder`, do not default to automatic keyboard delete/paste. Use `scripts/new-rtpro-vb-manual-fill-files.ps1` to generate a complete review file and a `body_only` file, then provide clickable links for manual paste into the TIA editor. Automatic editor-control scripts are experimental and should only run with single-step user confirmation.

## Validation

After generation:

1. Compile `FB_BagPulseDustCollector`
2. Compile `DB_BagPulseDustCollector`
3. Compile `DB_BagPulseDustCollector_IO`
4. Compile `FC_BagPulseDustCollector_IO`
5. Compile the whole PLC software object
6. Compile the HMI target when HMI objects changed
7. Save the project

In the final report, include:

- project name
- PLC software name
- blocks created or updated
- tag table created or updated
- whether `Main`/`OB1` changed
- compile result summary
- HMI compile result summary when HMI objects changed
- any assumptions, especially IO addresses

## What To Avoid

- Do not overwrite a populated `Main`/`OB1` without checking it first.
- Do not reuse `%M0` and `%M1` clock bytes for status words.
- Do not assume the project contains no existing bag pulse logic; inspect existing FB/FC/DB names first.
- Do not claim the work is complete until the PLC software compile passes.




