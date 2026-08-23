# P06 walkthrough: Model NTP-Style Exchange

1. Read the guiding question and P05 connection in `README.md`. Recall why one-way data aliases a
   constant delay with clock offset.
2. Make the single prediction in `lesson.md` about adding server residence while holding both path
   directions fixed.
3. Run `experiment.m` and inspect only the baseline simulated event timeline. Follow client send,
   server receive, server transmit, and client receive in true elapsed milliseconds.
4. Inspect the next view. Read the local timestamp vector `[100 111 113 110] ms`, then derive the
   two offset terms `11 ms` and `3 ms`; their average is `7 ms`.
5. Subtract the `2 ms` server residence from the `10 ms` client elapsed interval. Explain why the
   result is the `8 ms` network round trip rather than a one-way delay.
6. Move only true server-minus-client offset through `[-8 0 12] ms`. Observe the estimate move
   while round trip stays fixed.
7. Reset offset to `7 ms`. Move symmetric one-way delay through `[1 4 10] ms`. Observe round trip
   move through `[2 8 20] ms` while the offset estimate stays fixed.
8. Explain the mechanism before the result: equal path delay enters the two signed offset terms
   with opposite signs, while both directions add in round trip.
9. Open `interactive.m`. Change one control at a time and use **Reset baseline** before the next
   comparison. Treat symmetry as simulation truth, not an endpoint measurement; recognize exact
   zero true delay as an ideal truth-only exception that finite represented intervals may obscure.
10. Run the `7/1 ms` broken path and compare it with the `4/4 ms`, `10 ms`-offset alias. Confirm
    both expose `[100 114 116 110] ms` despite different true offset and directional delays.
11. Name the violated assumption and the symptom: unobserved path asymmetry biases offset by half
    the directional difference while every displayed equation can still close exactly.
12. State the boundary: one ideal finite exchange, no network I/O, timeout, cancellation, loss,
    clock steering, filtering, or hardware timestamping, and no MATLAB-runtime or physical claim.
13. Run `run_checks`, answer one prompt from `checks.md` at a time, and teach back in two sentences:
    first the offset/round-trip equations, then what symmetry permits and what asymmetry hides.
