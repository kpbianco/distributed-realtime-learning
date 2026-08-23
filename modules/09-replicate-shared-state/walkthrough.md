# P09 walkthrough: Replicate Shared State

1. Read the guiding question: What inputs, observable effects, and failure modes matter when you
   replicate Shared State?
2. Recall P08: a coherent activation coordinates configuration, but later runtime updates still
   need propagation and local apply time.
3. Make the single prediction in `lesson.md`: after a primary-only acknowledgment at `0 ms`, an
   immediate read from Replica D still returns version `0` because D applies at `75 ms`.
4. Run `experiment.m` and inspect only the first baseline view. Follow each replica's transition
   from version `0` to version `1` on the time axis.
5. Change to the second baseline view. Add scaled propagation delay and apply cost to independently
   reconstruct apply times `[0 15 35 75] ms`.
6. State the baseline metrics with units: `W=4` response `75 ms`, four current replicas, Replica D
   read version `1`/`65%`, and `125 replica-ms` of accumulated lag. State that response equals the
   W-th apply only because acknowledgment return delay/loss is omitted by an explicit teaching oracle.
7. Move only propagation scale through `[0.5 1 2]`. Observe convergence `[40 75 145] ms` and lag
   exposure `[70 125 235] replica-ms`.
8. Explain why scaling propagation changes apply times without changing the written value or the
   requested acknowledgment count.
9. Reset scale to `1`, then move only `W` through `[1 2 4]`. Observe response latency `[0 15 75] ms`,
   current-replica count `[1 2 4]`, and D read version `[0 0 1]`.
10. Explain why asking for fewer acknowledgments changes response evidence but does not make D apply sooner.
11. Open `interactive.m`. Change one control at a time and use **Reset baseline** between comparisons.
12. Set `W=1` and read delay `0`. Identify the broken assumption from the symptom: the write is
    acknowledged at Primary A while D successfully returns stale version `0`.
13. Increase read delay to `75 ms` or restore `W=4`. Observe D return version `1`, and distinguish
    waiting/routing policy from faster replication.
14. Take D offline, set `W=4`, and timeout `100 ms`. Observe a timeout with three applied replicas
    and an unavailable read. Say explicitly that no actual wait, cancellation, or rollback occurred.
15. Restore D and reset the baseline. This fresh deterministic evaluation reaches the recovery
    target; it does not execute a catch-up, retry, deduplication, or restore protocol.
16. State the boundary: four replicas, one writer, one update, fixed synthetic delays, zero-cost
    acknowledgment observation, bounded arithmetic, no concurrent-writer ordering, consensus,
    storage, network I/O, or physical validation.
17. Run `run_checks`, answer one interpretation prompt, and teach back apply time, acknowledgment
    threshold, stale visibility, timeout ambiguity, and the recovery boundary in two sentences.
