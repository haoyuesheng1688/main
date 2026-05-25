# Default IO Map

Use this mapping when the user wants a ready-made closed loop and does not provide a plant-specific IO list.

Before applying it, inspect the target project for conflicts. If these addresses are already in use for something else, stop and ask for the real IO allocation.

## Inputs

- `DC_Enable` -> `%I0.0`
- `DC_Reset` -> `%I0.1`
- `DC_RunPermit` -> `%I0.2`
- `DC_CleanRequest` -> `%I0.3`
- `DC_DpHigh` -> `%I0.4`
- `DC_DpLow` -> `%I0.5`
- `DC_ContinuousMode` -> `%I0.6`
- `DC_ManualPulse` -> `%I0.7`

## Outputs

- `DC_PulseValve_1` -> `%Q0.0`
- `DC_PulseValve_2` -> `%Q0.1`
- `DC_PulseValve_3` -> `%Q0.2`
- `DC_PulseValve_4` -> `%Q0.3`

## Status Memory

Keep status words away from the standard clock memory area. A safe default is:

- `DC_Running` -> `%M120.0`
- `DC_AutoRunning` -> `%M120.1`
- `DC_CycleDone` -> `%M120.2`
- `DC_Busy` -> `%M120.3`
- `DC_Alarm` -> `%M120.4`
- `DC_CurrentBag` -> `%MW122`
- `DC_AlarmCode` -> `%MW124`
- `DC_StepNo` -> `%MW126`

## Default Parameter Values

- `BagCount := 4`
- `PulseTime := T#200MS`
- `ValveInterval := T#5S`
- `CyclePause := T#30M`
- `ManualBag := 1`
