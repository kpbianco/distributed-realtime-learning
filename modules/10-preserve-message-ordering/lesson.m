%% P10 - Preserve Message Ordering
% Guiding question:
% What inputs, observable effects, and failure modes matter when you preserve Message Ordering?
%
% P09 showed one replicated version becoming visible at different times.
% P10 follows six successive versions whose network arrivals can cross.

%% Read the arrival-time and sequence-buffer mechanism
disp('Message k arrives at t_arrive(k) = t_send(k) + scale*d(k).');
disp('The receiver releases only its next expected per-sender sequence number.');
disp('Later messages wait in a finite buffer until the gap closes or a deadline/capacity fails.');
disp('Per-sender sequence order is not causal order, global total order, or consensus.');

%% Observe the baseline, two isolated sweeps, and one broken assumption
experiment;

%% Move one live lever at a time
% Reset between levers. First name whether arrival order, buffer occupancy,
% delivery latency, or final state changed; then explain the mechanism.
interactive;
