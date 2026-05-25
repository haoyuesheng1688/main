# A0-cursor-tia-vip2-归档-日志

This folder contains the reusable TIA Portal V17 / TP1200 Comfort archive-log
skill package copied from the verified local Codex skill.

## Layout

- `skills/tia-openness-bag-pulse/`
  - Reusable Codex skill entrypoint, scripts, assets, and references.
  - Start from `SKILL.md`.
- `knowledge/tia_sanjiu_learning/`
  - Project-specific learning snapshot from project `三九-15`.
  - Includes exported HMI tag tables, VB scripts, screens, import XML, verify XML,
    and compile/readback logs.

## Important References

- `skills/tia-openness-bag-pulse/references/hmi-data-record-audit-vb.md`
  - Data record, audit trail, `ReadFile_DATA1`, `ReadFile_Audit`, and
    C1/C2 screen knowledge.
- `skills/tia-openness-bag-pulse/references/hmi-advanced-objects.md`
  - V17 Openness surface for VB scripts, cycles, text lists, graphic lists,
    tag tables, and the known boundary around records/alarm records/tasks.

## Verified Scripts

Use these from a PowerShell session while the target TIA Portal V17 project is
already open:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\skills\tia-openness-bag-pulse\scripts\export-hmi-screens-and-tags.ps1" -OutputRoot ".\knowledge\tia_sanjiu_learning"

powershell -NoProfile -ExecutionPolicy Bypass -File ".\skills\tia-openness-bag-pulse\scripts\add-data1-inlet-temp-p.ps1" -OutputRoot ".\knowledge\tia_sanjiu_learning"
```

The second script is the verified example for adding `进风温度P` to:

- `变量归档` display tags: `data_进风温度P_1..15`
- `ReadFile_DATA1`: `PV_JF进风温度P -> data_8 -> SmartTags`
- `C1_数据记录`: header plus 15 output IOFields

The verified compile result on `三九-15` was:

```text
Compiling finished (errors: 0; warnings: 63)
```

## Notes

- This is a local copy only. It has not been uploaded to GitHub.
- Copy was performed as copy-only: the original source skill and knowledge
  folders were not moved or deleted.
- For Chinese object names in PowerShell 5.1 scripts, keep script files encoded
  as UTF-8 with BOM.
