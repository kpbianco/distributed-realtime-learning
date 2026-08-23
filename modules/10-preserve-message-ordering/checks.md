# P10 checks: Preserve Message Ordering

Run `run_checks` from this module folder, or run `run_module_checks('P10')` from the repository
root after P10 is marked implemented. The executable checks independently cover:

- exact baseline send, delay, arrival, raw-order inversion, strict delivery, holding, buffer,
  completion, and final-state calculations;
- repeatability, accepted integer/logical classes, fractional scale/timeout, and fixed tie-breaking;
- delay-scale sweep `[0 0.5 1 2]` and independent `t_send+s*d` calculations;
- capacity sweep `[0 1 2] messages`, zero-capacity failure, exact capacity-two completion, and
  capacity-above-need invariance;
- zero-delay/no-reordering limits, naive policy correct only by chance at that limit, and maximum
  bounded scale/timeout/capacity;
- the deliberately broken raw-arrival policy, four delivery inversions, two state regressions,
  stale final version `5`, and zero reorder holding;
- raw-arrival delivery with message 3 absent consumes all five arrivals without a strict-policy
  timeout or delivery suppression, remaining distinct from the ordered timeout outcome;
- exact `20 ms` gap-deadline acceptance, just-before timeout, message-3 absence, buffered/future
  delivery suppression, and ordered-prefix retention;
- buffer overflow after prefix `[1 2]`, no rollback, no actual asynchronous cancellation/wait,
  fresh-call recovery targets, and deterministic recovery after malformed calls;
- stable malformed-input identifiers for empty, text, vector, complex, nonfinite, negative,
  fractional/out-of-range capacity, invalid logical controls, and over-bound values;
- fixed resource counts, bounded loops/storage, presentation isolation, base-MATLAB compatibility,
  and explicit single-sender/causal/global-order/consensus/transport/network claim boundaries.

## Interpretation questions

Answer one at a time after observing the relevant view.

1. How can every message be valid while raw arrival order still violates sender order?
2. Which term in `t_arrive(k)=t_send(k)+s*d(k)` lets a later send arrive first?
3. Why does sequence `2` wait `5 ms` in the baseline even though it arrived before sequence `1`?
4. Why do sequence numbers detect a gap without making any network path faster?
5. What does `40 message-ms` count, and why is it not bandwidth or processing utilization?
6. Why can delay scale change arrival inversions and holding without changing final strict state?
7. Why is capacity `2 messages` sufficient while capacity `1 message` fails at sequence `6`?
8. Why does a zero-capacity receiver work at zero delay but fail at the baseline delay scale?
9. Which two transitions regress state under raw arrival delivery, and why does final version become `5`?
10. Why is naive delivery appearing correct at scale zero not an ordering guarantee?
11. Why is message `3` accepted at the exact `55 ms` deadline but rejected just after expiration?
12. Why does fail-closed timeout preserve order yet leave only a stale, incomplete prefix?
13. What is suppressed after timeout, and what actual packet/task cancellation is not performed?
14. Why are already delivered versions `1` and `2` not automatically rolled back?
15. What would a real retransmission/replay and duplicate-handling recovery protocol need to add?
16. Why does per-sender sequence order not establish causal order across senders or global total order?
17. How does finite reorder capacity motivate P11's backpressure question?
18. What did static/reference checks establish, and what remains unvalidated without MATLAB or hardware?

## Teach-back

In two sentences, answer: “What inputs, observable effects, and failure modes matter when you
preserve Message Ordering?” Put mechanism first: relate send time, scaled path delay, the next
expected sequence, and finite buffering to delivery order and holding. Then explain how raw arrival,
capacity exhaustion, or gap timeout causes state regression or an incomplete prefix without
claiming actual cancellation, rollback, multi-sender order, MATLAB runtime, or physical validation.
