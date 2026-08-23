# P09 checks: Replicate Shared State

Run `run_checks` from this module folder, or run `run_module_checks('P09')` from the repository
root after P09 is marked implemented. The executable checks independently cover:

- exact baseline propagation, apply times, four-ack response, version/value visibility, convergence,
  accumulated replica lag, and slow-replica read;
- repeatability, integer-class normalization, fractional delay scale/read delay/timeout, and fixed state;
- propagation scale sweep `[0.5 1 2]` and independent `scale*d_i+c_i` calculations;
- acknowledgment sweep `[1 2 4]` and independent order-statistic response calculations;
- zero propagation, `W=1`, exact apply/read boundary, exact timeout boundary, and just-before limits;
- the deliberately broken primary-only acknowledgment, stale successful read, safe wait, and all-ack recovery;
- online timeout with a successful stale read, later apply without cancellation, unavailable required
  replica/read, timeout with partial apply, reachable `W=3`, restored-replica recovery, and explicit
  absence of rollback or actual waiting;
- stable malformed-input identifiers for empty, text, vector, complex, nonfinite, negative,
  fractional/out-of-range acknowledgment count, invalid availability, and over-bound values;
- recovery-target evaluation after malformed calls, fixed resource counts, presentation/state
  isolation, base-MATLAB compatibility, and explicit acknowledgment-return/ordering/consensus/
  storage/network/cancellation claim boundaries.

## Interpretation questions

Answer one at a time after observing the relevant view.

1. Why can four valid replicas expose two different versions during the propagation window?
2. How do `s*d_i` and `c_i` contribute differently to apply time?
3. Why is the `W`-ack response the `W`-th online apply time in this fixture?
4. Why does reducing `W` change response time without changing Replica D's apply time?
5. At `W=1`, which fact is acknowledged and which universal-visibility claim remains unsupported?
6. Why does observed acknowledgment equal apply time here, and what real return-path behavior is omitted?
7. Why is a stale successful read different from an unavailable read?
8. Why is the exact apply-time boundary current rather than stale?
9. Why can a timeout coexist with three replicas already exposing version `1`?
10. Why would automatically rolling back a partial apply require another distributed transition?
11. Why does restoring D in a fresh model call establish only a recovery target?
12. What retry, deduplication, catch-up, and durable-storage behavior would a real system need?
13. Why is an acknowledgment count here not a consensus or quorum-intersection proof?
14. Which questions are deliberately deferred to P10 message ordering and P12 consensus?
15. What did the static/reference checks establish, and what remains unvalidated without MATLAB or hardware?

## Teach-back

In two sentences, answer: “What inputs, observable effects, and failure modes matter when you
replicate Shared State?” Put mechanism first: relate `t_apply_i=s*d_i+c_i` and the `W`-th apply
time to replica visibility and response latency. Then explain why primary-only acknowledgment can
produce a stale read and why timeout with partial apply implies neither cancellation nor rollback,
while stating that ordering, consensus, storage, network, and hardware behavior remain outside the model.
