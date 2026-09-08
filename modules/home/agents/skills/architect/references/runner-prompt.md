# Architect runner prompt

The orchestrator supplies the task, traced integration constraints, isolated working directory, and output path. Produce one candidate design package using the [rationale template](rationale-template.md); no need to run the parent workflow yourself.

Write caller usage and two or three realistic call sites first. Derive the types, function signatures, and module map from them. Include invariants, error modes, ownership of state, and dominant access patterns so a reader can trace input to output without implementation bodies.

Use `not implemented` bodies and pseudocode to distinguish sketches from working code. Explain how concurrent writers, retries, and partial failures affect the design when those conditions apply. Keep validation at external inputs and avoid exposing internal details only for tests.

Name concrete alternatives and why you rejected them. Produce a distinct, coherent design rather than hedging toward what other runners might choose.
