# Generated Objects

Use these names by default unless the user asks for plant-specific naming.

## Core Objects

- `FB_BagPulseDustCollector`
  - reusable SCL FB
  - owns the pulse sequence, inter-bag delay, cycle pause, manual pulse, and alarm/status outputs

- `DB_BagPulseDustCollector`
  - instance DB for the core FB

- `DB_BagPulseDustCollector_IO`
  - HMI/operator-facing DB
  - stores adjustable parameters and mirrors runtime status

- `FC_BagPulseDustCollector_IO`
  - wraps field IO around the core FB
  - reads input tags, calls the FB instance, writes pulse valve outputs, writes status words

## Main/OB1 Caller

When OB1/Main is empty or explicitly approved for replacement, a minimal caller is enough:

```scl
ORGANIZATION_BLOCK "Main"
BEGIN
   "FC_BagPulseDustCollector_IO"();
END_ORGANIZATION_BLOCK
```

If the existing OB1 contains logic, preserve it and only add a single call when you can do so cleanly.

## Reporting Checklist

After generation, report:

- whether each object was created or already existed
- whether `Main`/`OB1` was replaced, modified, or left untouched
- compile result for the generated blocks
- compile result for the full PLC software
