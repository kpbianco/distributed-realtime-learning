function out = model(propagationDelayScale,requiredAckCount, ...
    readAfterResponseMs,slowReplicaAvailable,ackTimeoutMs)
%MODEL Deterministic single-writer replicated-register model for P09.
% A primary applies version 1 at t=0, then three followers apply the same
% version after transparent propagation and apply delays. No packet,
% storage engine, clock, thread, consensus service, or hardware is used.

if nargin < 1
    propagationDelayScale = 1;
end
if nargin < 2
    requiredAckCount = 4;
end
if nargin < 3
    readAfterResponseMs = 0;
end
if nargin < 4
    slowReplicaAvailable = true;
end
if nargin < 5
    ackTimeoutMs = 160;
end

replicaCount = 4;
primaryReplicaIndex = 1;
readTargetReplicaIndex = 4;
initialVersion = 0;
updateVersion = 1;
initialValuePercent = 40;
updatedValuePercent = 65;
basePropagationDelayMs = [0 10 30 70];
applyCostMs = [0 5 5 5];
ackReturnDelayMs = zeros(1,replicaCount);
maxPropagationDelayScale = 20;
maxReadAfterResponseMs = 1e6;
maxAckTimeoutMs = 1e6;
maxDerivedTimeMs = 2.1e6;

if ~(isnumeric(propagationDelayScale) && ...
        isreal(propagationDelayScale) && ...
        isscalar(propagationDelayScale) && ...
        isfinite(propagationDelayScale) && ...
        propagationDelayScale >= 0 && ...
        propagationDelayScale <= maxPropagationDelayScale)
    error('P09:InvalidPropagationDelayScale', ...
        ['propagationDelayScale must be a finite scalar from 0 ' ...
         'through %.0f.'],maxPropagationDelayScale);
end
if ~(isnumeric(requiredAckCount) && isreal(requiredAckCount) && ...
        isscalar(requiredAckCount) && isfinite(requiredAckCount) && ...
        requiredAckCount >= 1 && requiredAckCount <= replicaCount && ...
        requiredAckCount == fix(requiredAckCount))
    error('P09:InvalidRequiredAckCount', ...
        'requiredAckCount must be an integer scalar from 1 through %d.', ...
        replicaCount);
end
if ~(isnumeric(readAfterResponseMs) && isreal(readAfterResponseMs) && ...
        isscalar(readAfterResponseMs) && isfinite(readAfterResponseMs) && ...
        readAfterResponseMs >= 0 && ...
        readAfterResponseMs <= maxReadAfterResponseMs)
    error('P09:InvalidReadDelay', ...
        'readAfterResponseMs must be a finite scalar from 0 through %.0f ms.', ...
        maxReadAfterResponseMs);
end
if ~((islogical(slowReplicaAvailable) || ...
        isnumeric(slowReplicaAvailable)) && ...
        isreal(slowReplicaAvailable) && ...
        isscalar(slowReplicaAvailable) && ...
        isfinite(slowReplicaAvailable) && ...
        (slowReplicaAvailable == 0 || slowReplicaAvailable == 1))
    error('P09:InvalidReplicaAvailability', ...
        'slowReplicaAvailable must be a scalar logical or numeric 0 or 1.');
end
if ~(isnumeric(ackTimeoutMs) && isreal(ackTimeoutMs) && ...
        isscalar(ackTimeoutMs) && isfinite(ackTimeoutMs) && ...
        ackTimeoutMs >= 0 && ackTimeoutMs <= maxAckTimeoutMs)
    error('P09:InvalidAckTimeout', ...
        'ackTimeoutMs must be a finite scalar from 0 through %.0f ms.', ...
        maxAckTimeoutMs);
end

propagationDelayScale = double(propagationDelayScale);
requiredAckCount = double(requiredAckCount);
readAfterResponseMs = double(readAfterResponseMs);
slowReplicaAvailable = logical(slowReplicaAvailable);
ackTimeoutMs = double(ackTimeoutMs);

replicaIndex = 1:replicaCount;
replicaLabels = {'Primary A','Replica B','Replica C','Replica D'};
replicaAvailable = [true true true slowReplicaAvailable];
availableReplicaCount = sum(replicaAvailable);

% The primary's propagation and apply costs are zero. For each online
% follower, version 1 becomes visible at
%   t_apply_i = scale * base_delay_i + apply_cost_i.
nominalApplyTimeMs = ...
    propagationDelayScale * basePropagationDelayMs + applyCostMs;
effectiveApplyTimeMs = nominalApplyTimeMs;
effectiveApplyTimeMs(~replicaAvailable) = inf;

