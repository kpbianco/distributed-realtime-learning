function out = model(producerIntervalMs,serviceTimeMs, ...
    receiverCapacityMessages,maxBackpressureWaitMs, ...
    useBackpressure,cancelMessageSixWhileWaiting)
%MODEL Deterministic completion-credit backpressure model for P11.
% Twelve ordered demands feed one finite-capacity FIFO consumer. Capacity
% includes the message in service. This is bounded event arithmetic: it
% starts no producer, consumer, timer, callback, transport, or device work.

if nargin < 1
    producerIntervalMs = 10;
end
if nargin < 2
    serviceTimeMs = 20;
end
if nargin < 3
    receiverCapacityMessages = 3;
end
if nargin < 4
    maxBackpressureWaitMs = 200;
end
if nargin < 5
    useBackpressure = true;
end
if nargin < 6
    cancelMessageSixWhileWaiting = false;
end

messageCount = 12;
cancelMessageIndex = 6;
cancelDelayMs = 5;
maxProducerIntervalMs = 1000;
maxServiceTimeMs = 1000;
maxReceiverCapacityMessages = messageCount;
maxBackpressureWaitMsBound = 1e6;
maxObservationEventCount = 3 * messageCount;
% For demand i with n=i-1 predecessors, the worst case performs n+1
% release scans plus one occupancy scan, each comparing those n prior
% completion times. Summing n*(n+2), n=0..messageCount-1, gives 638.
maxAdmissionComparisonCount = (messageCount - 1) * messageCount * ...
    (2 * messageCount + 5) / 6;
maxDerivedTimeMs = 1.012e6;

if ~(isnumeric(producerIntervalMs) && isreal(producerIntervalMs) && ...
        isscalar(producerIntervalMs) && isfinite(producerIntervalMs) && ...
        producerIntervalMs >= 1 && ...
        producerIntervalMs <= maxProducerIntervalMs)
    error('P11:InvalidProducerInterval', ...
        'producerIntervalMs must be a finite scalar from 1 through %.0f ms.', ...
        maxProducerIntervalMs);
end
if ~(isnumeric(serviceTimeMs) && isreal(serviceTimeMs) && ...
        isscalar(serviceTimeMs) && isfinite(serviceTimeMs) && ...
        serviceTimeMs >= 1 && serviceTimeMs <= maxServiceTimeMs)
    error('P11:InvalidServiceTime', ...
        'serviceTimeMs must be a finite scalar from 1 through %.0f ms.', ...
        maxServiceTimeMs);
end
if ~(isnumeric(receiverCapacityMessages) && ...
        isreal(receiverCapacityMessages) && ...
        isscalar(receiverCapacityMessages) && ...
        isfinite(receiverCapacityMessages) && ...
        receiverCapacityMessages >= 0 && ...
        receiverCapacityMessages <= maxReceiverCapacityMessages && ...
        receiverCapacityMessages == fix(receiverCapacityMessages))
    error('P11:InvalidCapacity', ...
        'receiverCapacityMessages must be an integer from 0 through %d.', ...
        maxReceiverCapacityMessages);
end
if ~(isnumeric(maxBackpressureWaitMs) && ...
        isreal(maxBackpressureWaitMs) && ...
        isscalar(maxBackpressureWaitMs) && ...
        isfinite(maxBackpressureWaitMs) && ...
        maxBackpressureWaitMs >= 0 && ...
        maxBackpressureWaitMs <= maxBackpressureWaitMsBound)
    error('P11:InvalidMaxWait', ...
        'maxBackpressureWaitMs must be a finite scalar from 0 through %.0f ms.', ...
        maxBackpressureWaitMsBound);
end
if ~((islogical(useBackpressure) || isnumeric(useBackpressure)) && ...
        isreal(useBackpressure) && isscalar(useBackpressure) && ...
        isfinite(useBackpressure) && ...
        (useBackpressure == 0 || useBackpressure == 1))
    error('P11:InvalidBackpressurePolicy', ...
        'useBackpressure must be a scalar logical or numeric 0 or 1.');
end
if ~((islogical(cancelMessageSixWhileWaiting) || ...
        isnumeric(cancelMessageSixWhileWaiting)) && ...
        isreal(cancelMessageSixWhileWaiting) && ...
        isscalar(cancelMessageSixWhileWaiting) && ...
        isfinite(cancelMessageSixWhileWaiting) && ...
        (cancelMessageSixWhileWaiting == 0 || ...
        cancelMessageSixWhileWaiting == 1))
    error('P11:InvalidCancellationPolicy', ...
        ['cancelMessageSixWhileWaiting must be a scalar logical or ' ...
        'numeric 0 or 1.']);
