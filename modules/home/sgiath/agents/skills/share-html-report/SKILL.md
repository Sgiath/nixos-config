---
name: share-html-report
description: Create and publish a dated, standalone HTML visualization of the current conversation's data, plan, analysis, comparison, or decision. Use ONLY when the user asks for a shareable HTML report, visual summary, single-page visualization, or to publish the current discussion to sgiath.dev/vesta.
compatibility: Requires SSH/SCP access to vesta.local and write access to /data/www/sgiath.dev/llm.
---

# Share HTML Report

Turn the useful substance of the current conversation into one HTML page styled by the shared theme stylesheet, upload it to the public `sgiath.dev` host, verify the deployment, and return its URL.

## Output contract

- Local file: `docs/YYYY-MM-DD-<topic-slug>.html`
- Remote file: `/data/www/sgiath.dev/llm/YYYY-MM-DD-<topic-slug>.html`
- Public URL: `https://sgiath.dev/llm/YYYY-MM-DD-<topic-slug>.html`
- The filename date is the current UTC date from `date -u +%F`.
- The topic slug is lowercase ASCII kebab-case using only `a-z`, `0-9`, and `-`.
- Produce exactly one HTML file that links the shared theme stylesheet and embeds the PostHog analytics snippet (see below), adding inline CSS only for report-specific visualizations. Use further inline JavaScript or SVG only when necessary. Do not create asset directories.

If the local or remote filename already exists, do not overwrite it silently. Append the current UTC time as `-HHMMSS` before `.html`, unless the user explicitly asked to replace the existing report.

## Shared theme stylesheet

All reports share one dark sci-fi theme so they look consistent without shipping their own base CSS.

- Source of truth: `references/report.css` in this skill.
- Hosted copy: `https://sgiath.dev/llm/report.css` (remote path `/data/www/sgiath.dev/llm/report.css`).
- Rendered example of everything it styles: `references/sample.html`.

Link it from the report `<head>` with the absolute URL, so the page renders identically in local preview and once deployed:

```html
<link rel="stylesheet" href="https://sgiath.dev/llm/report.css">
```

What the theme gives you:

- Bare semantic HTML is fully styled: headings, links, tables with captions, code blocks, blockquotes, lists, definition lists, figures, `details`, `hr`, and basic form controls. Write plain elements; do not restyle them.
- Layout contract: `body > header` (the `<h1>` plus a metadata line), `<main>` whose `<section>`s render as HUD panels, an optional `body > aside` that becomes a sticky right-hand side panel (status, telemetry, table of contents, report metadata — it stacks below the content on narrow screens), and `body > footer` for provenance. Without an `<aside>`, `<main>` spans the full shell.
- Utility classes for telemetry widgets: `.dot` with `.dot-ok`/`.dot-warn`/`.dot-err` (pulsing status indicator), `.bar` with an inner `<span style="width: NN%">` (animated gauge), `.cursor` (blinking terminal cursor), `.metric` (big numeric readout).
- Dark theme, print styles, and `prefers-reduced-motion` handling are built in.

Report-specific inline CSS is for content the theme cannot know about (custom diagrams, charts, one-off layouts). Reuse the theme's custom properties (`--accent`, `--fg-muted`, `--line`, `--bg-panel`, spacing steps) instead of inventing new colors or fonts.

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
   - Decision analysis: options matrix, evidence, impact, confidence, recommendation.
   - Research synthesis: findings table, source links, confidence, unresolved questions.

   The page is a technical artifact, not marketing copy. Prefer labels, tables, diagrams, and terse annotations over prose.

6. Build the visual page.

   Load the `frontend` skill and delegate visual implementation to a visual-engineering specialist when available. If the harness exposes Fable model selection, prefer Fable for the visual implementation; otherwise use the configured visual specialist without claiming it is Fable. Give the specialist the shared-theme contract above: base styling comes from `report.css`, so the work is semantic structure, content visualization, and small report-specific styles — not a new design system.

   Requirements:
   - semantic HTML landmarks and heading hierarchy;
   - responsive behavior for mobile, tablet, and desktop;
   - accessible contrast, focus states, table captions, and reduced-motion handling;
   - report-specific styles reuse the theme's custom-property tokens for color, typography, spacing, and surfaces; base elements the theme already covers are not restyled;
   - current date visible in report metadata;
   - source links that open in a new tab while internal anchors stay in the same tab;
   - no external assets other than the shared theme stylesheet link and the PostHog analytics snippet; no other external fonts, scripts, images, or runtime dependencies;
   - no unsupported claims, placeholder text, TODOs, or fabricated citations;
   - print styles when the content is useful as a document.

   Beyond the analytics snippet, prefer zero JavaScript. Use inline JavaScript only when filtering, sorting, or another interaction materially improves a large report.

7. Verify the local artifact.

   Always run static checks:
   - the file exists and is non-empty;
   - exactly one `<title>` and one `<h1>` exist;
   - the PostHog snippet from `references/posthog.html` is present in `<head>`;
   - the current date appears in the filename and report metadata;
   - no `TODO`, `FIXME`, placeholder copy, accidental secrets, or external asset references other than the shared theme stylesheet link and the PostHog snippet remain;
   - every factual source link and local evidence reference is present;
   - opening and closing table/section structures are balanced enough to catch obvious malformed markup.

   Unless the user explicitly says to skip browser verification, render the file at `375`, `768`, and `1280` CSS pixels and check for overflow, clipping, console errors, broken interactions, and unreadable text. Use the `visual-qa` workflow for significant visual reports. Tear down any browser, HTTP server, process, port, or temporary artifact created for verification.

8. Check the remote destination before upload.

   ```bash
   ssh vesta.local 'test -d /data/www/sgiath.dev/llm && test -w /data/www/sgiath.dev/llm'
   ```

   Confirm the shared stylesheet is live:

   ```bash
   curl --fail --silent --show-error --head "https://sgiath.dev/llm/report.css"
   ```

   If it is missing, upload `references/report.css` from this skill to `/data/www/sgiath.dev/llm/report.css` and re-check before uploading the report.

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
- Keep the artifact lean: one HTML file linking the shared theme stylesheet, no generated asset directory, package installation, or build step.
