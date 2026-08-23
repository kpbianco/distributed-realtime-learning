# P03 lesson: Compare TCP and UDP Behavior

## Guiding question

What inputs, observable effects, and failure modes matter when you compare TCP and UDP Behavior?

## Compounds on P02

P02 made application framing explicit. Its 15-byte record still needs that length boundary over
TCP because TCP delivers bytes, not writes or messages. One P02 frame fits in one modeled UDP
datagram, so a delivered datagram keeps that boundary, although UDP does not promise that it will
arrive, arrive once, or arrive in order.

## Mental model

Think about two application questions separately:

1. Will the record eventually become available?
2. Will it become available before its information is stale?

The baseline loses record 3 on its first attempt. UDP leaves that hole and exposes later datagrams
after their fixed 20.12 ms service delay. TCP retransmits the missing byte range after the
controlled 1000 ms timeout. Ordered byte-stream delivery then holds later byte ranges until the
missing prefix arrives: head-of-line blocking.

TCP therefore delivers six of six eventually and four of six before the 800 ms deadline. UDP
delivers five of six eventually and on time. This is one controlled scenario, not a universal
ranking. A different need—complete ordered history rather than fresh partial updates—can prefer the
TCP outcome.

## One prediction before the baseline

Record 3 is lost, but record 4's first attempt reaches the receiver. Which transport lets record 4
reach the application first, and which mechanism explains the difference?

## Baseline observation

Compare three traces in order: TCP network arrival, TCP application availability, and UDP
application delivery. The later TCP ranges are modeled as retained at the receiver, but the
application sees only the contiguous prefix. That outcome assumes a sufficient sender window and
out-of-order receive retention; baseline retains three ranges, or 45 P02 application bytes. The UDP
trace has a missing point for record 3 and continues with record 4.

Then compare eventual count with on-time count. Reliability repairs a gap; it does not guarantee a
deadline. A deadline in this lesson classifies usefulness and does not cancel or remove bytes from
the TCP stream.

## Lever 1: application record period

Reset all controls, then change only the period. A shorter period packs more later records into the
fixed loss-recovery interval, so more TCP byte ranges wait behind the gap. UDP latency and its one
missing datagram stay unchanged because each surviving datagram remains independent in this model.

## Lever 2: TCP retransmission timeout

Reset to a 200 ms period, then change only the controlled RTO. A longer timeout moves the recovered
range and the TCP contiguous-prefix release later. UDP outputs remain invariant because no UDP
retry policy was added. This timeout-only path is deliberately narrower than real TCP's adaptive
timers, acknowledgements, fast retransmit, congestion control, and retry behavior.

## Deliberately broken message-boundary assumption

The sender writes two complete 15-byte P02 frames. A legal TCP read pattern returns 9 bytes and 21
bytes. A parser that assumes one read equals one frame rejects valid stream data. Buffering across
reads and checking P02's sync, length policy, and checksum recovers two frames with zero bytes left
over. A partial header waits; a bad sync, an over-limit declaration, and a corrupt checksum reject.
A third frame stops at the fixture's global two-frame cap. The UDP side shows two 15-byte reads only
because each frame occupies one delivered datagram and the receive buffer is adequate.

## Common mistakes

- TCP reliability does not guarantee that data meets an application deadline.
- TCP ordering applies to bytes; TCP does not preserve application message boundaries.
- UDP datagrams have boundaries, but UDP does not guarantee delivery, order, or duplicate removal.
- A missing UDP point is not zero latency; it is no delivery.
- The selected loss index is a deterministic case, not a measured loss probability.
- The 1000 ms timeout is a controlled timeout path, not a complete RTO estimator.
- Later TCP ranges wait only because the model assumes enough sender window and receiver retention;
  it does not simulate flow control or finite socket buffers.
- A modeled TCP record-range attempt is not a TCP segment count; segmentation and coalescing are
  outside the abstraction.
- The equal service delay isolates transport semantics; it does not include transport, IP, or link
  headers and does not prove that UDP is always faster.
- Deadline evaluation is not cancellation. Abort and per-record cancellation are not modeled.

## Completion standard

Run `run_checks`, answer the interpretation questions in `checks.md`, diagnose the exact broken
boundary assumption, and give a two-sentence teach-back: mechanism first, application consequence
second.
