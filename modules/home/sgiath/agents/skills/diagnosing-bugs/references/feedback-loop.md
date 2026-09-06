# Bug diagnosis feedback loop

## Choose a reproduction seam

Inspect relevant `CONTEXT.md` and local ADRs when they explain the affected modules. Read enough code to locate the failing path and build its reproduction, rather than choosing a cause from code inspection alone.

Choose the cheapest seam that reaches the exact reported symptom:

- Existing test seam: unit, integration, or end-to-end, as the failure requires.
- HTTP request against a running dev server, or CLI invocation with fixture input and expected output.
- Browser automation observing DOM, console, and network behavior.
- Replay of a captured request, payload, or event log through the affected path.
- Throwaway harness running the relevant subsystem with controlled dependencies.
- Property/fuzz loop for input-dependent failures; retain the failing input and seed.
- Automated state bisection across commits, datasets, or versions (`git bisect run` when appropriate).
- Differential run comparing identical input across old/new versions or configurations.
- Human-assisted reproduction only when automation cannot drive the required interaction: copy and adapt [hitl-loop.template.sh](../scripts/hitl-loop.template.sh).

The human-assisted template exposes `step "<instruction>"` (wait for Enter) and `capture VAR "<question>"` (record an answer). Run the adapted script with Bash in an interactive terminal; its final `KEY=VALUE` output supplies the observed symptom. The bundled Export-button scenario is an example, not a ready reproduction of an arbitrary bug.

## Establish the failure signal

Before causal experiments, record one reproduction command already run and its output. It must exercise the actual path and detect the user's exact symptom, not merely exit successfully. Use the user's reported failure as evidence, not as something to reconfirm; run the command to establish the diagnostic loop.

Keep the loop unattended where possible, deterministic, and short enough to rerun frequently (seconds where feasible). Cache setup, narrow unrelated initialization, pin time and random seeds, and isolate filesystem/network state. Record deviations that the real scenario requires rather than replacing it with an easier but different bug.

For intermittent failures, record attempts and reproduction rate. Repeated triggers, concurrency, stress, controlled timing windows, or injected delays can raise the rate; preserve the conditions so before/after measurements remain comparable. One passing run does not prove an intermittent bug fixed.

If no usable loop is possible, report attempts and the exact missing prerequisite: environment access, a captured HAR/log/core dump or timestamped recording, or authorization for temporary production instrumentation. Do not present an untested cause as a diagnosis or add production instrumentation without permission.

## Minimize and discriminate

Capture the exact error, wrong output, or timing. Reduce input, callers, configuration, data, and steps one at a time, keeping changes only while the failure signal remains. Preserve the original scenario for final verification. The minimized scenario should retain the elements necessary to cause the failure; record any reduction limit.

Rank plausible causes and state each one's falsifiable prediction: “If X causes this, changing Y should remove the symptom; changing Z should worsen it.” Share material alternatives without making a review pause a prerequisite for testing them.

Change one variable per probe. Prefer debugger/REPL inspection or targeted logs at boundaries that distinguish predictions, not indiscriminate logging. Give temporary logs a unique searchable prefix such as `[DEBUG-a4f2]`.

For performance regressions, establish a comparable timing/profile/query-plan baseline before changing code; use that measurement as the bisection signal rather than substituting log volume for performance evidence.

## Fix and verify

A regression seam must reach the real call-site pattern: a single-caller unit test is insufficient when the failure needs several callers or a longer chain. Where a suitable seam exists, turn the minimized reproduction into a failing regression test before the fix, observe failure, apply the fix, and observe success. If no suitable seam exists, record the limitation instead of adding a shallow test that gives false confidence.

Completion requires:

- The original, unminimized reproduction no longer exhibits the symptom; intermittent/performance cases use comparable conditions and measurements.
- The regression test passes, or the missing seam and available reproduction proof are documented.
- Temporary `[DEBUG-...]` instrumentation is removed, checked by its prefix.
- Throwaway prototypes are removed or moved to a clearly marked debug location.
- The supported cause and verification evidence are reported; include the cause in a commit/PR message if one is requested.

After the fix, note a concrete preventive architectural change if the evidence warrants it (for example, a missing test seam or hidden caller coupling). Do not expand the fix into that redesign without user scope.
