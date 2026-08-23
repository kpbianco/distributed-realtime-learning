# P07 walkthrough: Model PTP Hardware Timestamping

1. Read the guiding question and P06 connection in `README.md`. Recall that P06 path asymmetry
   contributes half its signed value to offset error.
2. Make the single prediction in `lesson.md` about doubling host timestamp-path latency while
   holding the modeled hardware capture plane fixed.
3. Run `experiment.m` and inspect only the first baseline plot. Compare the software offset trace
   with the corrected hardware trace and the simulated `120 ns` truth line.
4. Inspect the placement-error plot. Follow the signs: TX stamps precede the reference plane, RX
   stamps follow it, and the four errors combine as `(e2-e1+e3-e4)/2`.
5. State the baseline metrics in nanoseconds. Software is `350 ns` peak-to-peak with `300 ns`
   maximum offset error; corrected `8 ns`-tick hardware is `4 ns` peak-to-peak with `2 ns` maximum
   offset error.
6. Move only host-path scale through `[0 1 2]`. Observe software spread grow through
   `[0 350 700] ns` while hardware spread remains `4 ns`. Explain the capture-plane mechanism
   before the result.
7. Reset host scale to `1`. Move only hardware tick through `[1 8 64] ns`. Observe hardware offset
   spread change through `[0 4 32] ns` while the software trace remains unchanged.
8. Explain the quantization bound: each teaching-fixture stamp is within `q/2`, so the offset
   combination is within `q` and round trip within `2q`.
9. Open `interactive.m`. Change one control at a time and use **Reset baseline** before the next
   comparison. Treat the symmetry and calibration labels as simulation truth.
10. Run the deliberately broken zero-calibration case at a `1 ns` tick. Observe eight identical
    `150 ns` estimates for a true `120 ns` offset and a `1740 ns` round trip for true `1600 ns`.
11. Name the violated assumption and symptom: the timestamps do not share the calibrated wire
    reference plane, so stable pipeline error looks precise while remaining biased.
12. Restore calibration, set the reverse path to `400 ns` while forward stays `800 ns`, and explain
    why hardware offset still changes: capture placement cannot repair P06 path asymmetry.
13. State the boundary: an eight-exchange analytical model, no sockets, packets, kernel, NIC, PHY,
    PHC, timestamp correlation, timeout, cancellation, servo, clock adjustment, or physical test.
14. Run `run_checks`, answer one prompt from `checks.md` at a time, and teach back in two sentences:
    first the timestamp-error equations, then what near-wire capture removes and what it cannot.