% A real apply acknowledgment needs a return/observation path. This fixture
% makes that path visible and fixes its delay to zero, so it is an
% analytical teaching oracle rather than modeled transport. A W-ack
% response is the W-th order statistic of observed acknowledgment times.
% An unavailable required replica makes that order statistic infinite. A
% finite threshold at exactly the timeout is accepted; no tolerance widens
% either boundary.
ackObservationTimeMs = effectiveApplyTimeMs + ackReturnDelayMs;
orderedAckTimeMs = sort(ackObservationTimeMs);
requiredAckArrivalTimeMs = orderedAckTimeMs(requiredAckCount);
ackThresholdReachable = isfinite(requiredAckArrivalTimeMs);
writeAcknowledged = ackThresholdReachable && ...
    requiredAckArrivalTimeMs <= ackTimeoutMs;
ackTimedOut = ~writeAcknowledged;
if writeAcknowledged
    clientResponseTimeMs = requiredAckArrivalTimeMs;
    acknowledgmentLatencyMs = requiredAckArrivalTimeMs;
    timeoutDecisionLatencyMs = nan;
else
    clientResponseTimeMs = ackTimeoutMs;
    acknowledgmentLatencyMs = nan;
    timeoutDecisionLatencyMs = ackTimeoutMs;
end

replicaCurrentAtResponse = replicaAvailable & ...
    nominalApplyTimeMs <= clientResponseTimeMs;
replicaVersionAtResponse = ...
    initialVersion * ones(1,replicaCount);
replicaVersionAtResponse(replicaCurrentAtResponse) = updateVersion;
replicaValueAtResponsePercent = ...
    initialValuePercent * ones(1,replicaCount);
replicaValueAtResponsePercent(replicaCurrentAtResponse) = ...
    updatedValuePercent;
currentReplicaCountAtResponse = sum(replicaCurrentAtResponse);
allReplicasCurrentAtResponse = all(replicaCurrentAtResponse);
allAvailableReplicasCurrentAtResponse = ...
    all(replicaCurrentAtResponse(replicaAvailable));
partialApplyAtResponse = currentReplicaCountAtResponse > 0 && ...
    currentReplicaCountAtResponse < replicaCount;
writeMayHaveAppliedDespiteTimeout = ...
    ackTimedOut && currentReplicaCountAtResponse > 0;

% The observation always targets Replica D to make routing visible. An
% unavailable target is a failed read, not a stale value. Otherwise the
% observed version follows the same exact apply-time boundary.
readTimeMs = clientResponseTimeMs + readAfterResponseMs;
replicaCurrentAtRead = replicaAvailable & ...
    nominalApplyTimeMs <= readTimeMs;
replicaVersionAtRead = initialVersion * ones(1,replicaCount);
replicaVersionAtRead(replicaCurrentAtRead) = updateVersion;
replicaVersionAtRead(~replicaAvailable) = nan;
currentReplicaCountAtRead = sum(replicaCurrentAtRead);
readSucceeded = replicaAvailable(readTargetReplicaIndex);
if readSucceeded
    readVersion = ...
        replicaVersionAtRead(readTargetReplicaIndex);
    if readVersion == updateVersion
        readValuePercent = updatedValuePercent;
    else
        readValuePercent = initialValuePercent;
    end
    staleReadObserved = readVersion < updateVersion;
    readVersionLag = updateVersion - readVersion;
else
    readVersion = nan;
    readValuePercent = nan;
    staleReadObserved = false;
    readVersionLag = nan;
end
readYourWriteApplicable = writeAcknowledged && readSucceeded;
readYourWriteSatisfied = readYourWriteApplicable && ...
    readVersion == updateVersion;

if all(replicaAvailable)
    convergenceReached = true;
    convergenceTimeMs = max(nominalApplyTimeMs);
    allReplicaLagExposureReplicaMs = sum(nominalApplyTimeMs);
else
    convergenceReached = false;
    convergenceTimeMs = nan;
    allReplicaLagExposureReplicaMs = nan;
end
availableConvergenceTimeMs = ...
    max(nominalApplyTimeMs(replicaAvailable));
onlineReplicaLagExposureReplicaMs = ...
    sum(nominalApplyTimeMs(replicaAvailable));
replicasRequiredButUnavailable = ...
    max(requiredAckCount - availableReplicaCount,0);

if writeAcknowledged && ~readSucceeded
    outcome = 'acknowledged-read-unavailable';
elseif writeAcknowledged && staleReadObserved
    outcome = 'acknowledged-stale-read';
elseif writeAcknowledged
    outcome = 'acknowledged-current-read';
elseif ~readSucceeded
    outcome = 'timeout-read-unavailable';
elseif staleReadObserved
    outcome = 'timeout-stale-read';
else
    outcome = 'timeout-current-read';
end

