# P08 walkthrough: Distribute a Time-Triggered Schedule

1. Read the guiding question: What inputs, observable effects, and failure modes matter when you
   distribute a Time-Triggered Schedule?
2. Recall P07: capture, calibration, quantization, and path asymmetry can leave bounded residual
   clock error even when timestamps are much more precise.
3. Make the single prediction in `lesson.md`: doubling the individual error bound doubles the
   possible relative error and removes twice as much guard.
4. Run `experiment.m` and inspect only the first baseline view. Every action occupies the same
   exclusive, non-preemptive shared channel. For `C_i(t)=t+e_i`, follow why positive `e_i` shifts
   true start `A+s_i-e_i` earlier.
5. Inspect the readiness view. Distinguish schedule delivery plus validation from clock
   synchronization: a node is staged only when its local ready time is no later than `A`.
6. State the baseline metrics with units: local ready times `[240 510 900 1210] us`, true starts
   relative to activation `[20 240 480 760] us`, actual gaps `[60 80 120 100] us`, and guaranteed
   minimum `50 us`.
7. Move only residual clock-error bound through `[0 20 40] us`. Observe actual minimum separation
   `[90 60 30] us` and the general bound `[90 50 10] us`.
8. Explain `90-2E`: either member of an adjacent pair can move toward the other by as much as `E`.
9. Reset `E=20 us`. Move only activation lead through `[600 1000 1500] us`. Observe ready-node
   count `[2 3 4]` and minimum slack `[-610 -210 290] us`.
10. Explain why the version-coherent policy retains the old map at the first two leads and selects
    the new map at the last lead. Activation lead changes staging margin, not clock error; the
    policy does not prove adequate guard.
11. Open `interactive.m`. Change one control at a time and use **Reset baseline** before the next
    comparison. Treat readiness, offset, and version state as simulation truth.
12. Set activation lead to `1000 us` and uncheck **All-or-nothing versions**. Observe versions
    `[2 2 2 1]`, duplicated phase `500 us`, and one `-130 us` cyclic separation.
13. Name the violated assumption and symptom: a mixed schedule version duplicates a slot, so Node C
    overlaps Node D for `130 us` even though each full schedule is collision-free at `E=20 us`.
14. Re-enable the policy at `1000 us` to retain version 1, then raise lead to `1500 us` to activate
    version 2. The new selection was withheld, not applied and rolled back; this is not a device
    rollback or commit-protocol test.
15. State the boundary: four nodes, two synthetic maps, and at most six unordered collision pairs;
    no configuration messages,
    acknowledgments, loss, retry, timeout, cancellation, consensus, clock servo, network I/O,
    task execution, or physical validation.
16. Run `run_checks`, answer one prompt from `checks.md` at a time, and teach back in two sentences:
    first the clock/guard and readiness mechanisms, then the mixed-version failure and coherence policy.
