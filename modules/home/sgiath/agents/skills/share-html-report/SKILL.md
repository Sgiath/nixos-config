---
name: share-html-report
description: Create and publish a dated, standalone HTML visualization of the current conversation's data, plan, analysis, comparison, or decision. Use ONLY when the user asks for a shareable HTML report, visual summary, single-page visualization, or to publish the current discussion to sgiath.dev/vesta.
compatibility: Requires SSH/SCP access to vesta.local and write access to /data/www/sgiath.dev/llm
disable-model-invocation: true
---

# Share HTML Report

Turn the useful substance of the current conversation into one HTML page styled by the shared theme assets, upload it to the public `sgiath.dev` host, verify the deployment, and return its URL.

## Output contract

- Local file: `docs/YYYY-MM-DD-<topic-slug>.html`
- Remote file: `/data/www/sgiath.dev/llm/YYYY-MM-DD-<topic-slug>.html`
- Public URL: `https://sgiath.dev/llm/YYYY-MM-DD-<topic-slug>.html`
- The filename date is the current UTC date from `date -u +%F`.
- The topic slug is lowercase ASCII kebab-case using only `a-z`, `0-9`, and `-`.
- Produce exactly one HTML file that links the shared theme stylesheet and embeds the PostHog analytics snippet (see below), adding inline CSS only for report-specific visualizations. Reports that contain an interactive node graph additionally load the two hosted graph scripts (see “Shared theme assets”). Use further inline JavaScript or SVG only when necessary. Do not create asset directories.

If the local or remote filename already exists, do not overwrite it silently. Append the current UTC time as `-HHMMSS` before `.html`, unless the user explicitly asked to replace the existing report.

## Shared theme assets

All reports share one dark sci-fi theme so they look consistent without shipping their own base CSS. The theme now spans three hosted assets:

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
- Layout contract: `body > header` (the `<h1>` plus a metadata line), `<main>` whose `<section>`s render as HUD panels, an optional `body > aside` that becomes a sticky right-hand side panel (status, telemetry, table of contents, report metadata), and `body > footer` for provenance. Without an `<aside>`, `<main>` spans the full shell.
- Utility classes for telemetry widgets — all optional sugar for console-feel reports; bare reports render unchanged without them:
  - `.dot` with `.dot-ok`/`.dot-warn`/`.dot-err` — pulsing status indicator: `<span class="dot dot-ok"></span>online`
  - `.bar` with an inner width-styled span — animated gauge: `<div class="bar"><span style="width: 72%"></span></div>`
  - `.cursor` — blinking terminal cursor: `<span class="cursor"></span>`
  - `.metric` — big numeric readout: `<p class="metric">98.4%</p>`
  - `.status` with `.status-ok`/`.status-warn`/`.status-err` — uppercase chip with pulsing dot; works inline in prose or right-aligned inside a panel header: `<h2>Nav.Scope <span class="status status-ok">scanning</span></h2>`
  - `dl.readout` — dotted-leader readout rows (label left, dotted leader, bright value right): `<dl class="readout"><dt>RNG</dt><dd>4.7 AU</dd></dl>`; degrades to a normal `dl` in print
  - `ul.log` (or `ol.log`) — ops log lines with an amber `>` prefix and a blinking cursor on the latest line; wrap timestamps in `<time>`: `<ul class="log"><li><time>09:32:07</time> UPLINK SYNC ... OK</li></ul>`
  - `.manifest` — dashed-teal ID/manifest card wrapping a `dl` of label/value rows (values right-aligned): `<div class="manifest"><dl><dt>Callsign</dt><dd>SGIATH</dd></dl></div>`; works in `main` and `aside` sections
  - `.barcode` — decorative pure-CSS barcode stripe (hidden in print): `<div class="barcode" aria-hidden="true"></div>`
  - `.scope` — radar scope with range rings, crosshairs, and a rotating sweep; position `.blip` children with inline `left`/`top` percentages: `<div class="scope" aria-hidden="true"><i class="blip" style="left: 62%; top: 28%"></i></div>`
  - `.trace` — telemetry trace panel (inset grid background); put an inline SVG with `<polyline class="trace-line">` (amber) and optionally `<polyline class="trace-line-alt">` (teal) inside for animated live traces, plus `<i class="trace-scan"></i>` for a sweeping cursor line: `<div class="trace" aria-hidden="true"><svg viewBox="0 0 400 120" preserveAspectRatio="none"><polyline class="trace-line" points="0,70 50,40 100,60"/></svg><i class="trace-scan"></i></div>`; without the SVG it is just the grid panel
