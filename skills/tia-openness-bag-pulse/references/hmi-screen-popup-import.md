# HMI Screen And Popup Import

Use this reference when creating TP1200 or WinCC HMI screens through TIA Openness.

## Target Object

Load both API assemblies:

```powershell
Add-Type -Path 'C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.dll'
Add-Type -Path 'C:\Program Files\Siemens\Automation\Portal V17\PublicAPI\V17\Siemens.Engineering.Hmi.dll'
```

Find the HMI target through the HMI device item's `SoftwareContainer`. The expected software type is:

```text
Siemens.Engineering.Hmi.HmiTarget
```

For the verified TP1200 project, the HMI target was `HMI_RT_1`.

## Collections

- Normal screens: `hmi.ScreenFolder.Screens`
- Popup screens: `hmi.ScreenPopupFolder.ScreenPopups`
- Screen templates: `hmi.ScreenTemplateFolder.ScreenTemplates`

Use `Import(FileInfo, ImportOptions.Override)` with Simatic ML XML files.

## Verified Workflow

1. Attach to the open TIA process by project path.
2. Locate `HmiTarget`.
3. Check current screen and popup counts.
4. Import normal screen XML into `ScreenFolder.Screens`.
5. Import popup XML into `ScreenPopupFolder.ScreenPopups`.
6. Save the project.
7. Export the newly created screen and popup to verify creation.

## Verified Objects

This workflow was verified by creating:

- Normal screen: `Codex_Button_Test`
  - Contains button object `Codex_Button_1`
  - Button size: `220 x 80`
  - Button text: `Button`
- Popup screen: `Codex_Popup_500x500`
  - Popup size: `500 x 500`
  - Contains title text: `Popup 500x500`

## XML Templates

Use these bundled templates as a starting point:

- `../assets/hmi-screen-templates/hmi_import_Codex_Button_Test.xml`
- `../assets/hmi-screen-templates/hmi_import_Codex_Popup_500x500.xml`

When reusing the templates, change the screen names and object names to avoid collisions unless `ImportOptions.Override` is intentionally desired.

## Important TIA V17 Details

- Normal screens must include a valid `<Number>` in the range `1..32767`.
- Popup screens do not support the root `Visible` attribute.
- Popup screens do not support root-level `HelpText`.
- If an Openness import exception causes the attached session to become invalid, dispose the session, wait for Portal to recover, then attach again to the TIA process listed by `TiaPortal.GetProcesses()`.
- Do not overwrite existing HMI screens without checking `Find(name)` first or explicitly using `Override`.

## Verification Snippets

Export the created objects after import:

```powershell
$screen = $hmi.ScreenFolder.Screens.Find('Codex_Button_Test')
$popup = $hmi.ScreenPopupFolder.ScreenPopups.Find('Codex_Popup_500x500')
$screen.Export([System.IO.FileInfo]'hmi_verify_exports\Codex_Button_Test.xml', [Siemens.Engineering.ExportOptions]::WithDefaults)
$popup.Export([System.IO.FileInfo]'hmi_verify_exports\Codex_Popup_500x500.xml', [Siemens.Engineering.ExportOptions]::WithDefaults)
```

Check exported XML for:

- `Hmi.Screen.Button`
- `Codex_Button_1`
- popup `<Width>500</Width>`
- popup `<Height>500</Height>`
