---
name: insert-weather-into-word
description: Look up current weather for a city or district and insert a concise weather summary into an already open Microsoft Word document. Use when the user asks to type today's weather into Word, continue on the next line, or add translated weather lines such as Japanese or German into the active Word document.
---

# Insert Weather Into Word

Insert weather text into the active Microsoft Word document and keep the wording short, date-specific, and ready to paste into a report or memo.

## Workflow

1. Resolve the target place and the date.
Use an absolute date in the response and in the inserted text when the request says "today", "tomorrow", or similar relative wording.

2. Fetch current weather before writing.
Use a live weather source or tool when the request depends on current conditions. Prefer a concise summary: condition, temperature, and the next few hours if relevant.

3. Draft the weather sentence in the user's requested language.
Keep it compact and practical. A good default shape is:

`YYYY-MM-DD [location] weather: currently [condition], around [temp] C. Later today or over the next few hours: [trend].`

For translations, translate the already prepared weather content rather than re-querying weather unless the user asks for a fresh update.

4. Insert into the active Word document.
Run [scripts/insert-into-active-word.ps1](scripts/insert-into-active-word.ps1) and pass the text to insert. Use `-NewParagraph` when the user asks for the next line or a new line.

5. Report completion briefly.
Tell the user the text has been inserted. If Word is not open, say that clearly and stop instead of pretending the insertion worked.

## PowerShell Usage

Use this pattern from PowerShell:

```powershell
& 'C:\path\to\insert-weather-into-word\scripts\insert-into-active-word.ps1' -Text $text
& 'C:\path\to\insert-weather-into-word\scripts\insert-into-active-word.ps1' -Text $translated -NewParagraph
```

If the current shell is PowerShell, pass the text as a normal string or here-string. Keep the final string fully assembled before calling the script.

## Translation Notes

When the user asks to translate into Japanese, German, or another language, translate the already drafted weather line and insert the translation on the next line if requested.

Common follow-ups for this skill:

- "Translate that into Japanese on the next line"
- "Add a German version below it"
- "Insert Tokyo weather too"

Treat those as continuation edits to the same open document.

## Failure Handling

If Word automation fails because no active instance is available, tell the user Word may not be open or accessible.

If a live weather lookup is unavailable, say so and do not invent current conditions.

Do not overwrite unrelated content; insert only at the current selection.