- Interactive-diagram classes — CSS-only interactivity (details/summary, `:hover`, `:focus`); zero JavaScript; all opt-in. The `.node-graph` family below is the lightweight no-JS fallback for node diagrams — the primary node-graph surface is the LiteGraph `figure.graph` recipe in the next section:
  - `.node-graph` — node-editor style diagram canvas (dot grid, relative positioning). Contains one absolutely-positioned wires layer plus `.node` cards placed with inline percentages: `<div class="node-graph" style="height: 26rem"><svg class="wires" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">…</svg><details class="node" style="left: 6%; top: 18%">…</details></div>`
  - `.node` — node card. Preferred form is `<details class="node"><summary>name <small>subtitle</small></summary><p>detail…</p></details>` so every node is click-expandable; the open node gets an accent border and overlays its neighbors. A non-expanding `<div class="node"><h4>name</h4>…</div>` renders identically minus the marker.
  - `.port` with `.port-a` (amber) / `.port-b` (teal) / `.port-c` (green) / `.port-d` (violet) / `.port-e` (red) — small hollow dot on a node edge that fills and glows on hover; position inside the `<summary>` with inline offsets and mark decorative: `<i class="port port-b" style="left: 100%; top: 1.1rem" aria-hidden="true"></i>`; add an optional micro label: `<span class="port-label" style="right: 4px; top: 0.55rem" aria-hidden="true">SIG</span>`
  - `.wire` with `.wire-a/-b/-c/-d/-e` (colors matching the ports) — SVG `<path>` inside the `.wires` layer; draw cubic beziers in a `viewBox="0 0 100 100"` + `preserveAspectRatio="none"` SVG so coordinates read as percentages of the canvas; hovering a wire brightens and thickens it: `<path class="wire wire-a" d="M 20,16 C 29,16 29,38 38,38"/>`
  - `ol.steps` — vertical workflow stepper with numbered amber chips and a connecting spine; each step is a click-to-expand details, and the open step's chip fills amber: `<ol class="steps"><li><details><summary>Draft</summary><p>…</p></details></li></ol>`
  - `.tip` — hover/focus tooltip: dotted amber underline, bubble above with the `data-tip` text; add `tabindex="0"` so keyboard users can focus it: `<span class="tip" data-tip="explanation" tabindex="0">term</span>`
  - `.clickable` — generic hover lift + glow affordance for any linked panel or figure.
  - Fallbacks: in print, `.node-graph` degrades to a static stacked list of the same expandable cards — wires and ports hide, nodes flow full width — so the markup stays readable as plain content. In print, a closed `details` body does not render (browser behavior); open the nodes/steps that matter before printing, or accept summary-only output.
- Panel headers in `main` auto-number with an amber chip ("02" box before "// TITLE") — no markup needed.
- Dark theme, print styles, and `prefers-reduced-motion` handling are built in.

Report-specific inline CSS is for content the theme cannot know about (custom diagrams, charts, one-off layouts). Reuse the theme's custom properties (`--accent`, `--fg-muted`, `--line`, `--bg-panel`, spacing steps) instead of inventing new colors or fonts.

If the theme itself changes, update the source file in this skill, re-upload it to the same remote path, and verify with a cache-busting query. The hosted filenames stay `report.css`, `litegraph.js`, and `report.js`.

## Interactive node graphs (LiteGraph)

Workflow, system, architecture, and pipeline content renders as a REAL interactive node canvas: draggable nodes, pannable/zoomable viewport, collapsible nodes, themed to the amber mission-console look. The CSS `.node-graph` classes remain documented above as the no-JS fallback for static diagrams; prefer the LiteGraph graph whenever the reader must trace a flow.

Recipe — a `figure.graph` with an embedded JSON spec plus the two script tags from “Shared theme assets”:

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

