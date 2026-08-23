%% P03 - Compare TCP and UDP Behavior
% Guiding question:
% What inputs, observable effects, and failure modes matter when you compare TCP and UDP Behavior?
%
% P02 supplied an explicit frame boundary. P03 sends that frame through two
% different services: a reliable ordered TCP byte stream and independent UDP
% datagrams. Reliability, arrival age, and message boundaries are separate
% properties.

%% Read the mental model
disp('UDP can expose later datagrams around a loss; TCP repairs the missing byte range before exposing later bytes.');
disp('The TCP view assumes enough sender window and receiver retention for later ranges to wait behind the gap.');
disp('A delivery deadline classifies usefulness. It does not cancel an in-flight TCP stream.');

%% Observe the baseline, two isolated levers, and one broken case
experiment;

%% Move one live lever at a time
% Reset between levers. Explain the mechanism after each changed view.
interactive;
