%% P02 - Serialize and Frame a Message
% Guiding question:
% What inputs, observable effects, and failure modes matter when you serialize and Frame a Message?
%
% P01 separated network delay from clock error. P02 adds the deterministic
% time required to turn one typed message into an agreed frame and clock all
% of its bits onto a link.

%% Read the mental model
disp('Serialization gives fields a byte order; once aligned, framing gives the receiver a boundary and integrity check.');
disp('Wire occupancy is T = 8F/R ms when F is bytes and R is kb/s.');

%% Observe the baseline, two isolated levers, and one broken case
experiment;

%% Move one live lever at a time
% Reset between levers. Explain the mechanism after each changed view.
interactive;
