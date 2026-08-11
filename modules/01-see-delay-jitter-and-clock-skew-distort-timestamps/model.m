function out = model(baseDelayMs,jitterMs,skewPpm,clockOffsetMs,deadlineMs,periodMs,count,seed)
%MODEL One-way messages observed by unsynchronized clocks.
arguments
    baseDelayMs (1,1) double {mustBeNonnegative} = 2
    jitterMs (1,1) double {mustBeNonnegative} = 0.4
    skewPpm (1,1) double = 20
    clockOffsetMs (1,1) double = 1
    deadlineMs (1,1) double {mustBePositive} = 4
    periodMs (1,1) double {mustBePositive} = 10
    count (1,1) double {mustBeInteger,mustBePositive} = 300
    seed (1,1) double {mustBeInteger,mustBeNonnegative} = 84
end
rng(seed,'twister');
sendTrue=(0:count-1)'*periodMs;
delay=max(0,baseDelayMs+jitterMs*randn(count,1));
arrivalTrue=sendTrue+delay;
senderStamp=sendTrue;
receiverStamp=clockOffsetMs+(1+skewPpm*1e-6).*arrivalTrue;
measured=receiverStamp-senderStamp;
corrected=(receiverStamp-clockOffsetMs)./(1+skewPpm*1e-6)-senderStamp;
out=struct('index',(1:count)','sendTrue',sendTrue,'delay',delay,'arrivalTrue',arrivalTrue, ...
    'senderStamp',senderStamp,'receiverStamp',receiverStamp,'measuredLatency',measured, ...
    'correctedLatency',corrected,'deadline',deadlineMs,'misses',sum(delay>deadlineMs), ...
    'missFraction',mean(delay>deadlineMs),'timestampError',measured-delay, ...
    'skewPpm',skewPpm,'clockOffsetMs',clockOffsetMs);
end
