# P03 checks: Compare TCP and UDP Behavior

## Independent numerical invariants

- Derive the P02 serialization term: `8(15 bytes)/(1000 kb/s) = 0.120 ms`, then add the 20 ms
  path delay to obtain 20.12 ms no-loss service.
- From sends `[0 200 400 600 800 1000]` ms and loss index 3, derive UDP application delivery
  `[20.12 220.12 NaN 620.12 820.12 1020.12]` ms.
- Add the 1000 ms controlled retransmission timeout to record 3. Derive TCP network arrival
  `[20.12 220.12 1420.12 620.12 820.12 1020.12]` ms.
- Apply the contiguous-prefix recurrence. TCP application availability must be
  `[20.12 220.12 1420.12 1420.12 1420.12 1420.12]` ms.
- Verify TCP ages `[20.12 20.12 1020.12 820.12 620.12 420.12]` ms and head-of-line waits
  `[0 0 0 800 600 400]` ms.
- At an 800 ms deadline, verify TCP eventual/on-time counts `6/4` and UDP counts `5/5`.

## Sweep and limiting cases

- With periods `[100 200 400]` ms, derive TCP on-time counts `[3 4 5]` and maximum head-of-line
  waits `[900 800 600]` ms. Explain why UDP stays at five on-time records.
- With timeouts `[1000 1250 1500]` ms, derive TCP on-time counts `[4 3 2]` and maximum ages
  `[1020.12 1270.12 1520.12]` ms. Explain why UDP remains invariant.
- Set loss index to zero. TCP and UDP delivery times must match, with no retransmission,
  head-of-line wait, loss, or deadline miss.
- Lose only the last record. TCP still retransmits it, but there is no later record to wait behind
  it; head-of-line blocked count must be zero.
- Compare a deadline just below and exactly at 20.12 ms. State why equality counts as on time and
  why changing the deadline cannot change either transport timeline.
- Repeat exact-deadline classification at the maximum `1e6 ms` record period. Confirm that relative
  age arithmetic still counts all 64 no-loss records on time.
- At the limiting case where a recovered range and the next range are mathematically coincident,
  confirm the comparison tolerance reports zero head-of-line wait and zero retained bytes.
- At the 64-record bound, confirm at most 65 modeled TCP record-range attempts, 64 UDP datagram
  attempts, and 945 retained P02 application bytes. These are bounded teaching-bookkeeping values,
  not TCP segment or operating-system buffer measurements.

## Broken, timeout, and recovery checks

- Explain why a 1000 ms retransmission timeout is an analytical event rather than a real wait in
  this model. Name the omitted TCP mechanisms before treating the plot as a network prediction.
- For two exact 15-byte P02 frames and TCP read chunks `[9 21]`, show why a naive one-read parser
  recovers zero frames. Verify that a bounded parser retains 9 bytes, then checks sync, declared
  length, the 135-byte policy, and checksum to recover two frames with zero remainder.
- Verify that a two-byte partial header waits, an over-limit declaration rejects before checksum,
  a bad sync and corrupt complete frame reject, and a subsequent valid parse recovers cleanly.
- Feed a third valid frame to the two-frame parser fixture. It must stop at two, leave 15 stream
  bytes unconsumed, and report the global frame limit instead of growing its frame array.
- Explain why the displayed UDP `[15 15]` reads demonstrate datagram boundaries only for delivered
  datagrams with adequate buffers, not reliable or ordered delivery.
- After malformed inputs and the broken parser case, call the baseline again. Every output must
  recover exactly because the model retains no global, persistent, file, timer, or network state.
- Cancellation is outside this finite synchronous model. The deadline classifies usefulness; it
  does not abort TCP or retract a delivered UDP datagram.

## Interpretation questions

Answer one at a time:

1. Why can UDP expose record 4 while record 3 is absent?
2. Why can TCP deliver all six records but miss two application deadlines?
3. Which lever changes how many later byte ranges accumulate behind the TCP gap?
4. Why does changing the TCP timeout leave the modeled UDP outputs unchanged?
5. Why is P02 framing still required on TCP even though TCP is reliable and ordered?
6. Which window and receive-retention assumptions make the displayed head-of-line result possible?
7. What evidence would be needed before treating these analytical results as socket, protocol,
   MATLAB-runtime, bench, or field behavior?

## Executable check and teach-back

Run:

```matlab
run_checks
```

All assertions must pass before completion is considered. Then teach back the mechanism first and
the application deadline or message-boundary consequence second.
