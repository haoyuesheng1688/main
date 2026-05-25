# WinCC RT Professional Script Snapshot And Compile

Use this reference when the open TIA Portal V17 project contains a PC station
with `WinCC RT Professional`, for example device `HMI-5X`, instead of a
Comfort panel such as TP1200.

## Verified Project

Verified on `2026-05-14`:

- Project: `赛奥5-last16_20260507M2`
- Path: `H:\程序优化\S4-弹窗\A3-赛奥5-高手\8赛奥5-last16_20260507M2\赛奥5-last16_20260507M2.ap17`
- HMI device: `HMI-5X`
- Station type visible in the device view: `SIMATIC PC station`
- Runtime type visible in the device view: `WinCC RT Prof`

## Important Difference From TP1200

Do not assume the TP1200 Comfort Openness surface applies to RT Professional.

For TP1200 Comfort, `DeviceItem.GetService[SoftwareContainer]()` exposed an
`Siemens.Engineering.Hmi.HmiTarget` with:

- `VBScriptFolder`
- `TagFolder`
- `ScreenFolder`
- `Cycles`
- `TextLists`
- `GraphicLists`

For the verified `HMI-5X` WinCC RT Professional project, probing `Project`,
`Device`, and `DeviceItem` services found:

- `HMI-5X` exposes `Siemens.Engineering.Compiler.ICompilable`
- `HMI-5X` did not expose `HmiTarget`
- `HMI-5X` did not expose `VBScriptFolder`
- `HMI-5X` did not expose `TagFolder`
- `SIMATIC PC station/Stationmanager` exposes `ICompilable`

That means normal TP1200 XML import/export for `VBScriptFolder.VBScripts` is
not available through the verified V17 Openness object model for this RT Pro
project.

## Where Scripts Appear In The Project Folder

The project contains compiled/runtime script artifacts under:

```text
IM\HMI\R\0\D\HMI_HWS3\
```

Useful subfolders/files:

- `ScriptLib\*.bmo`: compiled script modules
- `ScriptAct\*.bac`: compiled script actions/tasks
- `Config\USEDVBSMODULES.CVB`: module usage list

Verified module list:

- `Alarm_Auto_CSV.bmo`
- `Audit_3Day_CSV.bmo`
- `Audit_Auto_CSV.bmo`
- `Audit_Write.bmo`
- `Create_SQL.bmo`
- `DATA_Auto_CSV.bmo`
- `ExecuteSQL.bmo`
- `GetAuditBackList.bmo`
- `MSF1_CSV.bmo`
- `MSF1_Load.bmo`
- `MSF2_3day_back.bmo`
- `MSF2_CSV.bmo`
- `MSF2_Load.bmo`
- `SQL_Back.bmo`

Verified action/task files:

- `Auto_back.bac`
- `Task_1.bac`
- `数据库备份.bac`

These files are binary or compiled RT Pro modules. Text extraction can reveal
some names and fragments, but not reliable editable VB source. Treat them as a
snapshot/export evidence format, not as source code to patch by hand.

## Verification Commands

From a workspace containing the helper scripts:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\export-rtpro-script-snapshot.ps1" -OutputRoot ".\tia_rtpro_learning"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\compile-rtpro-hmi-device.ps1" -OutputRoot ".\tia_rtpro_learning" -DeviceName "HMI-5X"
```

The snapshot script copies `ScriptLib`, `ScriptAct`, and `Config` artifacts and
records SHA256 hashes for closed-loop evidence.

Compile evidence from the verified project:

```text
CompileDevice=HMI-5X|Siemens.Engineering.HW.DeviceImpl
CompileState=Success
```

PowerShell may report a warning while reading empty compile-result messages:

```text
CompileMessagesReadWarning=Access to a disposed object ...
```

This is a message enumeration issue after compile, not a compile failure, as
long as `CompileState=Success` is present.

## Practical Rule

For RT Professional:

1. Use Openness to verify project attachment, device tree, service surface, and
   `HMI-5X` compile.
2. Use project-folder snapshots to export compiled script artifacts.
3. Do not import TP1200-style `Hmi.VBScript.Script` XML into RT Pro unless a
   project-specific `VBScriptFolder` is actually discovered.
4. For source-level script editing, use the TIA UI script editor or a verified
   RT Pro source export mechanism from the exact project.
