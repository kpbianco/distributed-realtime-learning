%% P01 - See Delay, Jitter, and Clock Skew Distort Timestamps
% Guiding question:
% How do network delay, jitter, clock offset, and clock skew distort one-way timing?
%
% Mental model:
% A timestamp combines event time, clock error, and network delay. Without synchronization, one measured latency can look like another even when the physical message path is unchanged.

%% Read the baseline lesson
disp('How do network delay, jitter, clock offset, and clock skew distort one-way timing?');
disp('A timestamp combines event time, clock error, and network delay. Without synchronization, one measured latency can look like another even when the physical message path is unchanged.');

%% Run the deterministic experiment
experiment;

%% Open the live lever panel
% Move one control at a time and connect the visible change to the model.
interactive;
