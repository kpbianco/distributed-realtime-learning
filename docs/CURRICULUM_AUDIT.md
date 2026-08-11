# Curriculum readiness audit

**Track:** Distributed Real-Time Systems and Networks

## Baseline conclusion

The repository has 24 uniquely identified modules in a six-phase, prerequisite-ordered sequence. P01 is the complete reference slice; P02-P24 are explicit non-runnable batch scaffolds. The learner flow is read → visualize → move one lever → visualize the delta → read/explain, followed by a broken case, checks, and teach-back.

Static structure and CLI behavior are verified in CI. MATLAB was not available during the 2026-08-11 baseline audit, so numerical execution, UI behavior, and instructional efficacy remain named validation gaps rather than implied evidence.

## Coverage and compounding order

### Phase 1: Network behavior

- **P01 — See Delay, Jitter, and Clock Skew Distort Timestamps:** How do network delay, jitter, clock offset, and clock skew distort one-way timing?
- **P02 — Serialize and Frame a Message:** What inputs, observable effects, and failure modes matter when you serialize and Frame a Message?
- **P03 — Compare TCP and UDP Behavior:** What inputs, observable effects, and failure modes matter when you compare TCP and UDP Behavior?
- **P04 — Build a Queue and Watch Latency Grow:** What inputs, observable effects, and failure modes matter when you build a Queue and Watch Latency Grow?

### Phase 2: Time and synchronization

- **P05 — Separate Clock Offset from Network Delay:** What inputs, observable effects, and failure modes matter when you separate Clock Offset from Network Delay?
- **P06 — Model NTP-Style Exchange:** What inputs, observable effects, and failure modes matter when you model NTP-Style Exchange?
- **P07 — Model PTP Hardware Timestamping:** What inputs, observable effects, and failure modes matter when you model PTP Hardware Timestamping?
- **P08 — Distribute a Time-Triggered Schedule:** What inputs, observable effects, and failure modes matter when you distribute a Time-Triggered Schedule?

### Phase 3: Coordination and flow

- **P09 — Replicate Shared State:** What inputs, observable effects, and failure modes matter when you replicate Shared State?
- **P10 — Preserve Message Ordering:** What inputs, observable effects, and failure modes matter when you preserve Message Ordering?
- **P11 — Apply Backpressure:** What inputs, observable effects, and failure modes matter when you apply Backpressure?
- **P12 — Build Consensus Intuition:** What inputs, observable effects, and failure modes matter when you build Consensus Intuition?

### Phase 4: Real-time networking

- **P13 — Budget an End-to-End Deadline:** What inputs, observable effects, and failure modes matter when you budget an End-to-End Deadline?
- **P14 — Schedule Periodic Network Traffic:** What inputs, observable effects, and failure modes matter when you schedule Periodic Network Traffic?
- **P15 — Apply Quality of Service:** What inputs, observable effects, and failure modes matter when you apply Quality of Service?
- **P16 — Perform Admission Control:** What inputs, observable effects, and failure modes matter when you perform Admission Control?

### Phase 5: Resilience

- **P17 — Detect a Failed Node:** What inputs, observable effects, and failure modes matter when you detect a Failed Node?
- **P18 — Retry Idempotently:** What inputs, observable effects, and failure modes matter when you retry Idempotently?
- **P19 — Survive a Network Partition:** What inputs, observable effects, and failure modes matter when you survive a Network Partition?
- **P20 — Fail Over to a Redundant Path:** What inputs, observable effects, and failure modes matter when you fail Over to a Redundant Path?

### Phase 6: Observability and assurance

- **P21 — Correlate Distributed Logs:** What inputs, observable effects, and failure modes matter when you correlate Distributed Logs?
- **P22 — Trace One Transaction End to End:** What inputs, observable effects, and failure modes matter when you trace One Transaction End to End?
- **P23 — Replay a Distributed Event Sequence:** What inputs, observable effects, and failure modes matter when you replay a Distributed Event Sequence?
- **P24 — Define Security and Trust Boundaries:** What inputs, observable effects, and failure modes matter when you define Security and Trust Boundaries?

## Batch readiness gates

A scaffold may become `implemented` only when it has a deterministic model, a sectioned experiment, two independent parameter sweeps, one deliberately broken case, interactive controls, interpretation-focused tutor text, numerical checks, focused static tests, and evidence that says exactly what did and did not run.
