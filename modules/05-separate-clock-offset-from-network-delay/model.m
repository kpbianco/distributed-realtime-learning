function out = model(sampleCount,clockOffsetMs,propagationDelayMs,queuePeakDelayMs,hiddenCommonDelayMs,assumedMinimumDelayMs)
%MODEL Deterministic one-way timestamp decomposition for the P05 lesson.
% The observed timestamp difference is clock offset plus true network delay.
% Separation requires an externally justified minimum-network-delay anchor.

if nargin < 1
    sampleCount = 8;
end
if nargin < 2
    clockOffsetMs = 7;
end
if nargin < 3
    propagationDelayMs = 3;
end
if nargin < 4
    queuePeakDelayMs = 8;
end
if nargin < 5
    hiddenCommonDelayMs = 0;
end
if nargin < 6
    assumedMinimumDelayMs = 3;
end

maxSampleCount = 64;
maxTimeMagnitudeMs = 1e6;
sendPeriodMs = 20;

if ~(isnumeric(sampleCount) && isreal(sampleCount) && isscalar(sampleCount) && ...
        isfinite(sampleCount) && sampleCount == fix(sampleCount) && ...
        sampleCount >= 1 && sampleCount <= maxSampleCount)
    error('P05:InvalidSampleCount', ...
        'sampleCount must be an integer from 1 through %d.',maxSampleCount);
end
if ~(isnumeric(clockOffsetMs) && isreal(clockOffsetMs) && ...
        isscalar(clockOffsetMs) && isfinite(clockOffsetMs) && ...
        clockOffsetMs >= -maxTimeMagnitudeMs && ...
        clockOffsetMs <= maxTimeMagnitudeMs)
    error('P05:InvalidClockOffset', ...
        'clockOffsetMs must be a finite scalar from %.0f through %.0f ms.', ...
        -maxTimeMagnitudeMs,maxTimeMagnitudeMs);
end
if ~(isnumeric(propagationDelayMs) && isreal(propagationDelayMs) && ...
        isscalar(propagationDelayMs) && isfinite(propagationDelayMs) && ...
        propagationDelayMs >= 0 && propagationDelayMs <= maxTimeMagnitudeMs)
    error('P05:InvalidPropagationDelay', ...
        'propagationDelayMs must be a finite scalar from 0 through %.0f ms.', ...
        maxTimeMagnitudeMs);
end
if ~(isnumeric(queuePeakDelayMs) && isreal(queuePeakDelayMs) && ...
        isscalar(queuePeakDelayMs) && isfinite(queuePeakDelayMs) && ...
        queuePeakDelayMs >= 0 && queuePeakDelayMs <= maxTimeMagnitudeMs)
    error('P05:InvalidQueuePeakDelay', ...
        'queuePeakDelayMs must be a finite scalar from 0 through %.0f ms.', ...
        maxTimeMagnitudeMs);
end
if ~(isnumeric(hiddenCommonDelayMs) && isreal(hiddenCommonDelayMs) && ...
        isscalar(hiddenCommonDelayMs) && isfinite(hiddenCommonDelayMs) && ...
        hiddenCommonDelayMs >= 0 && hiddenCommonDelayMs <= maxTimeMagnitudeMs)
    error('P05:InvalidHiddenCommonDelay', ...
        'hiddenCommonDelayMs must be a finite scalar from 0 through %.0f ms.', ...
        maxTimeMagnitudeMs);
end
if ~(isnumeric(assumedMinimumDelayMs) && isreal(assumedMinimumDelayMs) && ...
        isscalar(assumedMinimumDelayMs) && isfinite(assumedMinimumDelayMs) && ...
        assumedMinimumDelayMs >= 0 && ...
        assumedMinimumDelayMs <= maxTimeMagnitudeMs)
    error('P05:InvalidAssumedMinimumDelay', ...
        'assumedMinimumDelayMs must be a finite scalar from 0 through %.0f ms.', ...
        maxTimeMagnitudeMs);
end

sampleCount = double(sampleCount);
clockOffsetMs = double(clockOffsetMs);
propagationDelayMs = double(propagationDelayMs);
queuePeakDelayMs = double(queuePeakDelayMs);
hiddenCommonDelayMs = double(hiddenCommonDelayMs);
assumedMinimumDelayMs = double(assumedMinimumDelayMs);

sampleIndex = (1:sampleCount)';
trueSendTimeMs = (sampleIndex - 1) * sendPeriodMs;
senderTimestampMs = trueSendTimeMs;
normalizedQueuePattern = [0;0.25;0.75;0.5;1;0.25;0.5;0];
queuePatternIndex = mod(sampleIndex - 1,numel(normalizedQueuePattern)) + 1;
queueShape = normalizedQueuePattern(queuePatternIndex);
variableQueueDelayMs = queuePeakDelayMs * queueShape;
trueNetworkDelayMs = propagationDelayMs + hiddenCommonDelayMs + ...
    variableQueueDelayMs;
