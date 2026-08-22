# P02 checks: Serialize and Frame a Message

## Independent numerical invariants

- Derive `P = 3 + 2S`, `F = P + 4`, and `T_ms = 8F/R_kbps` without reading the plotted values.
- For four samples, verify 11 payload bytes, 15 frame bytes, 120 wire bits, and 0.120 ms at
  1000 kb/s.
- Add every byte after the sync marker, including checksum 135. The sum must be zero modulo 256.
- Decode `0x1234` and the signed sample bytes manually; compare them with `[-150 -50 50 150]`.

## Limiting and resource-bound cases

- With zero samples, explain why the type and sequence still produce a seven-byte frame.
- At the 64-sample bound, verify that the model creates 131 payload bytes and 135 frame bytes.
- Explain why the receiver compares an untrusted declared length with bytes already received instead
  of allocating a buffer of arbitrary declared size.
- Explain why a declaration above the 131-byte protocol limit is rejected immediately rather than
  entering a timeout state.

## Broken and recovery checks

- With declared-length delta `+2`, name the exact violated assumption and explain why checksum
  evaluation is premature, two bytes are missing, and a real streaming parser needs a timeout.
- With declared-length delta `+3`, explain why the even payload length violates the message schema
  and is rejected immediately instead of entering a timeout state.
- After the malformed frame, reset delta to zero. The exact baseline bytes and accepted state must
  recover; the model retains no cross-call state.

## Interpretation questions

Answer one at a time:

1. Why does increasing sample count change both frame size and link occupancy?
2. Why does increasing link rate change occupancy but not frame bytes or efficiency?
3. Why can a valid checksum not authenticate a sender?
4. Which P01 timing effects would be added after this module's deterministic serialization time?
5. Why would an arbitrary byte stream need escaping or another resynchronization rule beyond this
   already-aligned frame model?

## Executable check

Run:

```matlab
run_checks
```

All assertions must pass before completion is considered. Then teach back the mechanism first and
the timing or failure consequence second.
