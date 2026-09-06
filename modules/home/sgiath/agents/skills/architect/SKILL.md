---
name: architect
description: "Use for /architect or an explicit request for architecture sketches followed by implementation."
disable-model-invocation: true
---

# Architect

Design from caller usage, compare sketches, then implement the selected shape. Sketch bodies may contain `not implemented` and pseudocode; the completed implementation may not.

## Phase A: Ground the problem

Trace affected callers, data flow, ownership, existing types, and integration constraints. Recover the rationale behind existing boundaries when changing them. Skip existing-system tracing only for genuinely isolated greenfield work.

## Sketch and synthesize

Use [arena](../arena/SKILL.md) with the task and grounding. Give each runner the [runner prompt](references/runner-prompt.md); each produces caller usage first, types, signatures, a module map where needed, and the [rationale](references/rationale-template.md).

Use the harness’s configured or available architect runners, honoring any user-selected models. Prefer model diversity where supported. Arena's decision fills the rationale's synthesis section.

## Implement or checkpoint

Proceed to implementation by default. Pause for sign-off only if the user asks for a checkpoint, such as “/architect with checkpoint” or “show me before implementing.” Design-only requests end with the design package.

Replace sketch bodies with working code. Record meaningful deviations: a missing requirement, an incorrect type, or a caller forced to know implementation details can change the design. Repeated workarounds of the same shape, escape-hatch types, or unexpected shared writes warrant revisiting the sketch. Feed those concrete lessons into another grounded candidate comparison rather than patching around an unsuitable architecture.

## Output

Deliver working, verified code plus the usage/type sketch and concise rationale. Small changes need one sketch file; larger changes also need a module map. If the user requested design only or a checkpoint, identify the sketch as unimplemented and report unresolved decisions.