- `height` — optional canvas height in CSS px (default 440).
- `nodes[]` — each node: `id` (unique string, used by links), `title`, `sub` (muted line under the title), `body` (word-wrapped paragraph; the node auto-grows to fit), `pos` `[x, y]`, optional `size` `[w, h]`, `inputs` / `outputs` (arrays of slot-name strings; slots are untyped so anything connects), `accent` (palette letter, tints the title bar).
- `links[]` — `["fromNodeId:outputName", "toNodeId:inputName", "colorVariant"]`. Slot indices are resolved by name; unknown node or slot refs are `console.warn`ed and skipped.
- Palette letters (node `accent` and link color variant): `a` = `#ffb000` amber, `b` = `#6fc7b2` teal, `c` = `#59c37a` green, `d` = `#b18cff` violet, `e` = `#ff4d4d` red.

Graphs are display-only: no node creation, no searchbox, no context menu, and no graph execution. If the scripts fail to load, the figure shows only its caption and the `<noscript>` note.

If the theme itself changes, update `references/report.css`, re-upload it to the same remote path, and verify with a cache-busting query. The hosted filename stays `report.css`.

## Analytics snippet

Every report includes the PostHog snippet so page views are tracked. Copy `references/posthog.html` from this skill verbatim into the report's `<head>`, after the stylesheet link. Do not reformat, minify further, or edit the project key or hosts.

## Workflow

1. Announce that you are using `share-html-report`.

2. Define the report from the current conversation.

   Identify:
   - the subject and intended audience;
   - the decision or understanding the page should enable;
   - facts, data, plans, alternatives, risks, evidence, and source links already established;
   - uncertainties that must be labeled rather than guessed.

   The current conversation is the primary source. Research only when a claim must be refreshed or verified.

3. Run the public-content safety gate before writing.

   The resulting URL is public. Inspect the proposed content for:
   - credentials, tokens, private keys, secrets, or authentication headers;
   - customer data, personal information, private messages, or recordings;
   - internal-only URLs, infrastructure details, incident data, or confidential commercial information;
   - unpublished company material whose public status is unclear.

   Remove irrelevant sensitive details. If sensitive information is essential or public-sharing authorization is unclear, ask one precise question and stop before creating or uploading the report.

4. Choose the filename.

   Run:

   ```bash
   date -u +%F
   date -u +%H%M%S
   ```

   Derive a short descriptive slug from the report subject. Example:

   ```text
   2026-08-03-hackney-dependency-maintenance.html
   ```

5. Choose a visualization grammar that matches the content.

   - Data or inventory: sortable-looking registry, table, compact metrics, comparisons.
   - Plan or roadmap: phases, dependencies, timeline, milestones, decision gates.
   - Architecture or flow: semantic boxes and connectors using HTML/CSS or inline SVG.
   - Workflow or system → interactive LiteGraph node graph (`figure.graph` + JSON spec; see “Interactive node graphs”) or stepper (`.steps`); the CSS `.node-graph` is the no-JS fallback. Prefer interactive structure over static prose whenever the reader must trace a flow.
   - Decision analysis: options matrix, evidence, impact, confidence, recommendation.
   - Research synthesis: findings table, source links, confidence, unresolved questions.

   The page is a technical artifact, not marketing copy. Prefer labels, tables, diagrams, and terse annotations over prose.

6. Build the visual page.

   Load the `frontend` skill and delegate visual implementation to a visual-engineering specialist when available. If the harness exposes Fable model selection, prefer Fable for the visual implementation; otherwise use the configured visual specialist without claiming it is Fable. Give the specialist the shared-theme contract above: base styling comes from `report.css`, so the work is semantic structure, content visualization, and small report-specific styles — not a new design system.

   Requirements:
   - semantic HTML landmarks and heading hierarchy;
   - desktop-only layout — reports are viewed exclusively on desktop; do NOT add mobile/tablet breakpoints, viewport meta tags, touch affordances, or any other mobile compatibility work;
   - accessible contrast, focus states, table captions, and reduced-motion handling;
   - report-specific styles reuse the theme's custom-property tokens for color, typography, spacing, and surfaces; base elements the theme already covers are not restyled;
   - current date visible in report metadata;
   - source links that open in a new tab while internal anchors stay in the same tab;
   - no external assets other than the shared theme stylesheet link, the PostHog analytics snippet, and — only when the report contains an interactive graph — the two hosted graph scripts (`litegraph.js`, `report.js`); no other external fonts, scripts, images, or runtime dependencies;
   - no unsupported claims, placeholder text, TODOs, or fabricated citations;
   - print styles when the content is useful as a document.

   - reports SHOULD use the theme's CSS-only interactivity (expand/collapse nodes and steps, hover/focus detail, tooltips) whenever the content benefits — especially workflows, pipelines, architectures, and systems.

   Beyond the analytics snippet and the two hosted graph scripts (when a graph is present), prefer zero JavaScript: interactivity comes from HTML/CSS (`details`/`summary`, `:hover`, `:focus`, `:target`) first. Use inline JavaScript only when an interaction — filtering, sorting, live search — cannot be expressed with HTML/CSS and materially improves a large report.

