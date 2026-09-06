# Build and publish

Read [the theme contract](theme.md) before building. Asset paths below are relative to the skill directory.

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

4. Choose the filename and create an external temporary workspace.

   Run:

   ```bash
   date -u +%F
   date -u +%H%M%S
   TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/share-html-report.XXXXXX")"
   ```

   Derive a short descriptive slug from the report subject. Example:

   ```text
   2026-08-03-hackney-dependency-maintenance.html
   ```

   Store the complete filename in `FILENAME` and use `REPORT_PATH="${TEMP_DIR}/${FILENAME}"` for all generation, static validation, and upload steps. Do not create the report anywhere inside the repository. Ensure the temporary directory is removed on both success and failure.

5. Choose a visualization grammar that matches the content.

   - Data or inventory: sortable-looking registry, table, compact metrics, comparisons.
   - Plan or roadmap: phases, dependencies, timeline, milestones, decision gates.
   - Architecture or flow: start with labeled sections, a relationship table, or a compact stepper; use semantic boxes and connectors only when spatial relationships add clarity.
   - Workflow or system: default to ordered steps, a table, or a stepper (`.steps`). Consider a node graph only if it passes every criterion in “Optional interactive node graphs”; do not use one for a primarily linear flow.
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

   - use interactivity sparingly. Do not add expandable nodes, graphs, hover details, or tooltips when the same information is clearer when immediately visible. A report does not need an interactive element.

   Beyond the analytics snippet and the two hosted graph scripts (only when a graph passes the stated criteria), prefer zero JavaScript. If interaction materially improves a large report, prefer HTML/CSS (`details`/`summary`, `:hover`, `:focus`, `:target`) before inline JavaScript. Do not add interaction for visual novelty.

7. Verify the temporary artifact.

   Run every check against `${REPORT_PATH}`, never a repository path. Always run static checks:
   - the file exists and is non-empty;
   - exactly one `<title>` and one `<h1>` exist;
   - the PostHog snippet from `references/posthog.html` is present in `<head>`;
   - the current date appears in the filename and report metadata;
   - no `TODO`, `FIXME`, placeholder copy, accidental secrets, or external asset references other than the shared theme stylesheet link, the PostHog snippet, and (when a graph is present) the two hosted graph scripts;
   - every factual source link and local evidence reference is present;
   - opening and closing table/section structures are balanced enough to catch obvious malformed markup.

   Optionally perform one bounded headless-Chromium screenshot smoke check. This is the only permitted browser-based verification: do not launch an interactive browser, local HTTP server, visual-QA workflow, multi-viewport suite, or broader browser automation. Cap the render at 60 seconds, use one desktop viewport, confirm the screenshot was produced, and optionally inspect that single image for obvious catastrophic rendering failures. For example:

   ```bash
   QA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/share-html-report-qa.XXXXXX")"
   timeout 60 chromium \
     --headless=old \
     --no-sandbox \
     --disable-gpu \
     --disable-dev-shm-usage \
     --window-size=1440,1000 \
     --screenshot="${QA_DIR}/report.png" \
     --virtual-time-budget=5000 \
     --user-data-dir="${QA_DIR}/profile" \
     "file://${REPORT_PATH}" >/dev/null 2>&1
   test -s "${QA_DIR}/report.png"
   ```

   Failure to render or create a non-empty screenshot is a failed smoke check. Do not spend time iterating on subjective visual polish; the user performs the detailed visual inspection after publication. Remove `${QA_DIR}` after the check, including on failure.

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
   scp "${REPORT_PATH}" "vesta.local:/data/www/sgiath.dev/llm/${FILENAME}"
   ```

10. Verify the deployment.

   Compare the temporary and remote hashes:

   ```bash
   sha256sum "${REPORT_PATH}"
   ssh vesta.local "sha256sum '/data/www/sgiath.dev/llm/${FILENAME}'"
   ```

   The hashes must match. Then verify the public response:

   ```bash
   curl --fail --silent --show-error --head "https://sgiath.dev/llm/${FILENAME}"
   ```

   Require HTTP `200` and an HTML content type. If Cloudflare or another cache serves an older copy, compare the response's modification metadata and retry with a cache-busting query before declaring success.

11. Remove the temporary artifact and report the result.

   After all deployment checks pass, delete the entire temporary workspace:

   ```bash
   rm -rf -- "${TEMP_DIR}"
   ```

   Confirm the temporary report no longer exists before responding. If any earlier step fails, remove `${TEMP_DIR}` before reporting the failure as well.

   Return:
   - the public URL;
   - confirmation that the temporary and remote checksums matched before cleanup;
   - confirmation that the temporary local copy was deleted and no report was written into the repository;
   - whether the optional single-screenshot Chromium smoke check ran or was skipped.

## Guardrails

- Upload only after an explicit user request to publish, host, share, or run this skill. Creating a local HTML file alone is not authorization to upload it publicly.
- Never publish secrets, personal data, customer data, or unclear confidential material.
…
- Treat node graphs as exceptional. If a simpler table, list, stepper, or prose structure explains the situation, use the simpler structure and do not load the graph scripts.