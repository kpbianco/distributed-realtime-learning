# P02 — Serialize and Frame a Message

**Track:** Distributed Real-Time Systems and Networks  
**Phase 1:** Network behavior  
**Status:** implemented

## Guiding question

What inputs, observable effects, and failure modes matter when you serialize and Frame a Message?

## Compounds on

P01 showed that network delay and clock error distort observed timing. P02 adds the deterministic
link-occupancy term that exists before propagation and jitter: a message must first become bytes,
and those bytes must cross the link.

## Computational mental model

Serialization maps agreed fields to an agreed byte order. Once a receiver is aligned at the first
sync byte, framing supplies an expected boundary and an inconsistency check. This lesson uses a
transparent base-MATLAB protocol:

| Region | Bytes | Meaning |
| --- | ---: | --- |
| Sync | 1 | `0x7E` marks the start in an already-aligned capture |
| Declared payload length | 2 | Unsigned big-endian byte count |
| Serialized payload | `3 + 2S` | Type, sequence, then `S` signed 16-bit samples |
| Checksum | 1 | Two's-complement sum over length and payload |

For frame length `F` bytes and link rate `R` kb/s,

`wire bits = 8F`, `serialization time (ms) = 8F/R`, and `efficiency = payload bytes/F`.

The checksum exposes accidental inconsistency; it is not authentication. The model is bounded to
64 samples (131 payload bytes), rejects larger declarations before waiting, and never allocates
memory from an untrusted declared length.

## Required learning flow

1. Read the schema and predict which lever changes bytes on the wire.
2. Visualize the deterministic four-sample baseline.
3. Sweep sample count while holding link rate fixed, then explain the changed view.
4. Reset and sweep link rate while holding the frame fixed, then explain the changed view.
5. Deliberately over-declare the payload length and observe the receiver wait/timeout state.
6. Run independent numerical checks and finish with a mechanism-first teach-back.

## Files

- `model.m` — bounded serialization, framing, receiver-state, and timing calculations.
- `experiment.m` — baseline views, two independent sweeps, and the broken length case.
- `interactive.m` — sample-count, link-rate, and declared-length controls.
- `lesson.m`, `lesson.md`, and `walkthrough.md` — notebook and tutor sequence.
- `checks.md` and `run_checks.m` — interpretation prompts and executable invariants.

No toolbox is required. Static repository checks do not imply MATLAB-runtime, UI, numerical-fidelity,
bench, HIL, field, or production validation. This compact frame does not escape `0x7E` payload
bytes or model stream resynchronization; a production protocol needs byte stuffing, a stronger
delimiter rule, or another explicit recovery strategy.
