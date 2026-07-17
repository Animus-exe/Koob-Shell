# Adding your own ASCII art

Personal gallery files in this folder are **gitignored** on purpose. Clone the repo, drop your art here, and it stays on your machine — nothing in this directory (except this README and `*.example` templates) is uploaded to GitHub.

## Quick start

1. Create the art directory if it is missing:

   ```bash
   mkdir -p Plugins/ascii-gallery/Ascii_art
   ```

2. Add one or more art files (see formats below).

3. Run the app from the repo root:

   ```bash
   swift run
   ```

4. Open **Preferences…** → **ASCII Gallery** and enable the gallery. Lower **terminal opacity** so the art shows through (the app often adjusts this when you turn the gallery on).

5. Restart Koob Shell (or toggle the gallery off/on) if new files do not appear right away.

During development, Koob Shell prefers art from `Plugins/ascii-gallery/Ascii_art/` in the checkout. After install / first launch, a copy also lives under Application Support (see [Where files are loaded](#where-files-are-loaded)).

Do not put art in a repo-root `Ascii_art/` folder — that legacy location is no longer used.

## Supported file types

Only these are loaded:

| Kind | Examples | Notes |
| --- | --- | --- |
| JSON | `dragon.json` | Preferred. See formats below. |
| Extensionless text | `lockedin`, `banner` | Raw UTF-8 ASCII/Unicode art. |

Ignored by the gallery loader (safe to keep here):

- `README.md` (this file)
- `*.example` templates
- Anything with another extension (`.txt`, `.md`, `.png`, …)

Files are sorted by filename (case-insensitive). Empty files and placeholder text like `paste your ascii art here` are skipped.

## File formats

### 1. JSON string (recommended)

```json
{
  "art": "  /\\_/\\\n ( o.o )\n  > ^ <"
}
```

Use `\n` for newlines inside the JSON string. Save as UTF-8.

### 2. JSON array of lines

Easier to edit by hand — each array element is one row:

```json
{
  "art": [
    "  /\\_/\\",
    " ( o.o )",
    "  > ^ <"
  ]
}
```

### 3. Animated frames (optional)

For a looping backdrop animation, add `frames` (and optionally `fps` / `loopFrom`):

```json
{
  "art": "frame zero fallback",
  "fps": 12,
  "loopFrom": 4,
  "frames": [
    "boot frame 0",
    "boot frame 1",
    "idle frame A",
    "idle frame B"
  ]
}
```

- `fps` — frames per second (default `12`)
- `loopFrom` — index to restart from after the first full pass (use this for a one-shot intro, then an idle loop)
- `frames` may also be arrays of lines, same as `art`

The bundled defaults are `00-koob.json` through `03-koob.json` (scan-in intro + floating sway loop).

Copy `example.json.example` to a new name ending in `.json` and replace the art:

```bash
cp Plugins/ascii-gallery/Ascii_art/example.json.example \
   Plugins/ascii-gallery/Ascii_art/my-cat.json
```

### 4. Plain text / extensionless

Paste the art as-is into a file with **no extension**, or into a `.json` file that is *not* valid JSON (the loader will treat the whole file as raw art). Prefer a real JSON wrapper when you can — it avoids accidental mis-parses.

Example:

```bash
cat > Plugins/ascii-gallery/Ascii_art/bunny <<'EOF'
(\(\
( -.-)
o_(")(")
EOF
```

## Naming tips

- Use short, unique names: `dragon.json`, `mew`, `cs2.json`.
- The filename (without `.json`) becomes the entry id in the gallery.
- Avoid spaces if you can; they work, but kebab-case is simpler.

## Where files are loaded

Koob Shell resolves the art directory in this order:

1. **Development checkout** — `Plugins/ascii-gallery/Ascii_art/` next to the package (what you edit while hacking).
2. **Installed plugin** —  
   `~/Library/Application Support/KoobShell/plugins/ascii-gallery/Ascii_art/`
3. **Bundled resources** — art copied into the app bundle at build time (only whatever existed under `Plugins/` when you built).

For day-to-day personal art while using a packaged app, put files in Application Support:

```text
~/Library/Application Support/KoobShell/plugins/ascii-gallery/Ascii_art/
```

Create that folder if needed, add your `.json` / extensionless files, then relaunch Koob Shell.

## Preferences that matter

| Setting | Effect |
| --- | --- |
| Gallery enabled | Turns the backdrop on/off |
| Gallery opacity | How strong the art appears |
| Terminal opacity | Must be below 1.0 or the terminal hides the art |
| Full screen gallery | Art fills the window behind the terminal |
| Interval / revolve | How often the gallery advances to the next piece |

Also ensure the **ASCII Gallery** plugin is enabled and that plugin galleries are allowed in Preferences / `appearance.json` (`allowPluginGalleries`).

## Privacy / GitHub

This repo’s `.gitignore` ignores `**/Ascii_art/**` except:

- `Ascii_art/README.md` (these instructions)
- `Ascii_art/*.example` (templates)

Do **not** force-add personal art (`git add -f …`) unless you intentionally want it public. If you fork and want a public sample pack, commit only art you have rights to share, or keep samples under a differently named folder that is not ignored.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| No art at all | Gallery enabled? Terminal opacity &lt; 1? Files under the paths above? |
| One file missing | Empty file? Placeholder phrase? Wrong extension (must be `.json` or none)? |
| Old art after edits | Relaunch the app; confirm you edited the development path vs Application Support |
| Art looks cut off | Prefer smaller pieces, or enable full-screen gallery / adjust window size |

More context: [configuration](../../../docs/configuration.md), [plugins](../../../docs/plugins.md).
