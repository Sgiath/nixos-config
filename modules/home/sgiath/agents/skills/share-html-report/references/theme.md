# Theme and graph contract

Asset paths in this reference are relative to the skill directory.

## Shared theme assets

All reports share one theme — the **sgiath.dev design language** (`~/develop/sgiath/sgiath.dev/design-language/DESIGN-LANGUAGE.md` in the site repo: hairline strokes on poster black, JetBrains Mono, tracked uppercase captions, rationed signal-red accent, radical negative space) — so they look consistent without shipping their own base CSS. The theme spans three hosted assets:

| Asset | Source of truth (this skill) | Hosted copy | Remote path |
| --- | --- | --- | --- |
| Theme stylesheet | `references/report.css` | `https://sgiath.dev/llm/report.css` | `/data/www/sgiath.dev/llm/report.css` |
| LiteGraph runtime | `references/litegraph.js` (vendored, do not edit) | `https://sgiath.dev/llm/litegraph.js` | `/data/www/sgiath.dev/llm/litegraph.js` |
| Graph bootstrapper | `references/report.js` | `https://sgiath.dev/llm/report.js` | `/data/www/sgiath.dev/llm/report.js` |

Rendered example of everything they style: `references/sample.html` (it references the scripts with relative paths because it sits next to them; real reports use the absolute URLs below).

Every report links the stylesheet from `<head>` with the absolute URL, so the page renders identically in local preview and once deployed:

```html
<link rel="stylesheet" href="https://sgiath.dev/llm/report.css">
```

Only when the report contains an interactive node graph, also add — in this order, after the stylesheet link:

```html
<script src="https://sgiath.dev/llm/litegraph.js" defer></script>
<script src="https://sgiath.dev/llm/report.js" defer></script>
```

What the theme gives you:

