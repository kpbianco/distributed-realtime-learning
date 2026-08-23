# P11 walkthrough: Apply Backpressure

1. Read the guiding question: What inputs, observable effects, and failure modes matter when you
   apply Backpressure?
2. Recall P10: a finite receiver buffer cannot safely admit arbitrary later work. P11 adds an
   upstream readiness decision while keeping one producer's accepted messages in FIFO order.
3. Make the single prediction in `lesson.md`: if demand arrives twice as fast as service and
   receiver occupancy stays at three or fewer, identify where the accumulating work must appear.
4. Run `experiment.m` and inspect only the first baseline view. Read demand-ready, admission, and
   completion times for each ordered message.
5. Reconstruct message 6: it becomes ready at `50 ms`, the receiver is full, the completion at
   `60 ms` returns one credit, and admission at `60 ms` gives `10 ms` upstream wait.
6. Follow admission `[0 10 20 30 40 60 80 100 120 140 160 180] ms` and completion
   `[20 40 60 80 100 120 140 160 180 200 220 240] ms`.
7. Change to the second baseline view. Observe receiver occupancy never exceed `3 messages` and
   upstream pending demand peak at `4 messages`.
8. Read upstream waits `[0 0 0 0 0 10 20 30 40 50 60 70] ms`, total
   `280 message-ms`, and receiver queue waits `[0 10 20 30 40 40 40 40 40 40 40 40] ms`.
9. Explain that backpressure exposes overload upstream. It does not change the `20 ms` service
   time, add a completion, or erase pending work.
10. Move only producer interval through `[5 10 20 30] ms`. Observe total upstream waits
    `[585 280 0 0] message-ms`, maximum waits `[125 70 0 0] ms`, and completion times
    `[240 240 240 350] ms`.
11. Explain the `20 ms` boundary: a completion and demand coincide, completion returns capacity
    first, and no upstream wait appears. At `30 ms`, consumer idle time makes the finite batch end later.
12. Reset interval to `10 ms`, then move only capacity through `[1 2 3 6] messages`. Observe total
    upstream wait `[660 450 280 10] message-ms` while maximum receiver queue wait becomes
    `[0 20 40 100] ms`.
13. Explain why completion stays `240 ms`: more capacity moves waiting from producer to receiver
    but cannot raise the fixed consumer service rate.
14. Open `interactive.m`. Move one control at a time and use **Reset baseline** before the next comparison.
15. Disable **Apply completion-credit backpressure**. Observe admitted IDs
    `[1 2 3 4 5 7 9 11]`, dropped IDs `[6 8 10 12]`, zero upstream wait, and only eight completions.
16. Name the broken assumption from the symptom: a producer cannot ignore receiver readiness and
    also preserve every message in a finite receiver.
17. Restore backpressure and set maximum wait to `10 ms`. Message 6 is admitted at its exact
    deadline, then message 7 exceeds the bound; later demand is suppressed to retain prefix `[1:6]`.
18. Set the bound just below `10 ms`. Message 6 times out before the `60 ms` credit and the accepted
    prefix is `[1:5]`. Say explicitly that no blocking timer or asynchronous cancellation ran.
19. Enable **Cancel message 6 if waiting** at the baseline. The arithmetic request at `55 ms`
    removes pending message 6, later demand is suppressed, and accepted messages `1:5` drain by `100 ms`.
20. Explain why cancellation cannot undo admitted work and why suppression is a fail-closed
    ordered-stream policy, not rollback.
21. Restore the baseline. This fresh stateless call reaches all 12 completions; it is not retry,
    replay, retransmission, durable restore, or live recovery.
22. State the feedback boundary: completion credits have zero analytical delay, so delayed/stale
    credit overshoot and network flow-control protocols are not modeled.
23. State the resource boundary: 12 demands, capacity `0–12 messages`, producer/service
    `1–1000 ms`, wait `0–1e6 ms`, at most 638 prior-completion comparisons, 36 observation instants,
    and no random, file, timer, transport, background, or hardware operation.
24. Run `run_checks`, answer one interpretation prompt, and teach back demand readiness,
    completion credit, wait location, capacity, loss, and the evidence boundary in two sentences.
