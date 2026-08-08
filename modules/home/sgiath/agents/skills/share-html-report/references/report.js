/* ==========================================================================
   share-html-report — report.js
   Declarative LiteGraph bootstrapper for interactive node graphs in reports.

   Usage (author-facing):

     <script src="https://sgiath.dev/llm/litegraph.js" defer></script>
     <script src="https://sgiath.dev/llm/report.js" defer></script>

     <figure class="graph">
       <script type="application/json">
       {
         "height": 460,
         "nodes": [
           { "id": "button", "title": "button", "sub": "momentary",
             "body": "Debounced in firmware, 20 ms window.",
             "pos": [40, 60], "size": [180, 90],
             "outputs": ["SIG"], "inputs": [], "accent": "a" }
         ],
         "links": [ ["button:SIG", "pico:GP2", "a"] ]
       }
       </script>
       <figcaption>Fig N — drag nodes, pan, zoom</figcaption>
     </figure>

   Spec reference:
     height  — optional canvas height in CSS px (default 440)
     nodes[] — id (unique string), title, sub (muted line under title),
               body (word-wrapped paragraph), pos [x,y], size [w,h] optional,
               inputs / outputs (arrays of slot-name strings, untyped),
               accent (palette letter a-e, tints the title bar)
     links[] — ["fromId:outputName", "toId:inputName", "variantLetter"]
               unknown node/slot refs are console.warn'd and skipped

   Palette (matches report.css):
     a = #ffb000 amber   b = #6fc7b2 teal   c = #59c37a green
     d = #b18cff violet  e = #ff4d4d red

   Graphs are display-only: draggable nodes, pan, wheel zoom, collapse.
   No node creation, no searchbox, no context menu, no graph execution
   (graph.start() is never called — LGraphCanvas's own render loop draws).
   ========================================================================== */

