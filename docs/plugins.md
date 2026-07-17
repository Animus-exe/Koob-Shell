# Plugins

Plugins are manifest bundles. Each plugin is a folder:

```text
~/Library/Application Support/KoobShell/plugins/<plugin-id>/
  plugin.json
  …optional assets…
```

On first launch, Koob Shell seeds bundled plugins from the app resources (and a sample Git Helper Pack).

## Manifest (`plugin.json`)

Minimum fields:

```json
{
  "id": "my-plugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "isEnabled": true,
  "commands": [],
  "themes": []
}
```

Optional contributions:

| Field | Purpose |
| --- | --- |
| `commands` | Command templates (`name`, `template`, optional `arguments`, `environment`, `runMode`) |
| `themes` | Theme definitions (colors, font, banner, borders) |
| `gallery` | ASCII art directory for the backdrop gallery |
| `workflow` | Workflow Intelligence capability (see [workflow-intelligence.md](workflow-intelligence.md)) |

Set `"isEnabled": false` to disable a plugin without deleting it.

## Command entry example

```json
{
  "id": "E97158A3-6968-48BA-981D-CCEF2D1FF4C5",
  "name": "Git Graph",
  "runMode": "interactive",
  "template": "git log --graph --oneline --decorate {{range}}",
  "arguments": [
    {
      "id": "581E0F49-61D1-4AF6-B364-C796A0B6764C",
      "key": "range",
      "label": "Revision Range",
      "defaultValue": "HEAD~1",
      "required": false
    }
  ],
  "defaultWorkingDirectory": null,
  "environment": {}
}
```

`{{range}}` is replaced from argument values when a command is rendered.

## Bundled plugins

| Plugin | Role |
| --- | --- |
| **Git Helper Pack** | Sample commands and a theme |
| **Shell Theme Pack** | Extra themes |
| **ASCII Gallery** | Rotating art behind the terminal ([add your own](../Plugins/ascii-gallery/Ascii_art/README.md)) |
| **Workflow Intelligence** | Session capture and `koobshell` CLI |

Repo copies of plugin sources live under [`Plugins/`](../Plugins/) and are copied into Application Support when seeded.

## Authoring tips

1. Copy an existing plugin folder as a starting point.
2. Use a unique `id`.
3. Restart Koob Shell after edits so plugin manifests and assets are re-seeded/reloaded.
4. Keep plugins local-only; there is no remote install channel.
