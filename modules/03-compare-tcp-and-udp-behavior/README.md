# P03 — Compare TCP and UDP Behavior

**Track:** Distributed Real-Time Systems and Networks  
**Phase 1:** Network behavior  
**Status:** implemented

## Guiding question

What inputs, observable effects, and failure modes matter when you compare TCP and UDP Behavior?

## Compounds on P02

P02 turned four samples into a transparent 15-byte application frame with its own length boundary.
P03 keeps that frame visible while comparing two transport services. TCP is a reliable, ordered
**byte stream** and does not preserve application write boundaries. UDP preserves a delivered
**datagram** boundary but does not guarantee delivery, duplicate suppression, or order.

## Computational mental model

Six P02 frames are sent periodically. The baseline deliberately loses the first transport attempt
for frame 3. Every no-loss teaching unit has the same service delay:

`L = path delay + 8F/R = 20 ms + 8(15 bytes)/(1000 kb/s) = 20.12 ms`.

For send time `S_i = (i - 1)P`:

- UDP delivery is `U_i = S_i + L`, except the lost datagram remains absent.
- The lost TCP byte range arrives at `A_l = S_l + RTO + L` after one successful retransmission.
- TCP application availability is the contiguous-prefix recurrence
  `T_1 = A_1`, `T_i = max(T_(i-1), A_i)`.
- Application age is delivery time minus send time; a record is on time when age is no greater
  than the deadline.
- TCP head-of-line wait is `max(T_i - A_i, 0)` for a later range already at the receiver.

That recurrence deliberately assumes the TCP sender window admits every modeled record range and
the receiver retains later out-of-order bytes until the gap closes. At baseline, three later ranges
are retained, representing 45 P02 application bytes. These are explicit teaching assumptions, not
measurements of an operating-system socket buffer.

At the baseline (`P = 200 ms`, `RTO = 1000 ms`, deadline `800 ms`), TCP eventually exposes all six
records but only four on time. UDP exposes five of six, all five on time. Neither result means one
transport is universally faster: the application is choosing between recovery/order and freshness
under this particular loss and deadline.

## Transparent abstraction boundary

The model uses an established connection, one loss, and one successful timeout-driven TCP
retransmission. It accepts controlled RTO values from 1000 ms upward; these values are teaching
cases, not an RTO estimator. The model intentionally omits handshake, acknowledgements, fast
retransmit, SACK, adaptive RTO/backoff, congestion and flow-control dynamics,
segmentation/coalescing details, header bytes, MTU, reordering, duplication, queue limits, actual
socket-buffer limits, and connection failure. One modeled TCP record-range attempt is bookkeeping
for one P02 record's bytes, not a claim that it maps to one TCP segment. The 0.120 ms term is only
the P02 application-frame serialization; it is not full packet-on-wire time.

The loss index is a deterministic scenario, not a probability. A deadline only classifies whether
delivered data is still useful; it does not cancel TCP bytes. Connection abort and per-record
cancellation are outside this finite synchronous model.

## Deliberately broken assumption

Two 15-byte P02 frames written to TCP may be returned by a byte-stream read as 9 bytes and then 21
bytes. A naive parser that equates one read with one frame recovers neither. A buffered parser keeps
the 9 bytes, appends the next 21, checks P02's sync, declared length, 135-byte policy, and checksum,
then recovers both frames. Partial, over-limit, and corrupt fixtures remain incomplete or reject.
A bad sync also rejects, and a third valid frame stops at the fixture's global two-frame cap. With
adequate receive buffers, the comparison's two UDP reads retain their two 15-byte datagram
boundaries.

## Required learning flow

1. Read the service model and make one prediction about the record after a loss.
2. Visualize the deterministic TCP/UDP baseline timeline and deadline metrics.
3. Sweep application period while holding loss, path, timeout, and deadline fixed.
4. Reset and sweep TCP retransmission timeout while holding every UDP input fixed.
5. Break the one-read-equals-one-frame assumption and repair it with P02 framing.
6. Run independent numerical checks, answer one interpretation question at a time, and teach back
   the mechanism before the consequence.

## Files

- `model.m` — bounded transport timelines, deadline metrics, retained-range bounds, and transparent
  stream parsing.
- `experiment.m` — baseline views, two independent sweeps, and the broken parser case.
- `interactive.m` — period, loss-index, TCP-timeout, and deadline controls with reset.
- `lesson.m`, `lesson.md`, and `walkthrough.md` — notebook and tutor sequence.
- `checks.md` and `run_checks.m` — interpretation prompts and executable invariants.

No toolbox or networking API is required. Static and independent reference-arithmetic checks do
not imply MATLAB-runtime, UI, socket/protocol, numerical-fidelity, bench, HIL, field, deployment,
or production validation.
