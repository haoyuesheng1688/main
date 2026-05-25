---
name: excel-psychrometric-tool
description: Build or refresh an Excel moist-air calculator workbook that derives the remaining psychrometric properties from any two independent inputs among air temperature, relative humidity, humidity ratio, and dew point temperature. Use when the user asks for an Excel tool, workbook, macro, or template for humid-air calculations, especially on Windows with desktop Excel already open and with requirements like red input cells, green output cells, calculation buttons, or reusable workbook automation.
---

# Excel Psychrometric Tool

Use this skill to create a macro-enabled Excel workbook for quick moist-air calculations.

Assume Windows, PowerShell, and desktop Excel. Prefer creating or refreshing a workbook in the current workspace and leaving it open for the user.

## Workflow

1. Confirm that Excel is already running when the user says it is open. If needed, attach to the active Excel instance.
2. Run [scripts/build_excel_psychrometric_tool.ps1](./scripts/build_excel_psychrometric_tool.ps1) to create or refresh the workbook.
3. Save the workbook as `psychrometric_air_tool.xlsm` in the current workspace unless the user asks for a different path or name.
4. Leave the workbook open in Excel.
5. Verify the calculator with one known case, then clear the sheet and save it blank.

## Quick Rules

- Use the bundled PowerShell script instead of rebuilding the workbook logic by hand.
- Use standard atmospheric pressure `101.325 kPa`.
- Use these units:
  - air temperature: `deg C`
  - relative humidity: `%`
  - humidity ratio: `g/kg dry air`
  - dew point temperature: `deg C`
- Mark direct user inputs red and calculated outputs green.
- Provide `Calculate` and `Clear` buttons in the workbook.
- Keep the calculator behavior conservative and explicit when inputs are inconsistent.

## Important Limitation

Do not claim that every pair of inputs is enough. `Humidity ratio + dew point temperature` are both vapor-pressure information, so they do not uniquely determine air temperature and relative humidity. The workbook should explain this and show a prompt instead of inventing values.

## Script Usage

Run the bundled script from the current workspace:

```powershell
& ".\skills\excel-psychrometric-tool\scripts\build_excel_psychrometric_tool.ps1"
```

To override the workbook location:

```powershell
& ".\skills\excel-psychrometric-tool\scripts\build_excel_psychrometric_tool.ps1" -OutputPath ".\custom_name.xlsm"
```

## Validation

After creating the workbook, verify one known case before handing it off:

1. Enter `25` for air temperature.
2. Enter `50` for relative humidity.
3. Run the calculate macro.
4. Expect approximately:
   - humidity ratio: `9.86 g/kg dry air`
   - dew point: `13.86 deg C`
5. Confirm the two entered cells are red and the two calculated cells are green.
6. Run the clear macro and save the workbook blank.

## Deliverable

Report the workbook path, whether Excel was already open, the verification result, and the `humidity ratio + dew point` limitation.
