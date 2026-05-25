# HMI PLC-Linked Tags

Use this reference when HMI tags should connect directly to PLC DB variables instead of staying as internal HMI variables.

## Verified Pattern

The verified XML pattern for a PLC-linked HMI tag is:

```xml
<Connection TargetID="@OpenLink">
  <Name>HMI_连接_1</Name>
</Connection>
<ControllerTag TargetID="@OpenLink">
  <Name>DB_ActivePopup.Valve01.Visible</Name>
</ControllerTag>
```

In the TIA Portal variable table this appears as:

- connection: `HMI_连接_1`
- PLC name: `PLC_1`
- PLC variable: `DB_ActivePopup.Valve01.Visible`

## Current Popup Mapping

PLC-linked `DB_Components` fields:

- `DB_Components.<Component>.ClickTrig` -> `Bool`
- `DB_Components.<Component>.Switch[1]` -> `Bool`
- `DB_Components.<Component>.RealValue[1]` -> `Real`

PLC-linked `DB_ActivePopup` fields:

- `DB_ActivePopup.<Component>.Visible` -> `Bool`
- `DB_ActivePopup.<Component>.ActiveID` -> `Int`
- `DB_ActivePopup.<Component>.Confirmed` -> `Bool`
- `DB_ActivePopup.<Component>.ConfirmBtn` -> `Bool`
- `DB_ActivePopup.<Component>.CancelBtn` -> `Bool`

Known components: `Valve01`, `Heater01`, `Fan01`.

## Boundary

`DB_Components.<Component>.DoubleClickTime` does not exist in the exported `DB_Components` PLC DB. Keep `DB_Components_<Component>_DoubleClickTime` as an internal HMI helper unless the PLC DB is changed.

The older `DB_Components_<Component>_RealValue1_Int` tag is only an Int placeholder for screens that still use integer simulation. The PLC-linked Real tag is `DB_Components_<Component>_RealValue1`, connected to `DB_Components.<Component>.RealValue[1]`.

## Safe Import Sequence

Always export the current table before replacing it:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\export-hmi-tag-table.ps1" -OutputRoot ".\tia_popup_touch_sim" -TagTableName "Codex_Popup_PLC_Named_Int_Tags"
```

Then replace the generated table with PLC-linked tags:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\import-popup-plc-linked-tagset.ps1" -OutputRoot ".\tia_popup_touch_sim" -TagTableName "Codex_Popup_PLC_Named_Int_Tags" -ConnectionName "HMI_连接_1" -ReplaceExistingTable -SkipTagNames "DB_ActivePopup_Heater01_ActiveID"
```

`-ReplaceExistingTable` backs up the existing table to `exports\<TagTableName>_before_replace.xml`, deletes the generated table, then imports the new table.

Use `-SkipTagNames` for tags already created in another table such as `默认变量表`. In the verified project, `DB_ActivePopup_Heater01_ActiveID` already existed in `默认变量表`, so it had to be skipped.

## Validation

After import, check the exported table:

- `Connection` count was `23`
- `ControllerTag` count was `23`
- exported table contains `DB_ActivePopup.Valve01.Visible`
- exported table contains `DB_Components.Heater01.ClickTrig`
- exported table intentionally does not contain `DB_ActivePopup_Heater01_ActiveID` if it was skipped because it exists in `默认变量表`

Compile result from the verified run:

```text
ProjectName=VIP-TEST-3-弹框
HmiTarget=HMI_RT_1
CompileState=Warning
Compiling finished (errors: 0; warnings: 2)
ProjectSaved=True
```