end

producerIntervalMs = double(producerIntervalMs);
serviceTimeMs = double(serviceTimeMs);
receiverCapacityMessages = double(receiverCapacityMessages);
maxBackpressureWaitMs = double(maxBackpressureWaitMs);
useBackpressure = logical(useBackpressure);
cancelMessageSixWhileWaiting = ...
    logical(cancelMessageSixWhileWaiting);

messageId = 1:messageCount;
demandReadyTimeMs = (messageId - 1) * producerIntervalMs;
admittedMask = false(1,messageCount);
droppedMask = false(1,messageCount);
timedOutMask = false(1,messageCount);
canceledMask = false(1,messageCount);
suppressedMask = false(1,messageCount);
admissionTimeMs = nan(1,messageCount);
serviceStartTimeMs = nan(1,messageCount);
completionTimeMs = nan(1,messageCount);
decisionTimeMs = nan(1,messageCount);
upstreamWaitUntilDecisionMs = nan(1,messageCount);
receiverQueueWaitMs = nan(1,messageCount);
receiverResidenceTimeMs = nan(1,messageCount);
endToEndTimeMs = nan(1,messageCount);
receiverOccupancyAfterAdmission = nan(1,messageCount);
admissionComparisonCount = 0;
lastCompletionTimeMs = 0;
streamStopped = false;
streamStopTimeMs = nan;
streamStopReason = 'none';

for messageIndex = 1:messageCount
    readyTimeMs = demandReadyTimeMs(messageIndex);
    candidateAdmissionTimeMs = readyTimeMs;
    priorMessageRange = 1:(messageIndex - 1);
    priorCompletionTimeMs = completionTimeMs(priorMessageRange);

    if streamStopped
        % P10's ordered-stream contract fails closed after a pending item
        % times out or is canceled. Already admitted work still drains.
        suppressedMask(messageIndex) = true;
        decisionTimeMs(messageIndex) = ...
            max(readyTimeMs,streamStopTimeMs);
    elseif useBackpressure
        if receiverCapacityMessages == 0
            candidateAdmissionTimeMs = inf;
        else
            % A completion at the candidate instant returns its capacity
            % credit before an admission at that same instant.
            for releaseAttempt = 1:messageCount
                unfinishedPriorMask = ...
                    admittedMask(priorMessageRange) & ...
                    priorCompletionTimeMs > candidateAdmissionTimeMs;
                admissionComparisonCount = ...
                    admissionComparisonCount + numel(priorMessageRange);
                if sum(unfinishedPriorMask) < receiverCapacityMessages
                    break;
                end
                candidateAdmissionTimeMs = ...
                    min(priorCompletionTimeMs(unfinishedPriorMask));
            end
        end

        timeoutDecisionTimeMs = ...
            readyTimeMs + maxBackpressureWaitMs;
        cancellationDecisionTimeMs = inf;
        if cancelMessageSixWhileWaiting && ...
                messageIndex == cancelMessageIndex
            cancellationDecisionTimeMs = readyTimeMs + cancelDelayMs;
        end

        % Readiness wins a tie with timeout/cancellation. Thus a message
        % admitted exactly at its maximum wait is accepted.
        if candidateAdmissionTimeMs <= timeoutDecisionTimeMs && ...
                candidateAdmissionTimeMs <= cancellationDecisionTimeMs
            admittedMask(messageIndex) = true;
            admissionTimeMs(messageIndex) = ...
                candidateAdmissionTimeMs;
            decisionTimeMs(messageIndex) = candidateAdmissionTimeMs;
        elseif cancellationDecisionTimeMs <= timeoutDecisionTimeMs
            canceledMask(messageIndex) = true;
            decisionTimeMs(messageIndex) = cancellationDecisionTimeMs;
            streamStopped = true;
            streamStopTimeMs = cancellationDecisionTimeMs;
            streamStopReason = 'pending-cancellation';
        else
            timedOutMask(messageIndex) = true;
            decisionTimeMs(messageIndex) = timeoutDecisionTimeMs;
            streamStopped = true;
            streamStopTimeMs = timeoutDecisionTimeMs;
            streamStopReason = 'upstream-timeout';
        end
    else
        unfinishedPriorMask = admittedMask(priorMessageRange) & ...
            priorCompletionTimeMs > readyTimeMs;
        admissionComparisonCount = admissionComparisonCount + ...
            numel(priorMessageRange);
        if sum(unfinishedPriorMask) >= receiverCapacityMessages
            droppedMask(messageIndex) = true;
            decisionTimeMs(messageIndex) = readyTimeMs;
        else
            admittedMask(messageIndex) = true;
            admissionTimeMs(messageIndex) = readyTimeMs;
            decisionTimeMs(messageIndex) = readyTimeMs;
        end
    end

    upstreamWaitUntilDecisionMs(messageIndex) = ...
        decisionTimeMs(messageIndex) - readyTimeMs;

    if admittedMask(messageIndex)
        unfinishedPriorMask = admittedMask(priorMessageRange) & ...
            priorCompletionTimeMs > admissionTimeMs(messageIndex);
        admissionComparisonCount = admissionComparisonCount + ...
            numel(priorMessageRange);
        receiverOccupancyAfterAdmission(messageIndex) = ...
            sum(unfinishedPriorMask) + 1;
        serviceStartTimeMs(messageIndex) = max( ...
            admissionTimeMs(messageIndex),lastCompletionTimeMs);
        completionTimeMs(messageIndex) = ...
            serviceStartTimeMs(messageIndex) + serviceTimeMs;
        lastCompletionTimeMs = completionTimeMs(messageIndex);
        receiverQueueWaitMs(messageIndex) = ...
            serviceStartTimeMs(messageIndex) - ...
            admissionTimeMs(messageIndex);
        receiverResidenceTimeMs(messageIndex) = ...
            completionTimeMs(messageIndex) - ...
            admissionTimeMs(messageIndex);
        endToEndTimeMs(messageIndex) = ...
            completionTimeMs(messageIndex) - readyTimeMs;
    end
