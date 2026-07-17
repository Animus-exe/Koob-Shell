# Drop your ASCII art here

This is the easy folder for personal gallery backdrops.

1. Add a `.json` file (or an extensionless text file) to this directory.
2. Run `swift run` from the repo root.
3. Open **Preferences… → ASCII Gallery** and enable the gallery (lower terminal opacity so the art shows through).

Personal files here are **gitignored** — only this README and `*.example` templates are committed.

## Quick template

```bash
cp Ascii_art/example.json.example Ascii_art/my-cat.json
```

```json
{
  "art": [
    "  /\\_/\\",
    " ( o.o )",
    "  > ^ <"
  ]
}
```

Or paste raw art into a file with no extension:

```bash
cat > Ascii_art/bunny <<'EOF'
(\(\
( -.-)
o_(")(")
EOF
```

## Formats

| Kind | Example | Notes |
| --- | --- | --- |
| JSON string | `{ "art": "line\\nline" }` | Preferred for single pieces |
| JSON lines | `{ "art": ["line", "line"] }` | Easiest to edit by hand |
| Animated | `{ "frames": [...], "fps": 12 }` | Optional looping backdrop |
| Extensionless | `dragon`, `banner` | Raw UTF-8 text |

Files are sorted by name. Empty files and placeholders like `paste your ascii art here` are skipped.

## Also loaded

Koob Shell also loads bundled defaults from `Plugins/ascii-gallery/Ascii_art/` (the Koob intro animation). If the same filename exists in both places, **this folder wins**.

Packaged app installs use:

```text
~/Library/Application Support/KoobShell/plugins/ascii-gallery/Ascii_art/
```

More detail: [Plugins/ascii-gallery/Ascii_art/README.md](../Plugins/ascii-gallery/Ascii_art/README.md).
