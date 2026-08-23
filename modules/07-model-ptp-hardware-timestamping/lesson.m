%% P07 - Model PTP Hardware Timestamping
% Guiding question:
% What inputs, observable effects, and failure modes matter when you model PTP Hardware Timestamping?
%
% P06 showed what four timestamps can infer under a symmetric path. P07
% keeps those equations visible and asks where each timestamp is captured.

%% Read the timestamp-error mechanism
disp('Use theta = follower clock - leader clock and e_i = captured timestamp i - its reference-plane value.');
disp('theta_hat = theta + (d_f-d_r)/2 + (e2-e1+e3-e4)/2.');
disp('Near-wire capture excludes modeled host-path latency, but calibration and tick resolution still matter.');

%% Observe the baseline, two isolated sweeps, and one broken assumption
experiment;

%% Move one live lever at a time
% Reset between levers. Explain which capture-plane error term changed
% before interpreting precision or accuracy.
interactive;
