# P10 walkthrough: Preserve Message Ordering

1. Read the guiding question: What inputs, observable effects, and failure modes matter when you
   preserve Message Ordering?
2. Recall P09: one version can be temporarily inconsistent across replicas. P10 now follows six
   successive versions at one receiver and asks which one is applied first.
3. Make the single prediction in `lesson.md`: decide whether raw arrivals make state increase
   monotonically and which version remains after all six are applied.
4. Run `experiment.m` and inspect only the first baseline view. Independently add send time and
   scaled path delay to reconstruct arrival times `[20 15 55 35 65 50] ms`.
5. Read raw arrival order `[2 1 4 6 3 5]` from the timing view. Count four pairwise inversions.
6. Follow strict receiver delivery `[1 2 3 4 5 6]` at `[20 20 55 55 65 65] ms`. Explain that a
   higher sequence waits until every preceding sequence is available.
7. Change to the second baseline view. Read occupancy `[1 0 1 2 1 0] messages` after each arrival,
   high-water `2 messages`, hold `[0 5 0 20 0 15] ms`, and total `40 message-ms`.
8. Move only delay scale through `[0 0.5 1 2]`. Observe arrival inversions `[0 2 4 4]`, high-water
   `[0 1 2 2] messages`, and holding `[0 7.5 40 110] message-ms`.
9. Explain why path delay changes arrival and holding but never changes sequence identity or makes
   the ordering mechanism deliver a successor across a gap.
10. Reset scale to `1`, then move only capacity through `[0 1 2] messages`. Observe delivered counts
    `[0 2 6]` and completion/failure decision times `[15 50 65] ms`.
11. Explain the exact capacity boundary: two successors (`4` and `6`) wait before sequence `3` arrives.
12. Open `interactive.m`. Move one control at a time and use **Reset baseline** before the next comparison.
13. Disable **Use sequence reorder buffer**. Observe state trace `[0 2 1 4 6 3 5]`, two regressions,
    final version `5`, four delivery inversions, and zero ordering hold.
14. Name the broken assumption from the symptom: network arrival order is not sender sequence order.
15. Restore strict ordering and set gap timeout to `20 ms`. Message `3` at exactly `55 ms` is accepted.
    Reduce timeout just below `20 ms`; the receiver stops on ordered prefix `[1 2]`.
16. Make message `3` unavailable. Observe the `55 ms` timeout, buffered successors, suppressed future
    delivery, and retained prefix. Say explicitly that no actual wait, cancellation, or rollback ran.
17. Restore message `3` and reset the baseline. This fresh call reaches a recovery target; it is not
    retransmission, replay, duplicate handling, durable restore, or live protocol recovery.
18. State the resource boundary: six messages, at most six arrival events, buffer `0–6 messages`,
    scale `0–20`, timeout `0–1e6 ms`, fixed storage, and bounded loops.
19. State the semantic boundary: one sender, trusted unique non-wrapping sequence numbers, one
    receiver, no multiple-sender causal/global order, transport guarantee, replication, consensus,
    storage, network I/O, or physical validation.
20. Connect to P11: finite ordering buffers can fill, so a real system needs an explicit upstream
    flow policy rather than silently accepting unbounded work.
21. Run `run_checks`, answer one interpretation prompt, and teach back arrival crossings, sequence
    buffering, added hold, fail-closed behavior, and the evidence boundary in two sentences.