out = struct();
out.propagationDelayScale = propagationDelayScale;
out.requiredAckCount = requiredAckCount;
out.readAfterResponseMs = readAfterResponseMs;
out.slowReplicaAvailable = slowReplicaAvailable;
out.ackTimeoutMs = ackTimeoutMs;
out.replicaIndex = replicaIndex;
out.replicaLabels = replicaLabels;
out.replicaAvailable = replicaAvailable;
out.availableReplicaCount = availableReplicaCount;
out.basePropagationDelayMs = basePropagationDelayMs;
out.applyCostMs = applyCostMs;
out.ackReturnDelayMs = ackReturnDelayMs;
out.nominalApplyTimeMs = nominalApplyTimeMs;
out.effectiveApplyTimeMs = effectiveApplyTimeMs;
out.ackObservationTimeMs = ackObservationTimeMs;
out.orderedAckTimeMs = orderedAckTimeMs;
out.requiredAckArrivalTimeMs = requiredAckArrivalTimeMs;
out.ackThresholdReachable = ackThresholdReachable;
out.writeAcknowledged = writeAcknowledged;
out.ackTimedOut = ackTimedOut;
out.clientResponseTimeMs = clientResponseTimeMs;
out.acknowledgmentLatencyMs = acknowledgmentLatencyMs;
out.timeoutDecisionLatencyMs = timeoutDecisionLatencyMs;
out.replicaCurrentAtResponse = replicaCurrentAtResponse;
out.replicaVersionAtResponse = replicaVersionAtResponse;
out.replicaValueAtResponsePercent = replicaValueAtResponsePercent;
out.currentReplicaCountAtResponse = currentReplicaCountAtResponse;
out.allReplicasCurrentAtResponse = allReplicasCurrentAtResponse;
out.allAvailableReplicasCurrentAtResponse = ...
    allAvailableReplicasCurrentAtResponse;
out.partialApplyAtResponse = partialApplyAtResponse;
out.writeMayHaveAppliedDespiteTimeout = ...
    writeMayHaveAppliedDespiteTimeout;
out.readTimeMs = readTimeMs;
out.replicaCurrentAtRead = replicaCurrentAtRead;
out.replicaVersionAtRead = replicaVersionAtRead;
out.currentReplicaCountAtRead = currentReplicaCountAtRead;
out.readSucceeded = readSucceeded;
out.readVersion = readVersion;
out.readValuePercent = readValuePercent;
out.staleReadObserved = staleReadObserved;
out.readVersionLag = readVersionLag;
out.readYourWriteApplicable = readYourWriteApplicable;
out.readYourWriteSatisfied = readYourWriteSatisfied;
out.convergenceReached = convergenceReached;
out.convergenceTimeMs = convergenceTimeMs;
out.availableConvergenceTimeMs = availableConvergenceTimeMs;
out.allReplicaLagExposureReplicaMs = ...
    allReplicaLagExposureReplicaMs;
out.onlineReplicaLagExposureReplicaMs = ...
    onlineReplicaLagExposureReplicaMs;
out.replicasRequiredButUnavailable = ...
    replicasRequiredButUnavailable;
out.outcome = outcome;
out.initialVersion = initialVersion;
out.updateVersion = updateVersion;
out.initialValuePercent = initialValuePercent;
out.updatedValuePercent = updatedValuePercent;
out.primaryReplicaIndex = primaryReplicaIndex;
out.readTargetReplicaIndex = readTargetReplicaIndex;
out.replicaCount = replicaCount;
out.updateCount = 1;
out.singleWriterAssumed = true;
out.replicationModeled = true;
out.acknowledgmentThresholdModeled = true;
out.ackReturnDelayAssumedZero = true;
out.ackReturnTransportModeled = false;
out.ackLossModeled = false;
out.acknowledgmentObservationUsesTeachingOracle = true;
out.timeoutModeled = true;
out.timeoutIsArithmeticClassification = true;
out.actualWaitPerformed = false;
out.cancellationModeled = false;
out.actualCancellationPerformed = false;
out.rollbackModeled = false;
out.actualRollbackPerformed = false;
out.partialApplyIsNotRolledBack = true;
out.recoveryRequiresReplicaCatchUp = true;
out.writeOrderingModeled = false;
out.concurrentWritersModeled = false;
out.conflictResolutionModeled = false;
out.consensusModeled = false;
out.quorumConsensusModeled = false;
out.failureDetectorModeled = false;
out.retryProtocolModeled = false;
out.deduplicationModeled = false;
out.messageEncodingModeled = false;
out.networkIoPerformed = false;
out.storageIoPerformed = false;
out.backgroundWorkStarted = false;
out.physicalHardwareUsed = false;
out.namedBrokenAssumption = ...
    'acknowledgment threshold is not universal visibility';
out.maxPropagationDelayScale = maxPropagationDelayScale;
out.maxReadAfterResponseMs = maxReadAfterResponseMs;
out.maxAckTimeoutMs = maxAckTimeoutMs;
out.maxDerivedTimeMs = maxDerivedTimeMs;
out.calculationBounded = true;
end
