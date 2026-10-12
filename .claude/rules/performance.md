---
paths:
  - "investigations/benchmarks/*"
  - "tests/*performance*"
---

Measurement rules are in `engineering/performance.md` (see "Measuring
latency"): end-to-end numbers, several runs, fresh versus warm, a UTF-8 locale
and realistic paths in addition to the harness's `LC_ALL=C`. Record results and
environment in an investigation.
