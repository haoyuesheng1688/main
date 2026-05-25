# HMI Advanced Objects Through Openness

Use this reference for TP1200 Comfort / WinCC Comfort HMI objects under these project-tree nodes:

- `HMI 变量`
- `HMI 报警`
- `记录`
- `脚本 > VB 脚本`
- `计划任务`
- `周期`
- `文本和图形列表`

## Verified V17 Openness Surface

On `2026-05-13`, against project `VIP-TEST-3-弹框` and HMI target `HMI_RT_1`, the following `HmiTarget` properties were directly visible through Openness:

- `TagFolder`
- `VBScriptFolder`
- `Cycles`
- `TextLists`
- `GraphicLists`
- `ScreenFolder`
- `ScreenPopupFolder`
- `Connections`

These collections expose `Find(name)` and `Import(FileInfo, ImportOptions)`. Their individual objects expose `Export(FileInfo, ExportOptions)`.

## Verified Import/Export Loops

The following objects were imported, exported, read back, and accepted by HMI compile:

- Cycle: `Codex_Cycle_3s`
  - Export contains `<CycleTime>3</CycleTime>`
  - Export contains `<CycleUnit>Second</CycleUnit>`
- Text list: `Codex_TextList_Status`
  - Value `0` maps to `停止`
  - Value `1` maps to `运行`
- Graphic list: `Codex_GraphicList_Empty`
  - Empty graphic list import/export succeeds
  - Use this as the base object before adding graphic resources
- VB script: `Codex_VBFunction_Loop`
  - The XML `<Name>` must match the tree function name.
  - TIA stores only the function body in `<Code>`; the editor generates `Sub <Name>()`.
- HMI tag table: `Codex_VBS_Loop_Tags`
  - Contains `Codex_VBS_Input` and `Codex_VBS_Output`
  - Both are internal `WString` tags used by the VB script

Compile evidence:

```text
CompileState=Success
Compiling finished (errors: 0; warnings: 0)
```

## Assets

Use these templates:

- `assets/hmi-advanced-templates/Codex_Cycle_3s.xml`
- `assets/hmi-advanced-templates/Codex_TextList_Status.xml`
- `assets/hmi-advanced-templates/Codex_GraphicList_Empty.xml`
- `assets/hmi-advanced-templates/Codex_VBFunction_Loop.xml`
- `assets/hmi-advanced-templates/Codex_VBS_Tags.xml`

Use this script for a repeatable export/import/compile check:

- `scripts/invoke-hmi-advanced-loop.ps1`

## VB Script Name Rule

For VB functions, keep these names identical:

- Project tree name under `脚本 > VB 脚本`
- XML `<Name>`
- Generated editor header `Sub <Name>()`

Do not put an explicit `Sub ... End Sub` wrapper inside XML `<Code>` for exported/imported TIA V17 VB functions. The `<Code>` section should contain only the function body. TIA uses `<Name>` and `<Type>Sub</Type>` to generate the visible header and footer.

If `SmartTags("SomeTag")` is red-underlined, first verify the HMI tag exists. The `Codex_VBS_Loop_Tags.xml` template fixes this for the loop tags.

## Records, Alarms, And Scheduled Tasks

In this tested TIA V17 TP1200 Comfort project, Openness did not expose direct collection properties for:

- data records / data logs (`记录 > 数据记录`)
- alarm records (`记录 > 报警记录`)
- scheduled tasks (`计划任务`)

The DLL contains logging and alarm enum types, but no public `HmiTarget` composition similar to `Cycles`, `TextLists`, or `VBScriptFolder` was found. Treat these nodes as GUI-configurable / compile-verifiable in V17 unless a project-specific API surface is discovered.

When a request targets these nodes:

1. State that they are visible in TIA but not directly exposed by the verified V17 Openness object model.
2. Export and verify the adjacent script, tag, cycle, text-list, and graphic-list objects through Openness.
3. If the user needs records/alarms/tasks changed, use TIA UI operation or a manually exported Siemens XML sample from the exact project as the starting point, then re-test import/export.

## Minimal API Pattern

```powershell
$hmi.Cycles.Import([System.IO.FileInfo]'Codex_Cycle_3s.xml', [Siemens.Engineering.ImportOptions]::Override)
$cycle = $hmi.Cycles.Find('Codex_Cycle_3s')
$cycle.Export([System.IO.FileInfo]'Codex_Cycle_3s_export.xml', [Siemens.Engineering.ExportOptions]::WithDefaults)

$hmi.TextLists.Import([System.IO.FileInfo]'Codex_TextList_Status.xml', [Siemens.Engineering.ImportOptions]::Override)
$textList = $hmi.TextLists.Find('Codex_TextList_Status')

$hmi.GraphicLists.Import([System.IO.FileInfo]'Codex_GraphicList_Empty.xml', [Siemens.Engineering.ImportOptions]::Override)
$graphicList = $hmi.GraphicLists.Find('Codex_GraphicList_Empty')

$hmi.VBScriptFolder.VBScripts.Import([System.IO.FileInfo]'Codex_VBFunction_Loop.xml', [Siemens.Engineering.ImportOptions]::Override)
$vb = $hmi.VBScriptFolder.VBScripts.Find('Codex_VBFunction_Loop')
```

Compile the HMI target after import:

```powershell
$compile = $hmi.GetType().GetMethods() |
  Where-Object { $_.Name -eq 'GetService' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 0 } |
  Select-Object -First 1

$provider = $compile.MakeGenericMethod([Siemens.Engineering.Compiler.ICompilable]).Invoke($hmi, @())
$result = $provider.Compile()
$result.State
```
