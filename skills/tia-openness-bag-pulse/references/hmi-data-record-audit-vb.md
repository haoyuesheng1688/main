# HMI Data Records, Audit Trail, And VB Readback

Use this reference when a TIA Portal V17 / TP1200 Comfort project uses `记录`
plus WinCC VB scripts to display archived data or operation logs on HMI screens.

## Verified Project Pattern

Verified on `2026-05-14` with project `三九-15`, HMI target `HMI_RT_2`
(`qiaofeng-hmi [TP1200 Comfort]`):

- Data record node: `记录 > 数据记录`
- Audit trail node: `记录 > 审计跟踪`
- Data screen: `C1_数据记录`
- Audit screen: `C2_操作日志`
- VB scripts: `ReadFile_DATA1`, `ReadFile_Audit`
- HMI tag table for archive display tags: `变量归档`

Openness can reliably export/import adjacent objects:

- `VBScriptFolder.VBScripts`
- `TagFolder.TagTables`
- `ScreenFolder.Screens`
- `Cycles`, `GraphicLists`, and `TextLists`

The data-record and audit-trail configuration pages are visible in TIA Portal,
but the verified V17 TP1200 Openness surface still does not expose a direct
public collection equivalent to `VBScriptFolder` or `TagFolder`. Treat the
record configuration itself as GUI-configurable, then close the loop through
export/import/readback of scripts, tags, screens, and HMI compile.

## `ReadFile_DATA1` Model

The project script reads:

```vb
Path = "\Storage Card USB\DATA1\DATA10.txt"
field = Split(field, vbCrLf)
field2 = Split(field2, vbTab)
```

It uses `PV_JF进风温度` as the time-axis row. Each archive text row is matched by
the first tab column, then the value is copied from `field2(2)` into arrays and
finally into `SmartTags`.

Current mapping after adding `进风温度P`:

| Archive variable | Display array | Screen tags |
| --- | --- | --- |
| `PV_JF进风温度` | `data_1` | `data_进风温度_1..15` |
| `PV_CF出风温度` | `data_2` | `data_出风温度_1..15` |
| `PV_GX高效压差` | `data_3` | `data_高效压差_1..15` |
| `PV_BD布袋压差` | `data_4` | `data_布袋压差_1..15` |
| `PV_ZT主塔压力` | `data_5` | `data_塔内压力_1..15` |
| `PV_LX离心雾化` | `data_6` | `data_雾化频率_1..15` |
| `PV_YF引风反馈` | `data_7` | `data_引风频率_1..15` |
| `PV_JF进风温度P` | `data_8` | `data_进风温度P_1..15` |

When adding another archive column, update all three HMI layers:

1. Record configuration row in `DATA1`: display name plus process tag.
2. Internal WString display tags in `变量归档`: `data_<name>_1..15`.
3. VB script arrays and `SmartTags` output.
4. C1 screen header and 15 output IOFields bound to the new display tags.

Do not assume the archive text rows are in the same order as the screen columns.
Match by archive variable name, as `ReadFile_DATA1` already does.

## `ReadFile_Audit` Model

The audit script reads:

```vb
Path = "\Storage Card USB\AuditTrail\AuditTrail0.txt"
field = Split(field, vbCrLf)
field2 = Split(field(i + startLines), vbTab)
```

It displays 15 rows per page:

- `Audit_编号1..15` from `field2(0)`
- `Audit_时间1..15` from `field2(1)`
- `Audit_用户1..15` from `field2(3)`
- `Audit_对象1..15` from `field2(4)`
- `Audit_描述1..15` from `field2(5)`

## Repeatable Verification

For this project, the helper scripts used were:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\export-hmi-screens-and-tags.ps1" -OutputRoot ".\tia_sanjiu_learning"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\add-data1-inlet-temp-p.ps1" -OutputRoot ".\tia_sanjiu_learning"
```

Final readback evidence:

- `变量归档` exported with 15 `data_进风温度P_*` tags.
- `ReadFile_DATA1` exported with `PV_JF进风温度P`, `data_8`, and
  `SmartTags("data_进风温度P_" & i)`.
- `C1_数据记录` exported with header `进风温度P` and 15 output IOFields.
- HMI compile result: `errors: 0; warnings: 63`.

## Encoding Rule

PowerShell 5.1 may read non-ASCII script literals as ANSI if the script has no
UTF-8 BOM. For scripts containing Chinese TIA object names, write the script as
UTF-8 with BOM before running it:

```powershell
$p = ".\scripts\add-data1-inlet-temp-p.ps1"
$t = Get-Content -LiteralPath $p -Raw -Encoding UTF8
Set-Content -LiteralPath $p -Value $t -Encoding UTF8
```
