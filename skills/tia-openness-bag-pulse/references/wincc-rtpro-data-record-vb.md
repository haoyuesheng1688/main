# WinCC RT Professional Data Record Fields And VB Display Loop

Use this reference for WinCC RT Professional projects where the data-record page
is driven by VB scripts and SQL/CSV archive data, for example screen
`D2_数据记录`, archive `DATA1`, and script modules such as `DATA_Auto_CSV.bmo`.

## Environment Detection Field Pattern

For the field shown as `环境检测`, the intended mapping is:

- Archive: `DATA1`
- Record variable display name: `环境检测`
- Process variable: `PV_HJ环境氧浓度检测`
- `DATA_Auto_CSV` SQL/export tag list: `TagName(9) = "DATA1\环境检测"`
- D2 display tag prefix: `data_环境检测_1..15` or the plant-standard equivalent
- VB script layer: the DATA read/export script must add this field as one more
  archive column and copy the parsed value into the matching display tags.

## Required Closed Loop

Do not treat a visible row in the TIA grid as complete until these layers match:

1. `PDE#TAGs` contains `DATA1 / 环境检测 / PV_HJ环境氧浓度检测`.
2. `HmiDataLoggingTag` contains the corresponding data-logging mapping.
3. `HmiTag` contains the display output tags, normally 15 WString tags for the
   visible rows.
4. `D2_数据记录` has a header and IOFields bound to the display tags.
5. The active VB script module, usually `DATA_Auto_CSV.bmo` or the project
   equivalent, parses the archive row by variable name and writes the 15 display
   tags.
6. HMI compile returns `CompileState=Success`.

For a `DATA_Auto_CSV` script shaped like:

```vb
Dim TagName(8),iLen
TagName(0) = "DATA1\进风温度"
...
TagName(8) = "DATA1\露点温度"
```

extend the array and append the field:

```vb
Dim TagName(9),iLen
TagName(9) = "DATA1\环境检测"
```

Do not forget the dimension change. If the line is appended while the array
stays `Dim TagName(8)`, the script will fail or silently skip the new element.

The useful diagnostic is that these layers can drift. In one verified RT Pro
case, a transient WinCC database contained `DATA1 / 环境检测`, but after compile
the current runtime metadata reverted to nine DATA1 fields and had no
`data_环境...` display tags. Treat that as incomplete and re-open the TIA UI
record/script editor rather than patching `.bmo` files directly.

## Verification Script

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\verify-rtpro-data-record-field.ps1" `
  -ArchiveName "DATA1" `
  -FieldName "环境检测" `
  -ProcessTag "PV_HJ环境氧浓度检测" `
  -DisplayTagPrefix "data_环境检测" `
  -ScreenName "D2_数据记录"
```

The script is read-only. It queries the local `.\WINCC` SQL instance and writes:

```text
logs\verify_rtpro_data_record_field.txt
```

## Safe Editing Boundary

RT Professional script files under `ScriptLib/*.bmo` are compiled artifacts.
Do not binary-patch them. Use the TIA/WinCC script editor or a verified project-
specific source export mechanism for source-level VB edits.

For WinCC RT Professional, the default source-edit handoff is manual body files,
not fully automatic paste/delete. The RT Pro VB editor has generated skeleton
lines:

```vb
Sub DATA_Auto_CSV()
...
End Sub
```

The first `Sub ...()` line and the final `End Sub` line are protected. If a
selection includes either line, delete or paste may fail silently or paste in
the wrong place. Treat these two lines as fixed editor-owned skeleton text.

### Recommended Manual Body Handoff

Use this when the user can manually paste into the already-open RT Pro VB editor
and wants a reliable link to the edited source.

1. Copy the current editor source and save it as evidence.
2. Generate two files:
   - `*_full_*.vbs`: complete source for review.
   - `*_body_only_*.vbs`: only the text between `Sub ...()` and `End Sub`.
3. Give the user clickable links to both files.
4. Ask the user to delete only the body between the two fixed skeleton lines,
   then paste the `body_only` file content.
5. After the user confirms, copy the editor source again and verify:
   - exactly one `Sub DATA_Auto_CSV()`
   - exactly one `End Sub`
   - body does not contain another `Sub` or `End Sub`
   - expected lines such as `Dim TagName(9),iLen` and
     `TagName(9) = "DATA1\环境检测"` exist.

Generate the handoff files with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\new-rtpro-vb-manual-fill-files.ps1" `
  -SourcePath ".\tia_rtpro_learning\exports\rtpro_vb_find_delete_body\DATA_Auto_CSV_original_current_YYYYMMDD_HHMMSS.vbs" `
  -OutputRoot ".\tia_rtpro_learning" `
  -ScriptName "DATA_Auto_CSV" `
  -AddEnvironmentField
```

The `body_only` file is the safe payload for manual paste. It intentionally does
not contain `Sub DATA_Auto_CSV()` or `End Sub`.

### Automatic UI Editing Is Not The Default

Earlier keyboard-driven attempts showed these failure modes:

- copying `__empty__` because focus was not in the editor
- selecting only a short fragment instead of the full body
- inserting the new body into `SmartTags("last_back_date") = DTP2`, producing
  broken text such as `SmartTa'提示` or a stray `s("last_back_date") = DTP2`
- duplicating body content when the current editor text was already modified

Because of these risks, only run automatic delete/paste scripts when the user
explicitly asks for automation and agrees to single-step verification. After
every step, stop and wait for confirmation if the user asks for manual control.

### Field Change Pattern

When no Openness `VBScriptFolder` exists and the user wants to add the
environment field to `DATA_Auto_CSV`, the intended text change is only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\invoke-rtpro-vb-body-export-patch-import.ps1" `
  -ScriptName "DATA_Auto_CSV" `
  -OldDim "Dim TagName(8),iLen" `
  -NewDim "Dim TagName(9),iLen" `
  -AfterLine 'TagName(8) = "DATA1\露点温度"' `
  -InsertLine 'TagName(9) = "DATA1\环境检测"'
```

Do not change the SQL/export logic unless the existing project-specific script
requires it. The loop already uses `iLen = UBound(TagName)` and `For i = 0 To
iLen`, so extending the `TagName` array is enough for the CSV query/title list
pattern shown in this project.

The old automatic scripts are retained only as experimental helpers. Prefer the
manual file handoff above for RT Professional source edits.

If using the built-in Find/Replace panel, use it for selection only. Do not rely
on the Replace box for multi-line body content. A safer conceptual pattern is:

```text
Find/select:
(?s)(Sub\s+DATA_Auto_CSV\(\)\s*\r?\n)(.*?)(\r?\nEnd\s+Sub)

Then manually ensure the selected area excludes group 1 and group 3, press
Delete, and paste the body-only file content.
```

When editing the VB script manually, prefer matching archive rows by process
variable name instead of depending on column order. Add the environment field as
a new named mapping:

```vb
' Conceptual pattern only; adapt to the project's existing variable names.
If field2(0) = "PV_HJ环境氧浓度检测" Then
    data_env(rowIndex) = field2(2)
End If

SmartTags("data_环境检测_" & i) = data_env(i)
```

Keep the script function/sub name exactly the same as the object name shown in
the project tree when creating or replacing a VB function.