- Bare semantic HTML is fully styled: headings, links, tables with captions, code blocks, blockquotes, lists, definition lists, figures, `details`, `hr`, and basic form controls. Write plain elements; do not restyle them.
- Layout contract: `body > header` (the `<h1>` plus a metadata line, rendered as a centered caption stack over a small orbital seal — the page's one motif, supplied by the theme), `<main>` whose `<section>`s read as numbered caption rules separated by whitespace, an optional `body > aside` that becomes a sticky right-hand side rail (status, telemetry, table of contents, report metadata), and `body > footer` for provenance. Without an `<aside>`, `<main>` spans the full shell. Because the theme already places the page's single orbital motif in the header, reports must not add another decorative orbital/ring graphic.
- Utility classes for instrument readouts — all optional sugar; bare reports render unchanged without them:
  - `.dot` with `.dot-ok`/`.dot-warn`/`.dot-err` — small static status marker: `<span class="dot dot-ok"></span>online`
  - `.bar` with an inner width-styled span — hairline gauge: `<div class="bar"><span style="width: 72%"></span></div>`
  - `.metric` — big numeric readout: `<p class="metric">98.4%</p>`
  - `.status` with `.status-ok`/`.status-warn`/`.status-err` — tracked uppercase caption chip with a status dot; works inline in prose or slides right inside a section header: `<h2>Nav.Scope <span class="status status-ok">scanning</span></h2>`
  - `dl.readout` — dotted-leader readout rows (label left, dotted leader, bright value right): `<dl class="readout"><dt>RNG</dt><dd>4.7 AU</dd></dl>`; degrades to a normal `dl` in print
  - `ul.log` (or `ol.log`) — ops log lines with a muted `>` prefix, latest line brightened; wrap timestamps in `<time>`: `<ul class="log"><li><time>09:32:07</time> UPLINK SYNC ... OK</li></ul>`
  - `.manifest` — hairline ID/manifest card with one accent corner tick, wrapping a `dl` of label/value rows (values right-aligned): `<div class="manifest"><dl><dt>Callsign</dt><dd>SGIATH</dd></dl></div>`; works in `main` and `aside` sections
  - Retired decorative chrome from the previous theme — `.cursor`, `.barcode`, `.scope`, `.trace` — renders as nothing (kept only so already-published reports degrade cleanly). Never use these in new reports; annotation must plausibly measure something.
- Optional interactive-diagram classes — CSS-only interactivity (details/summary, `:hover`, `:focus`); zero JavaScript; use only when interaction materially improves understanding. The `.node-graph` family below is available as a lightweight no-JS fallback when a node diagram is genuinely warranted:
  - `.node-graph` — node-editor style diagram canvas (dot grid, relative positioning). Contains one absolutely-positioned wires layer plus `.node` cards placed with inline percentages: `<div class="node-graph" style="height: 26rem"><svg class="wires" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">…</svg><details class="node" style="left: 6%; top: 18%">…</details></div>`
  - `.node` — node card. Preferred form is `<details class="node"><summary>name <small>subtitle</small></summary><p>detail…</p></details>` so every node is click-expandable; the open node gets an accent border and overlays its neighbors. A non-expanding `<div class="node"><h4>name</h4>…</div>` renders identically minus the marker.
  - `.port` with `.port-a` (accent) / `.port-b`–`.port-e` (monochrome ink steps, high → faint) — small hollow hairline dot on a node edge that fills on hover; position inside the `<summary>` with inline offsets and mark decorative: `<i class="port port-b" style="left: 100%; top: 1.1rem" aria-hidden="true"></i>`; add an optional micro label: `<span class="port-label" style="right: 4px; top: 0.55rem" aria-hidden="true">SIG</span>`
  - `.wire` with `.wire-a/-e` (colors matching the ports: `-a` is the single accent highlight, the rest monochrome) — hairline SVG `<path>` inside the `.wires` layer; draw cubic beziers in a `viewBox="0 0 100 100"` + `preserveAspectRatio="none"` SVG so coordinates read as percentages of the canvas; hovering a wire brightens it: `<path class="wire wire-a" d="M 20,16 C 29,16 29,38 38,38"/>`
  - `ol.steps` — vertical workflow stepper with hollow hairline numbered chips on a hairline spine; each step is a click-to-expand details, and the open step's chip turns accent: `<ol class="steps"><li><details><summary>Draft</summary><p>…</p></details></li></ol>`
  - `.tip` — hover/focus tooltip: dotted accent underline, bubble above with the `data-tip` text; add `tabindex="0"` so keyboard users can focus it: `<span class="tip" data-tip="explanation" tabindex="0">term</span>`
  - `.clickable` — generic hover-lift affordance for any linked panel or figure.
  - Fallbacks: in print, `.node-graph` degrades to a static stacked list of the same expandable cards — wires and ports hide, nodes flow full width — so the markup stays readable as plain content. In print, a closed `details` body does not render (browser behavior); open the nodes/steps that matter before printing, or accept summary-only output.
- Section headers in `main` auto-number with a small accent index ("02" before the tracked uppercase title, trailing hairline rule) — no markup needed.
- Dark theme, print styles, and `prefers-reduced-motion` handling are built in. The stylesheet loads JetBrains Mono itself (same import the site uses); reports add no font tags.

Report-specific inline CSS is for content the theme cannot know about (custom diagrams, charts, one-off layouts). Reuse the theme's custom properties (`--accent`, `--text-hi`/`--text-mid`/`--text-low`, `--stroke-faint`/`--stroke`, `--bg-1`, `--hue-a`…`--hue-e`, spacing steps; legacy aliases like `--fg-muted`, `--line`, `--bg-panel` still resolve) instead of inventing new colors or fonts.

If the theme itself changes, update the source file in this skill, re-upload it to the same remote path, and verify with a cache-busting query. The hosted filenames stay `report.css`, `litegraph.js`, and `report.js`.

## Optional interactive node graphs (LiteGraph)

Node graphs are an exception, not the default. Do not add one merely because the report discusses a workflow, system, architecture, dependencies, or a sequence of steps. Prefer headings, lists, tables, definition lists, or a compact stepper when those explain the material adequately.

Use LiteGraph only when all of these are true:

- the report contains several entities with meaningful non-linear relationships;
- tracing connections between those entities is central to the reader's task;
- a table, ordered list, or simple static layout would make those relationships materially harder to understand;
- dragging, panning, or zooming provides real value rather than decoration.

When these conditions are met, LiteGraph provides a draggable, pannable, zoomable node canvas. The CSS `.node-graph` classes remain available as a no-JS fallback for a warranted static node diagram. Otherwise omit node graphs and their scripts entirely.

Recipe — only when the criteria above are satisfied, use a `figure.graph` with an embedded JSON spec plus the two script tags from “Shared theme assets”:

```html
<figure class="graph">
  <script type="application/json">
  {
    "height": 460,
    "nodes": [
      { "id": "button", "title": "button", "sub": "momentary",
        "body": "Debounced in firmware, 20 ms window.",
        "pos": [40, 60], "size": [180, 90],
        "outputs": ["SIG"], "accent": "a" },
      { "id": "pico", "title": "pico", "sub": "RP2040",
        "body": "Polls the sensor every 10 s.",
        "pos": [320, 60],
        "inputs": ["GP2"], "outputs": ["SPI"], "accent": "b" }
    ],
    "links": [ ["button:SIG", "pico:GP2", "a"] ]
  }
  </script>
  <noscript><p>Interactive graph requires JavaScript.</p></noscript>
  <figcaption>Fig 1 — drag nodes, pan, zoom (LiteGraph)</figcaption>
</figure>
```

Spec format (`report.js` translates it to LiteGraph):

- `height` — optional canvas height in CSS px (default 440). The node layout is auto-fitted and centered inside the canvas at load and on resize, so `pos`/`size` coordinates are unit-free — only their proportions matter.
- `nodes[]` — each node: `id` (unique string, used by links), `title`, `sub` (muted line under the title), `body` (word-wrapped paragraph; the node auto-grows to fit), `pos` `[x, y]`, optional `size` `[w, h]`, `inputs` / `outputs` (arrays of slot-name strings; slots are untyped so anything connects), `accent` (palette letter, tints the title bar).
- `links[]` — `["fromNodeId:outputName", "toNodeId:inputName", "colorVariant"]`. Slot indices are resolved by name; unknown node or slot refs are `console.warn`ed and skipped.
- Palette letters (node `accent` and link color variant) — monochrome + one accent, structure by value not hue: `a` = `#e25d52` accent (reserve for the one highlighted node/path), `b` = `#e6e6e9` ink-high, `c` = `#9d9da6` ink-mid, `d` = `#606069` ink-low, `e` = `#3a3a41` faint.

Graphs are display-only: no node creation, no searchbox, no context menu, and no graph execution. If the scripts fail to load, the figure shows only its caption and the `<noscript>` note.

If the theme itself changes, update `references/report.css`, re-upload it to the same remote path, and verify with a cache-busting query. The hosted filename stays `report.css`.