7. Verify the local artifact.

   Always run static checks:
   - the file exists and is non-empty;
   - exactly one `<title>` and one `<h1>` exist;
   - the PostHog snippet from `references/posthog.html` is present in `<head>`;
   - the current date appears in the filename and report metadata;
   - no `TODO`, `FIXME`, placeholder copy, accidental secrets, or external asset references other than the shared theme stylesheet link, the PostHog snippet, and (when a graph is present) the two hosted graph scripts;
   - every factual source link and local evidence reference is present;
   - opening and closing table/section structures are balanced enough to catch obvious malformed markup.

   Unless the user explicitly says to skip browser verification, render the file at desktop width (`1280` CSS pixels) and check for overflow, clipping, console errors, broken interactions, and unreadable text. Do not test mobile or tablet widths — reports are desktop-only. When the report embeds a LiteGraph graph, additionally verify in the browser that the canvas paints, a node can be dragged, and the console shows no errors. Use the `visual-qa` workflow for significant visual reports. Tear down any browser, HTTP server, process, port, or temporary artifact created for verification.

8. Check the remote destination before upload.

   ```bash
   ssh vesta.local 'test -d /data/www/sgiath.dev/llm && test -w /data/www/sgiath.dev/llm'
   ```

   Confirm the shared stylesheet is live — and, when the report embeds a graph, both graph scripts too:

   ```bash
   curl --fail --silent --show-error --head "https://sgiath.dev/llm/report.css"
   # only when the report uses an interactive graph:
   curl --fail --silent --show-error --head "https://sgiath.dev/llm/litegraph.js"
   curl --fail --silent --show-error --head "https://sgiath.dev/llm/report.js"
   ```

   If any is missing, upload the corresponding file from this skill's `references/` to `/data/www/sgiath.dev/llm/` and re-check before uploading the report.

   Store the complete filename, including `.html`, in `FILENAME`. Check whether the proposed remote path already exists:

   ```bash
   ssh vesta.local "test ! -e '/data/www/sgiath.dev/llm/${FILENAME}'"
   ```

   If it exists and replacement was not explicitly requested, switch to the timestamped filename before uploading.

9. Upload with the final filename.

   ```bash
   scp "docs/${FILENAME}" "vesta.local:/data/www/sgiath.dev/llm/${FILENAME}"
   ```

10. Verify the deployment.

   Compare local and remote hashes:

   ```bash
   sha256sum "docs/${FILENAME}"
   ssh vesta.local "sha256sum '/data/www/sgiath.dev/llm/${FILENAME}'"
   ```

   The hashes must match. Then verify the public response:

   ```bash
   curl --fail --silent --show-error --head "https://sgiath.dev/llm/${FILENAME}"
   ```

   Require HTTP `200` and an HTML content type. If Cloudflare or another cache serves an older copy, compare the response's modification metadata and retry with a cache-busting query before declaring success.

11. Report the result.

   Return:
   - the public URL;
   - the local source path;
   - confirmation that local and remote checksums match;
   - whether browser visual verification ran or was skipped.

## Guardrails

- Upload only after an explicit user request to publish, host, share, or run this skill. Creating a local HTML file alone is not authorization to upload it publicly.
- Never publish secrets, personal data, customer data, or unclear confidential material.
- Never silently overwrite an existing local or remote report.
- Never claim a browser or visual QA pass unless it actually ran against the final file.
- Never report success unless SCP completed, checksums match, and the public URL returns HTTP 200.
- Keep the artifact lean: one HTML file linking the shared theme assets, no generated asset directory, package installation, or build step.