end

failedMask = droppedMask | timedOutMask | canceledMask | suppressedMask;
sourceOrderedAdmittedMessageIds = messageId(admittedMask);
[~,admissionEventOrder] = sort(admissionTimeMs(admittedMask));
admittedMessageIds = ...
    sourceOrderedAdmittedMessageIds(admissionEventOrder);
[~,completionEventOrder] = sort(completionTimeMs(admittedMask));
completedMessageIds = ...
    sourceOrderedAdmittedMessageIds(completionEventOrder);
admittedCount = sum(admittedMask);
droppedCount = sum(droppedMask);
timedOutCount = sum(timedOutMask);
canceledCount = sum(canceledMask);
suppressedCount = sum(suppressedMask);
failedCount = sum(failedMask);
completedCount = admittedCount;
backpressuredMask = useBackpressure & ...
    upstreamWaitUntilDecisionMs > 0;
admittedAfterWaitingMask = admittedMask & backpressuredMask;
totalUpstreamWaitMessageMs = sum(upstreamWaitUntilDecisionMs);
maxUpstreamWaitMs = max(upstreamWaitUntilDecisionMs);
totalReceiverQueueWaitMessageMs = sum(receiverQueueWaitMs(admittedMask));
if admittedCount > 0
    maxReceiverQueueWaitMs = max(receiverQueueWaitMs(admittedMask));
    maxReceiverResidenceTimeMs = ...
        max(receiverResidenceTimeMs(admittedMask));
    maxEndToEndTimeMs = max(endToEndTimeMs(admittedMask));
    completionTimeOfBatchMs = max(completionTimeMs(admittedMask));
else
    maxReceiverQueueWaitMs = 0;
    maxReceiverResidenceTimeMs = 0;
    maxEndToEndTimeMs = nan;
    completionTimeOfBatchMs = nan;
end
receiverHighWaterMessages = max([0 ...
    receiverOccupancyAfterAdmission(admittedMask)]);

validCompletionTimes = completionTimeMs(admittedMask);
observationTimeMs = unique([demandReadyTimeMs decisionTimeMs ...
    validCompletionTimes]);