(function () {
  "use strict";

  /* ---- palette (mirrors report.css custom properties) ------------------- */

  var ACCENTS = {
    a: "#ffb000", // amber  — var(--accent)
    b: "#6fc7b2", // teal   — var(--accent-2)
    c: "#59c37a", // green  — var(--ok) family
    d: "#b18cff", // violet — var(--accent-3)
    e: "#ff4d4d", // red    — var(--err)
  };

  /* dark tints of the accents used as node title-bar colors */
  var TITLE_TINTS = {
    a: "#3a2c10",
    b: "#16332d",
    c: "#143321",
    d: "#241c38",
    e: "#3a1414",
  };

  var DEFAULT_HEIGHT = 440;

  /* def handoff: LiteGraph.createNode() calls the registered constructor
     with no arguments, so the per-node spec is passed through this
     module-scoped slot, read once by the constructor, then cleared. */
  var currentDef = null;

  /* ---- boot -------------------------------------------------------------- */

  function boot() {
    if (!window.LiteGraph || !window.LGraph || !window.LGraphCanvas) {
      console.error(
        "report.js: window.LiteGraph not found — load litegraph.js before report.js."
      );
      return;
    }

    applyTheme();
    clearDefaultNodes();
    registerReportNode();

    var handles = [];
    var figures = document.querySelectorAll("figure.graph");
    for (var i = 0; i < figures.length; i++) {
      var handle = initFigure(figures[i]);
      if (handle) handles.push(handle);
    }

    /* debug handle for QA: window.__reportGraphs[n].{graph,canvas} */
    window.__reportGraphs = handles;

    /* pause every canvas while the tab is hidden */
    document.addEventListener("visibilitychange", function () {
      for (var j = 0; j < handles.length; j++) {
        handles[j].updatePause();
      }
    });
  }

  /* ---- LiteGraph global theme (amber mission-console) -------------------- */

  function applyTheme() {
    var LG = window.LiteGraph;

    LG.NODE_TITLE_COLOR = "#ffb000";
    LG.NODE_SELECTED_TITLE_COLOR = "#ffd766";
    LG.NODE_TEXT_COLOR = "#ddd3c0";
    LG.NODE_TEXT_SIZE = 13;
    LG.NODE_TITLE_HEIGHT = 28;
    LG.NODE_SLOT_HEIGHT = 20;

    LG.NODE_DEFAULT_COLOR = "#2a2118"; // title bar
    LG.NODE_DEFAULT_BGCOLOR = "#0f0c08"; // body
    LG.NODE_DEFAULT_BOXCOLOR = "#7a6a4f"; // collapse box / status glyph

    LG.WIDGET_BGCOLOR = "#131009";
    LG.WIDGET_OUTLINE_COLOR = "#463a22";
    LG.WIDGET_TEXT_COLOR = "#ddd3c0";
    LG.WIDGET_SECONDARY_TEXT_COLOR = "#a89e8a";
  }

  /* Reports never create nodes interactively: drop every built-in node type
     (and the searchbox extras that index them) so nothing can be spawned. */
  function clearDefaultNodes() {
    var LG = window.LiteGraph;
    var types = Object.keys(LG.registered_node_types || {});
    for (var i = 0; i < types.length; i++) {
      delete LG.registered_node_types[types[i]];
    }
    LG.searchbox_extras = {};
  }

  /* ---- generic report node ----------------------------------------------- */

  function registerReportNode() {
    var LG = window.LiteGraph;

    function ReportNode() {
      var def = currentDef || {};
      var i;

      if (def.inputs) {
        for (i = 0; i < def.inputs.length; i++) {
          this.addInput(String(def.inputs[i]), null); // untyped: anything connects
        }
      }
      if (def.outputs) {
        for (i = 0; i < def.outputs.length; i++) {
          this.addOutput(String(def.outputs[i]), null);
        }
      }

      this.title = def.title || def.id || "node";

      /* sub/body live in properties so onDrawForeground can read them */
      this.properties = {
        sub: def.sub || "",
        body: def.body || "",
        accent: def.accent || "",
      };

      if (def.accent && TITLE_TINTS[def.accent]) {
        this.color = TITLE_TINTS[def.accent]; // tinted title bar
        this.boxcolor = ACCENTS[def.accent]; // accent status glyph
      }

      if (def.size) {
        this.size = [def.size[0], def.size[1]];
      } else {
        var s = this.computeSize();
        if (this.properties.body) s[1] += 44; // rough body allowance; onDrawForeground refines
        this.size = s;
      }
    }

    ReportNode.title = "node";
    ReportNode.desc = "share-html-report display node";

    /* Draw the muted sub line and the word-wrapped body under the slots,
       growing the node to fit (ported from the owner's litegraph hook). */
    ReportNode.prototype.onDrawForeground = function (ctx) {
      if (this.flags.collapsed) return;

      var LG = window.LiteGraph;
      var pad = 10;
      var maxWidth = this.size[0] - pad * 2;
      if (maxWidth <= 0) return;

      var slotRows = Math.max(
        this.inputs ? this.inputs.length : 0,
        this.outputs ? this.outputs.length : 0
      );
      var y = slotRows * LG.NODE_SLOT_HEIGHT + 6;

      ctx.textAlign = "left";

      if (this.properties.sub) {
        ctx.font = "11px monospace";
        ctx.fillStyle = "#a89e8a";
        y += 14;
        ctx.fillText(this.properties.sub, pad, y);
        y += 4;
      }

      var lines = [];
      if (this.properties.body) {
        ctx.font = "12px monospace";
        ctx.fillStyle = "#ddd3c0";
        lines = wrapText(ctx, String(this.properties.body), maxWidth);
        var lineHeight = 16;
        for (var i = 0; i < lines.length; i++) {
          ctx.fillText(lines[i], pad, y + (i + 1) * lineHeight);
        }
        y += lines.length * lineHeight;
      }

      /* auto-grow to fit the drawn text */
      var minHeight = y + pad;
      if (this.size[1] < minHeight - 2) {
        this.size[1] = minHeight;
        this.setDirtyCanvas(true, true);
      }
    };

    LG.registerNodeType("report/node", ReportNode);
  }

  /* greedy word wrap using the current ctx font (hook's wrapText pattern) */
  function wrapText(ctx, text, maxWidth) {
    var lines = [];
    var paragraphs = text.split("\n");

    for (var p = 0; p < paragraphs.length; p++) {
      var paragraph = paragraphs[p];
      if (!paragraph) {
        lines.push("");
        continue;
      }

      var words = paragraph.split(" ");
      var currentLine = "";

      for (var w = 0; w < words.length; w++) {
        var testLine = currentLine ? currentLine + " " + words[w] : words[w];
        if (ctx.measureText(testLine).width > maxWidth && currentLine) {
          lines.push(currentLine);
          currentLine = words[w];
        } else {
          currentLine = testLine;
        }
      }
      if (currentLine) lines.push(currentLine);
    }

    return lines;
  }

  /* ---- per-figure setup --------------------------------------------------- */

  function initFigure(figure) {
    var specEl = figure.querySelector('script[type="application/json"]');
    if (!specEl) return null;

    var spec;
    try {
      spec = JSON.parse(specEl.textContent);
    } catch (e) {
      console.error("report.js: invalid JSON spec in figure.graph", e);
      return null;
    }
    if (!spec || !Array.isArray(spec.nodes)) {
      console.error("report.js: figure.graph spec needs a nodes[] array");
      return null;
    }

    var height = typeof spec.height === "number" ? spec.height : DEFAULT_HEIGHT;

    /* the canvas goes before any figcaption so the caption stays underneath */
    var canvasEl = document.createElement("canvas");
    canvasEl.style.display = "block";
    canvasEl.style.width = "100%";
    canvasEl.style.height = height + "px";
    canvasEl.setAttribute("role", "img");
    var figcaption = figure.querySelector("figcaption");
    figure.insertBefore(canvasEl, figcaption || null);

    var graph = new window.LGraph();
    var canvas = new window.LGraphCanvas(canvasEl, graph);

    /* canvas look */
    canvas.background_image = null;
    canvas.clear_background_color = "#0b0806";
    canvas.render_shadows = false;
    canvas.render_canvas_border = false;
    canvas.default_link_color = "#a89e8a";
    canvas.connections_width = 2;
    canvas.render_connection_arrows = false;
    canvas.links_render_mode = window.LiteGraph.SPLINE_LINK; // curved links
    canvas.show_info = false; // hide litegraph's FPS/debug overlay
    /* port dots: warm palette instead of litegraph's default green */
    canvas.default_connection_color = {
      input_off: "#7a6a4f",
      input_on: "#ffb000",
      output_off: "#7a6a4f",
      output_on: "#ffb000",
    };

    /* interaction: drag/pan/zoom/collapse stay on; authoring UI off */
    canvas.allow_searchbox = false;
    canvas.processContextMenu = function () {}; // per-instance no-op override
    figure.addEventListener("contextmenu", function (e) {
      e.preventDefault();
    });

    buildGraph(graph, spec);

    /* Never graph.start(): these graphs are display-only. LGraphCanvas's own
       render loop (started in its constructor) handles drawing. */

    /* sizing: fill figure width at the spec'd height */
    function resizeCanvas() {
      var w = figure.clientWidth;
      if (w <= 0) return;
      canvas.resize(w, height);
      canvas.setDirty(true, true);
    }
    resizeCanvas();
    window.addEventListener("resize", resizeCanvas);
    if (typeof ResizeObserver !== "undefined") {
      new ResizeObserver(resizeCanvas).observe(figure);
    }

    /* performance: pause the render loop while offscreen or tab-hidden */
    var inViewport = true;
    function updatePause() {
      canvas.pause_rendering = document.hidden || !inViewport;
      if (!canvas.pause_rendering) canvas.setDirty(true, true);
    }
    if (typeof IntersectionObserver !== "undefined") {
      new IntersectionObserver(function (entries) {
        inViewport = entries[0].isIntersecting;
        updatePause();
      }).observe(figure);
    }

    return { graph: graph, canvas: canvas, updatePause: updatePause };
  }

  /* translate the declarative spec into nodes + links */
  function buildGraph(graph, spec) {
    var LG = window.LiteGraph;
    var byId = {};
    var i;

    for (i = 0; i < spec.nodes.length; i++) {
      var def = spec.nodes[i];
      if (!def || !def.id) {
        console.warn("report.js: node without id skipped", def);
        continue;
      }
      currentDef = def;
      var node = LG.createNode("report/node");
      currentDef = null;
      if (!node) continue;
      if (def.pos) node.pos = [def.pos[0], def.pos[1]];
      graph.add(node);
      byId[def.id] = node;
    }

    var links = Array.isArray(spec.links) ? spec.links : [];
    for (i = 0; i < links.length; i++) {
      connectLink(byId, links[i]);
    }
  }

  /* one link: ["fromId:outputName", "toId:inputName", "variantLetter"] */
  function connectLink(byId, entry) {
    if (!Array.isArray(entry) || entry.length < 2) {
      console.warn("report.js: malformed link entry skipped", entry);
      return;
    }

    var from = String(entry[0]).split(":");
    var to = String(entry[1]).split(":");
    var variant = entry[2];

    var fromNode = byId[from[0]];
    var toNode = byId[to[0]];
    if (!fromNode || !toNode) {
      console.warn("report.js: link references unknown node", entry);
      return;
    }

    var outSlot = fromNode.findOutputSlot(from[1]);
    var inSlot = toNode.findInputSlot(to[1]);
    if (outSlot === -1 || inSlot === -1) {
      console.warn("report.js: link references unknown slot", entry);
      return;
    }

    var link = fromNode.connect(outSlot, toNode, inSlot);
    if (link && variant && ACCENTS[variant]) {
      link.color = ACCENTS[variant];
    }
  }

  /* ---- go ----------------------------------------------------------------- */

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
