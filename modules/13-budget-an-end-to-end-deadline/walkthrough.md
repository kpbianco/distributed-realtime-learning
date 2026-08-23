# P13 walkthrough: Budget an End-to-End Deadline

1. Read the guiding question: What inputs, observable effects, and failure modes matter when you
   budget an End-to-End Deadline?
2. Recall P04 and P11: queueing and backpressure change where waiting appears, not whether waiting
   belongs in the complete path.
3. Recall P12: its baseline third vote is visible at `26 ms`. P13 reuses that value as a declared
   coordination contribution; it does not run consensus again.
4. Read `R_e2e=sum(c_i)`, `S_e2e=D-R_e2e`, and `M_i=b_i-c_i` before opening MATLAB controls.
5. Make the single prediction in `lesson.md`: decide how to classify a local queue-allocation
   breach when the complete path still fits `90 ms`.
6. Run `experiment.m` and inspect only the first baseline view. Name all five ordered stages and
   verify contributions `[8 12 10 26 9] ms`.
7. Compare each contribution with allocations `[10 16 14 32 12] ms`. Reconstruct stage margins
   `[2 4 4 6 3] ms`.
8. Change to the cumulative view. Observe the complete path end at `65 ms`, assigned allocations
   end at `84 ms`, and the deadline remain at `90 ms`.
9. Reconstruct the baseline identity: `25 ms` end-to-end slack equals `6 ms` unassigned reserve
   plus `19 ms` of stage margin.
10. State the evidence boundary: these are synthetic declared inputs, not measured or certified
    task, queue, coordination, network, or end-to-end timing.
11. Move only queue/admission wait through `[0 6 12 24] ms`. Observe complete-path contribution
    `[53 59 65 77] ms` and deadline slack `[37 31 25 13] ms`.
12. Observe queue-stage margin `[16 10 4 -8] ms`. At `24 ms`, report a local allocation breach
    and no end-to-end miss; do not silently rename spare margin as queue ownership.
13. Reset queue wait to `12 ms`, then move only deadline through `[60 65 84 90] ms`.
14. Confirm the complete contribution stays `65 ms`. Explain why changing a requirement changes
    classification and reserve but does not make a stage faster.
15. At `D=65 ms`, observe an exact complete-path tie. At `D=84 ms`, observe an exact allocation-
    total tie. State why these are different boundaries.
16. Open `interactive.m`. Move one control at a time and use **Reset baseline** before comparing
    queue wait, coordination wait, or deadline.
17. Turn off **Include coordination stage** at `D=60 ms`. Observe the accounted path report
    `39 ms`, apparent slack `+21 ms`, and `26 ms` unowned.
18. Compare the still-visible complete path `65 ms` with the same deadline. Name the real modeled
    slack `-5 ms` and the false-confidence symptom.
19. State the broken assumption: a deadline budget is credible even if one causal stage is omitted.
20. Explain why the checkbox changes accounting coverage only; it does not skip coordination work.
21. Restore complete coverage. Set queue wait to exactly `16 ms`, then just above it. The local
    allocation tie passes; the just-larger case breaches locally while the complete path still meets.
22. Compare deadline `65 ms` with a value just below it using `run_checks.m`. Equality passes; the
    model adds no epsilon that silently widens the requirement.
23. Set queue and coordination waits to zero. Identify the remaining `27 ms` from source,
    serialize/network, and destination stages.
24. State the resource boundary: five stages, six cumulative points, queue and coordination waits
    each `0–1000 ms`, deadline `0–1e6 ms`, and maximum complete contribution `2027 ms`.
25. Say explicitly that deadline comparison starts no wall-clock timeout, and no cancellation,
    rollback, retry, periodic scheduler, QoS, admission-control policy, or live recovery runs.
26. Restore the baseline in a fresh call. The same `65 ms` complete path returns; this is stateless
    reevaluation, not rollback or recovery execution.
27. Run `run_checks`, answer one interpretation prompt, and teach back complete ownership,
    contribution, stage margin, allocation reserve, end-to-end slack, and the evidence boundary.