observationEventCount = numel(observationTimeMs);
offeredCumulative = zeros(1,observationEventCount);
admittedCumulative = zeros(1,observationEventCount);
completedCumulative = zeros(1,observationEventCount);
failedCumulative = zeros(1,observationEventCount);
receiverOccupancyMessages = zeros(1,observationEventCount);
upstreamPendingMessages = zeros(1,observationEventCount);
for eventIndex = 1:observationEventCount
    eventTimeMs = observationTimeMs(eventIndex);
    offeredCumulative(eventIndex) = ...
        sum(demandReadyTimeMs <= eventTimeMs);
    admittedCumulative(eventIndex) = ...
        sum(admittedMask & admissionTimeMs <= eventTimeMs);
    completedCumulative(eventIndex) = ...
        sum(admittedMask & completionTimeMs <= eventTimeMs);
    failedCumulative(eventIndex) = ...
        sum(failedMask & decisionTimeMs <= eventTimeMs);
    receiverOccupancyMessages(eventIndex) = ...
        sum(admittedMask & admissionTimeMs <= eventTimeMs & ...
        completionTimeMs > eventTimeMs);
    if useBackpressure
        upstreamPendingMessages(eventIndex) = ...
            sum(demandReadyTimeMs <= eventTimeMs & ...
            decisionTimeMs > eventTimeMs);
    end
end

peakUpstreamPendingMessages = max(upstreamPendingMessages);
allDemandAccountedFor = ...
    admittedCount + failedCount == messageCount;
receiverCapacityRespected = ...
    all(receiverOccupancyMessages <= receiverCapacityMessages) && ...
    receiverHighWaterMessages <= receiverCapacityMessages;
losslessCompletion = admittedCount == messageCount && failedCount == 0;
admissionOrderPreserved = ...
    isequal(admittedMessageIds,sourceOrderedAdmittedMessageIds);
completionOrderPreserved = ...
    isequal(completedMessageIds,admittedMessageIds);
acceptedPrefixPreserved = isequal( ...
    admittedMessageIds,1:admittedCount);
nominalOfferedRateMessagesPerSecond = 1000 / producerIntervalMs;
serviceRateMessagesPerSecond = 1000 / serviceTimeMs;
offeredLoadRatio = serviceTimeMs / producerIntervalMs;
observationEndTimeMs = observationTimeMs(end);
effectiveCompletionRateMessagesPerSecond = ...
    1000 * completedCount / observationEndTimeMs;

if useBackpressure
    if timedOutCount > 0 && canceledCount > 0
        outcome = 'backpressure-timeout-and-cancellation';
    elseif timedOutCount > 0
        outcome = 'backpressure-timeout';
    elseif canceledCount > 0
        outcome = 'backpressure-cancellation';
    else
        outcome = 'lossless-backpressure';
    end
elseif droppedCount > 0
    outcome = 'readiness-ignored-with-drops';
else
    outcome = 'readiness-ignored-no-drop';
end

out = struct();
out.producerIntervalMs = producerIntervalMs;
out.serviceTimeMs = serviceTimeMs;
out.receiverCapacityMessages = receiverCapacityMessages;
out.maxBackpressureWaitMs = maxBackpressureWaitMs;
out.useBackpressure = useBackpressure;
out.cancelMessageSixWhileWaiting = ...
    cancelMessageSixWhileWaiting;
out.messageCount = messageCount;
out.messageId = messageId;
out.demandReadyTimeMs = demandReadyTimeMs;
out.admittedMask = admittedMask;
out.droppedMask = droppedMask;
out.timedOutMask = timedOutMask;
out.canceledMask = canceledMask;
out.suppressedMask = suppressedMask;
out.failedMask = failedMask;
out.admissionTimeMs = admissionTimeMs;
out.serviceStartTimeMs = serviceStartTimeMs;
out.completionTimeMs = completionTimeMs;
out.decisionTimeMs = decisionTimeMs;
out.upstreamWaitUntilDecisionMs = upstreamWaitUntilDecisionMs;
out.receiverQueueWaitMs = receiverQueueWaitMs;
out.receiverResidenceTimeMs = receiverResidenceTimeMs;
out.endToEndTimeMs = endToEndTimeMs;
out.receiverOccupancyAfterAdmission = ...
    receiverOccupancyAfterAdmission;
out.admittedMessageIds = admittedMessageIds;
out.completedMessageIds = completedMessageIds;
out.admittedCount = admittedCount;
out.completedCount = completedCount;
out.droppedCount = droppedCount;
out.timedOutCount = timedOutCount;
out.canceledCount = canceledCount;
out.suppressedCount = suppressedCount;
out.failedCount = failedCount;
out.backpressuredMask = backpressuredMask;
out.admittedAfterWaitingMask = admittedAfterWaitingMask;
out.backpressuredMessageCount = sum(backpressuredMask);
out.admittedAfterWaitingCount = sum(admittedAfterWaitingMask);
out.totalUpstreamWaitMessageMs = totalUpstreamWaitMessageMs;
out.maxUpstreamWaitMs = maxUpstreamWaitMs;
out.totalReceiverQueueWaitMessageMs = ...
    totalReceiverQueueWaitMessageMs;
