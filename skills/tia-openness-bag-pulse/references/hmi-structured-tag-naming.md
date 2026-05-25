# HMI Structured Tag Naming

Use this reference when HMI variables must be easy to find from the TIA Portal property pane. The goal is that a tag name immediately shows the PLC DB, component, and field.

## Naming Rule

Use this form:

```text
<PLC_DB>_<Component>_<Field>
```

Examples:

- `DB_Components_Heater01_ClickTrig`
- `DB_Components_Heater01_DoubleClickTime`
- `DB_ActivePopup_Heater01_ActiveID`
- `DB_ActivePopup_Fan01_CancelBtn`

Do not use generic names like `Sim_ActiveID` once the screen is meant to help an operator or engineer find the real data.

When the HMI tags must connect directly to PLC DB variables, read [hmi-plc-linked-tags.md](./hmi-plc-linked-tags.md). Structured names are the HMI-side names; PLC-linked tags additionally need `Connection` and `ControllerTag` links.

## Current Components

The verified popup simulation currently uses:

- `Valve01`
- `Heater01`
- `Fan01`

Add new component names only after checking the PLC DB member names or the user's screenshot.

## Current Fields

For `DB_Components_<Component>_*`:

- `ClickTrig`
- `DoubleClickTime`
- `Switch1`
- `RealValue1_Int`

For `DB_ActivePopup_<Component>_*`:

- `Visible`
- `ActiveID`
- `Confirmed`
- `ConfirmBtn`
- `CancelBtn`

`RealValue1_Int` is an Int-only simulation placeholder. Replace it with a true Real tag only after exporting a known-good Real HMI tag template from the target project.

## Script Pattern

Create or update structured internal HMI tags:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\import-popup-sim-int-tagset.ps1" -OutputRoot ".\tia_popup_touch_sim" -UseStructuredTagNames
```

If the project already contains a tag, skip it instead of deleting or overwriting it:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\import-popup-sim-int-tagset.ps1" -OutputRoot ".\tia_popup_touch_sim" -UseStructuredTagNames -SkipTagNames "DB_ActivePopup_Heater01_ActiveID"
```

Create the directly openable TP1200 runtime screen using those names:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\create-popup-sim-visual-screen.ps1" -OutputRoot ".\tia_popup_touch_sim" -ScreenName "Codex_Popup_Sim_Runtime_Named" -ScreenNumber 22 -ScreenWidth 1280 -ScreenHeight 740 -AsNormalScreen -BindIntSet -UseStructuredTagNames -FocusComponent Heater01
```

## Validation

After import, export and inspect the generated XML. The known-good read-back checks are:

- screen export contains `DB_ActivePopup_Heater01_ActiveID`
- screen export contains `DB_Components_Heater01_ClickTrig`
- screen export contains no old `Sim_ActiveID`
- HMI compile finishes with `errors: 0`

Warnings about HMI memory usage or timestamps were observed and are non-blocking when the compile summary still says `errors: 0`.
