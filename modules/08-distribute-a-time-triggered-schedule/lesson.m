%% P08 - Distribute a Time-Triggered Schedule
% Guiding question:
% What inputs, observable effects, and failure modes matter when you distribute a Time-Triggered Schedule?
%
% P07 showed that a synchronized timestamp can retain bounded residual
% error. P08 turns that error into action displacement and adds the separate
% requirement that every node stage the same schedule version.

%% Read the shared-epoch mechanism
disp('Use C_i(t) = t + e_i, where e_i is node-local time minus coordinator time.');
disp('A local schedule timestamp A+s_i fires at true time A+s_i-e_i.');
disp('Each action occupies the same exclusive, non-preemptive shared channel.');
disp('A coherent nominal guard G retains at least G-2E when every absolute clock error is bounded by E.');

%% Observe the baseline, two isolated sweeps, and one broken assumption
experiment;

%% Move one live lever at a time
% Reset between levers. Explain whether clock placement, staging readiness,
% or version coherence changed before interpreting collision symptoms.
interactive;