trueArrivalTimeMs = trueSendTimeMs + trueNetworkDelayMs;
receiverTimestampMs = trueArrivalTimeMs + clockOffsetMs;
observedTimestampDifferenceMs = receiverTimestampMs - senderTimestampMs;

minimumObservedDifferenceMs = min(observedTimestampDifferenceMs);
estimatedClockOffsetMs = minimumObservedDifferenceMs - assumedMinimumDelayMs;
estimatedNetworkDelayMs = observedTimestampDifferenceMs - ...
    estimatedClockOffsetMs;
estimatedVariableDelayMs = estimatedNetworkDelayMs - ...
    assumedMinimumDelayMs;
clockOffsetErrorMs = estimatedClockOffsetMs - clockOffsetMs;
networkDelayErrorMs = estimatedNetworkDelayMs - trueNetworkDelayMs;
reconstructedObservationMs = estimatedClockOffsetMs + ...
    estimatedNetworkDelayMs;
reconstructionResidualMs = reconstructedObservationMs - ...
    observedTimestampDifferenceMs;

trueMinimumNetworkDelayMs = min(trueNetworkDelayMs);
anchorErrorMs = trueMinimumNetworkDelayMs - assumedMinimumDelayMs;
timeScaleMs = max([1;abs(clockOffsetMs);abs(observedTimestampDifferenceMs); ...
    trueNetworkDelayMs;assumedMinimumDelayMs]);
comparisonToleranceMs = 64 * eps(timeScaleMs);
minimumDelayAnchorSatisfiedInTruth = ...
    abs(anchorErrorMs) <= comparisonToleranceMs;
if minimumDelayAnchorSatisfiedInTruth
    identifiabilityState = 'anchored-separation';
else
    identifiabilityState = 'ambiguous-common-delay';
end

out = struct();
out.sampleCount = sampleCount;
out.sampleIndex = sampleIndex;
out.sendPeriodMs = sendPeriodMs;
out.clockOffsetMs = clockOffsetMs;
out.propagationDelayMs = propagationDelayMs;
out.queuePeakDelayMs = queuePeakDelayMs;
out.hiddenCommonDelayMs = hiddenCommonDelayMs;
out.assumedMinimumDelayMs = assumedMinimumDelayMs;
out.trueSendTimeMs = trueSendTimeMs;
out.senderTimestampMs = senderTimestampMs;
out.queueShape = queueShape;
out.variableQueueDelayMs = variableQueueDelayMs;
out.trueNetworkDelayMs = trueNetworkDelayMs;
out.trueArrivalTimeMs = trueArrivalTimeMs;
out.receiverTimestampMs = receiverTimestampMs;
out.observedTimestampDifferenceMs = observedTimestampDifferenceMs;
out.minimumObservedDifferenceMs = minimumObservedDifferenceMs;
out.observedDifferenceSpreadMs = max(observedTimestampDifferenceMs) - ...
    minimumObservedDifferenceMs;
out.estimatedClockOffsetMs = estimatedClockOffsetMs;
out.estimatedNetworkDelayMs = estimatedNetworkDelayMs;
out.estimatedVariableDelayMs = estimatedVariableDelayMs;
out.clockOffsetErrorMs = clockOffsetErrorMs;
out.networkDelayErrorMs = networkDelayErrorMs;
out.reconstructedObservationMs = reconstructedObservationMs;
out.reconstructionResidualMs = reconstructionResidualMs;
out.maxAbsReconstructionResidualMs = max(abs(reconstructionResidualMs));
out.trueMinimumNetworkDelayMs = trueMinimumNetworkDelayMs;
out.trueMaximumNetworkDelayMs = max(trueNetworkDelayMs);
out.trueNetworkDelaySpreadMs = max(trueNetworkDelayMs) - ...
    trueMinimumNetworkDelayMs;
out.meanTrueNetworkDelayMs = mean(trueNetworkDelayMs);
out.meanEstimatedNetworkDelayMs = mean(estimatedNetworkDelayMs);
out.anchorErrorMs = anchorErrorMs;
out.minimumDelayAnchorSatisfiedInTruth = ...
    minimumDelayAnchorSatisfiedInTruth;
out.identifiabilityState = identifiabilityState;
out.zeroVariableQueueSamplePresent = min(variableQueueDelayMs) == 0;
out.minimumDelayAnchorAssumed = true;
out.decompositionUniqueFromOneWayOnly = false;
out.constantDelayAliasesWithClockOffset = true;
out.timestampPairingAssumed = true;
out.truthAvailableForTeachingOnly = true;
out.measurementNoiseModeled = false;
out.clockSkewModeled = false;
out.twoWayExchangeModeled = false;
out.timeoutModeled = false;
out.cancellationModeled = false;
out.actualWaitPerformed = false;
out.queueProfileAccessCount = sampleCount;
out.maxQueueProfileAccessCount = maxSampleCount;
out.maxSampleCount = maxSampleCount;
out.maxTimeMagnitudeMs = maxTimeMagnitudeMs;
out.comparisonToleranceMs = comparisonToleranceMs;
end
