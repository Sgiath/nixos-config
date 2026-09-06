---
name: show-me
description: "Use when asked to explain the current topic visually."
disable-model-invocation: true
---

# Show me

Choose the smallest view that answers the current question. Place each visual beside the brief text it supports.

- Logic or algorithm: pseudocode.
- Runtime control flow: call tree.
- UI structure: component tree with relevant state, ownership, and file paths.
- File responsibilities: shallow annotated file tree.
- Interactions or data flow: Mermaid sequence or flow diagram.
- A change to an established shape: a focused diff. Show the whole block instead when most of it is new, omitted context would hide ownership or order, or the user needs a copyable target.

Include only the calls, files, props, states, and boundaries needed to explain the question or competing options. Do not combine every format.

For a dense UI/layout comparison or concept that needs more than a diagram, create one focused HTML file: a diagram, infographic, or short slide deck. Match the product’s colors, typography, spacing, and components; use real labels and data; support desktop and mobile. Open it with the platform opener, for example:

```sh
xdg-open path/to/show-me-{description}.html
```
