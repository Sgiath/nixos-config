---
name: humanizer
description: "Use when asked to humanize prose or identify formulaic AI writing patterns."
---

# Humanizer

Preserve the author's information and voice while removing formulaic prose. Do not invent facts, names, numbers, dates, quotes, or citations to make a rewrite more vivid. Fiction is the exception; in factual writing, use only details supplied by the source or user. Cut unsupported filler rather than decorating it with invented evidence.

A supplied writing sample outranks house style, including punctuation preferences. Match its sentence lengths, vocabulary, transitions, and deliberate quirks. Add opinions, humor, or first person only when the author's voice and genre call for them; technical, legal, encyclopedic, and reference writing should stay neutral.

## Choose the mode

- Pasted prose: return the final rewrite. Include an audit or draft only if requested.
- File: rewrite prose in place; leave code blocks, frontmatter, data, and link targets unchanged. Report a short change summary.
- Embedded in another task: output only the final text.
- Detection request: quote each flagged phrase and name its pattern. Do not rewrite unless asked, and do not assign an AI-probability score. Patterns are editing evidence, not proof of authorship.

## Edit and check

Use the [pattern catalogue](references/patterns.md) for matching problems and examples, and [detection guidance](references/detection.md) to avoid false positives. Preserve quotations, proper names, literal technical terms, unusual details, and deliberate voice choices. Look for clusters rather than flagging one transition word or punctuation mark.

Revise, then check the result against the source for lost information or invented detail. Keep factual content even when an example in the catalogue illustrates a shorter excerpt. By default replace em/en dashes and theatrical punctuation, but preserve a supplied author's established style. Deliver according to the mode above without exposing an internal draft-and-audit loop.

Source: [Wikipedia: Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing), maintained by WikiProject AI Cleanup.
