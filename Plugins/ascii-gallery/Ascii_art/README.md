# ASCII Gallery plugin art

Bundled defaults (`00-koob.json` … `03-koob.json`) live here.

**For personal art, use the repo-root drop folder instead:**

→ **[Ascii_art/](../../../Ascii_art/)** — copy `example.json.example`, add your `.json` / extensionless files, run `swift run`.

That root folder is preferred at development time. Files here are still loaded (and win only when the root folder does not already define the same filename).

## Packaged / installed app

```text
~/Library/Application Support/KoobShell/plugins/ascii-gallery/Ascii_art/
```

## Formats (short)

```json
{
  "art": [
    "  /\\_/\\",
    " ( o.o )",
    "  > ^ <"
  ]
}
```

Optional animation: `frames`, `fps`, `loopFrom`. Extensionless plain-text files also work.

Personal art under any `Ascii_art/` folder is gitignored (except README / `*.example` / bundled Koob defaults). Full guide: [Ascii_art/README.md](../../../Ascii_art/README.md).
