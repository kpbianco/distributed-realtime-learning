%% P09 - Replicate Shared State
% Guiding question:
% What inputs, observable effects, and failure modes matter when you replicate Shared State?
%
% P08 made one schedule activation coherent. P09 follows one later state
% update as it reaches a primary and three replicas at different times.

%% Read the apply-time and acknowledgment mechanism
disp('Replica i applies at t_apply_i = scale*d_i + c_i.');
disp('A W-ack response is the W-th online apply time when it arrives by the timeout.');
disp('Acknowledgment-return delay is fixed to zero as a teaching oracle; transport is outside the model.');
disp('A response threshold does not mean every possible read target is already current.');

%% Observe the baseline, two isolated sweeps, and one broken assumption
experiment;

%% Move one live lever at a time
% Reset between levers. First name whether apply timing, response timing,
% read visibility, or availability changed; then explain the mechanism.
interactive;