out.maxReceiverQueueWaitMs = maxReceiverQueueWaitMs;
out.maxReceiverResidenceTimeMs = maxReceiverResidenceTimeMs;
out.maxEndToEndTimeMs = maxEndToEndTimeMs;
out.completionTimeOfBatchMs = completionTimeOfBatchMs;
out.receiverHighWaterMessages = receiverHighWaterMessages;
out.observationTimeMs = observationTimeMs;
out.offeredCumulative = offeredCumulative;
out.admittedCumulative = admittedCumulative;
out.completedCumulative = completedCumulative;
out.failedCumulative = failedCumulative;
out.receiverOccupancyMessages = receiverOccupancyMessages;
out.upstreamPendingMessages = upstreamPendingMessages;
out.observationEventCount = observationEventCount;
out.peakUpstreamPendingMessages = peakUpstreamPendingMessages;
out.allDemandAccountedFor = allDemandAccountedFor;
out.receiverCapacityRespected = receiverCapacityRespected;
out.losslessCompletion = losslessCompletion;
out.admissionOrderPreserved = admissionOrderPreserved;
out.completionOrderPreserved = completionOrderPreserved;
out.acceptedPrefixPreserved = acceptedPrefixPreserved;
out.nominalOfferedRateMessagesPerSecond = ...
    nominalOfferedRateMessagesPerSecond;
out.serviceRateMessagesPerSecond = serviceRateMessagesPerSecond;
out.offeredLoadRatio = offeredLoadRatio;
out.observationEndTimeMs = observationEndTimeMs;
out.effectiveCompletionRateMessagesPerSecond = ...
    effectiveCompletionRateMessagesPerSecond;
out.outcome = outcome;
out.streamStopped = streamStopped;
out.streamStopTimeMs = streamStopTimeMs;
out.streamStopReason = streamStopReason;
out.namedBrokenAssumption = ...
    'a producer can ignore receiver readiness without loss';
out.capacityIncludesMessageInService = true;
out.completionCreditBeforeCoincidentAdmission = true;
out.pendingDemandRemainsUpstream = useBackpressure;
out.feedbackDelayMs = 0;
out.instantaneousReadinessFeedbackAssumed = true;
out.feedbackOvershootModeled = false;
out.fifoConsumerModeled = true;
out.singleProducerOrderAssumed = true;
out.consumerCreatesCapacity = false;
out.backpressureCreatesServiceCapacity = false;
out.timeoutModeled = useBackpressure;
out.timeoutIsArithmeticClassification = true;
out.actualWallClockWaitPerformed = false;
out.cancellationRequestModeled = ...
    useBackpressure && cancelMessageSixWhileWaiting;
out.cancellationRemovesOnlyPendingDemand = true;
out.cancellationCouldNotUndoAdmission = ...
    useBackpressure && cancelMessageSixWhileWaiting && ...
    admittedMask(cancelMessageIndex);
out.actualAsynchronousCancellationPerformed = false;
out.rollbackModeled = false;
out.actualRollbackPerformed = false;
out.acceptedWorkNotRolledBack = true;
out.laterDemandSuppressedToPreservePrefix = ...
    useBackpressure && suppressedCount > 0;
out.recoveryModeled = false;
out.freshEvaluationRequiredForRecoveryTarget = true;
out.retryModeled = false;
out.retransmissionModeled = false;
out.creditProtocolModeled = false;
out.transportProtocolModeled = false;
out.networkIoPerformed = false;
out.storageIoPerformed = false;
out.backgroundWorkStarted = false;
out.physicalHardwareUsed = false;
out.admissionComparisonCount = admissionComparisonCount;
out.maxAdmissionComparisonCount = maxAdmissionComparisonCount;
out.maxProducerIntervalMs = maxProducerIntervalMs;
out.maxServiceTimeMs = maxServiceTimeMs;
out.maxReceiverCapacityMessages = ...
    maxReceiverCapacityMessages;
out.maxBackpressureWaitMsBound = maxBackpressureWaitMsBound;
out.maxObservationEventCount = maxObservationEventCount;
out.maxDerivedTimeMs = maxDerivedTimeMs;
out.calculationBounded = true;
end
