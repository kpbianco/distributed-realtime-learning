function out = model(messageCount,arrivalPeriodMs,serviceTimeMs,capacityMessages,deadlineMs,releaseBatchMessages)
%MODEL Deterministic finite-capacity FIFO queue for the P04 lesson.
% Capacity counts every accepted unfinished message, including one in service.
% Departures at an arrival timestamp free capacity before that arrival is admitted.

if nargin < 1
    messageCount = 12;
end
if nargin < 2
    arrivalPeriodMs = 4;
end
if nargin < 3
    serviceTimeMs = 6;
end
if nargin < 4
    capacityMessages = 4;
end
if nargin < 5
    deadlineMs = 20;
end
if nargin < 6
    releaseBatchMessages = 1;
end

maxMessageCount = 64;
maxCapacityMessages = 64;
maxReleaseBatchMessages = 8;
maxTimeMs = 1e6;

if ~(isnumeric(messageCount) && isreal(messageCount) && isscalar(messageCount) && ...
        isfinite(messageCount) && messageCount == fix(messageCount) && ...
        messageCount >= 1 && messageCount <= maxMessageCount)
    error('P04:InvalidMessageCount', ...
        'messageCount must be an integer from 1 through %d.',maxMessageCount);
end
if ~(isnumeric(arrivalPeriodMs) && isreal(arrivalPeriodMs) && ...
        isscalar(arrivalPeriodMs) && isfinite(arrivalPeriodMs) && ...
        arrivalPeriodMs >= 1 && arrivalPeriodMs <= maxTimeMs)
    error('P04:InvalidArrivalPeriod', ...
        'arrivalPeriodMs must be a finite scalar from 1 through %.0f ms.',maxTimeMs);
end
if ~(isnumeric(serviceTimeMs) && isreal(serviceTimeMs) && ...
        isscalar(serviceTimeMs) && isfinite(serviceTimeMs) && ...
        serviceTimeMs >= 1 && serviceTimeMs <= maxTimeMs)
    error('P04:InvalidServiceTime', ...
        'serviceTimeMs must be a finite scalar from 1 through %.0f ms.',maxTimeMs);
end
if ~(isnumeric(capacityMessages) && isreal(capacityMessages) && ...
        isscalar(capacityMessages) && isfinite(capacityMessages) && ...
        capacityMessages == fix(capacityMessages) && capacityMessages >= 1 && ...
        capacityMessages <= maxCapacityMessages)
    error('P04:InvalidCapacity', ...
        'capacityMessages must be an integer from 1 through %d.',maxCapacityMessages);
end
if ~(isnumeric(deadlineMs) && isreal(deadlineMs) && isscalar(deadlineMs) && ...
        isfinite(deadlineMs) && deadlineMs >= 1 && deadlineMs <= maxTimeMs)
    error('P04:InvalidDeadline', ...
        'deadlineMs must be a finite scalar from 1 through %.0f ms.',maxTimeMs);
end
if ~(isnumeric(releaseBatchMessages) && isreal(releaseBatchMessages) && ...
        isscalar(releaseBatchMessages) && isfinite(releaseBatchMessages) && ...
        releaseBatchMessages == fix(releaseBatchMessages) && ...
        releaseBatchMessages >= 1 && ...
        releaseBatchMessages <= min([double(messageCount),maxReleaseBatchMessages]))
    error('P04:InvalidReleaseBatch', ...
        'releaseBatchMessages must be an integer from 1 through min(messageCount,%d).', ...
        maxReleaseBatchMessages);
end

messageCount = double(messageCount);
arrivalPeriodMs = double(arrivalPeriodMs);
serviceTimeMs = double(serviceTimeMs);
capacityMessages = double(capacityMessages);
deadlineMs = double(deadlineMs);
releaseBatchMessages = double(releaseBatchMessages);

recordIndex = (1:messageCount)';
arrivalTimeMs = (recordIndex - 1) * arrivalPeriodMs;
releaseStartIndex = messageCount;
releaseEndIndex = messageCount;
if releaseBatchMessages > 1
    if releaseBatchMessages < messageCount
        releaseEndIndex = messageCount - 1;
    end
    releaseStartIndex = releaseEndIndex - releaseBatchMessages + 1;
    arrivalTimeMs(releaseStartIndex:releaseEndIndex) = ...
        arrivalTimeMs(releaseEndIndex);
end

timeScaleMs = max([1;(messageCount - 1) * arrivalPeriodMs + ...
    messageCount * serviceTimeMs;deadlineMs]);
comparisonToleranceMs = 64 * eps(timeScaleMs);

acceptedMask = false(messageCount,1);
droppedMask = false(messageCount,1);
serviceStartTimeMs = NaN(messageCount,1);
departureTimeMs = NaN(messageCount,1);
waitingTimeMs = NaN(messageCount,1);
systemLatencyMs = NaN(messageCount,1);
unfinishedBeforeArrivalCount = zeros(messageCount,1);
systemOccupancyAfterArrivalCount = zeros(messageCount,1);
lastAcceptedDepartureMs = 0;
hasAcceptedMessage = false;
admissionComparisonCount = 0;

for arrivalIndex = 1:messageCount
    unfinishedCount = 0;
    for priorIndex = 1:(arrivalIndex - 1)
        admissionComparisonCount = admissionComparisonCount + 1;
        if acceptedMask(priorIndex) && ...
                departureTimeMs(priorIndex) > ...
                arrivalTimeMs(arrivalIndex) + comparisonToleranceMs
            unfinishedCount = unfinishedCount + 1;
        end
    end
    unfinishedBeforeArrivalCount(arrivalIndex) = unfinishedCount;

    if unfinishedCount >= capacityMessages
        droppedMask(arrivalIndex) = true;
        systemOccupancyAfterArrivalCount(arrivalIndex) = unfinishedCount;
        continue
    end

    acceptedMask(arrivalIndex) = true;
    if hasAcceptedMessage && ...
            lastAcceptedDepartureMs > arrivalTimeMs(arrivalIndex) + comparisonToleranceMs
        serviceStartTimeMs(arrivalIndex) = lastAcceptedDepartureMs;
    else
        serviceStartTimeMs(arrivalIndex) = arrivalTimeMs(arrivalIndex);
    end
    departureTimeMs(arrivalIndex) = serviceStartTimeMs(arrivalIndex) + serviceTimeMs;
    waitingTimeMs(arrivalIndex) = ...
        serviceStartTimeMs(arrivalIndex) - arrivalTimeMs(arrivalIndex);
    if waitingTimeMs(arrivalIndex) <= comparisonToleranceMs
        waitingTimeMs(arrivalIndex) = 0;
    end
    systemLatencyMs(arrivalIndex) = ...
        departureTimeMs(arrivalIndex) - arrivalTimeMs(arrivalIndex);
    lastAcceptedDepartureMs = departureTimeMs(arrivalIndex);
    hasAcceptedMessage = true;
    systemOccupancyAfterArrivalCount(arrivalIndex) = unfinishedCount + 1;
end

waitingAfterArrivalCount = max(systemOccupancyAfterArrivalCount - 1,0);
onTimeMask = acceptedMask & ...
    systemLatencyMs <= deadlineMs + comparisonToleranceMs;
lateMask = acceptedMask & ~onTimeMask;
acceptedCount = sum(acceptedMask);
droppedCount = sum(droppedMask);
onTimeCount = sum(onTimeMask);
lateCount = sum(lateMask);
acceptedLatencyMs = systemLatencyMs(acceptedMask);
acceptedWaitingMs = waitingTimeMs(acceptedMask);
maxWaitingTimeMs = max(acceptedWaitingMs);
maxSystemLatencyMs = max(acceptedLatencyMs);
meanWaitingTimeMs = mean(acceptedWaitingMs);
meanSystemLatencyMs = mean(acceptedLatencyMs);
observationStartMs = arrivalTimeMs(1);
observationEndMs = max([arrivalTimeMs(end);departureTimeMs(acceptedMask)]);
observationHorizonMs = observationEndMs - observationStartMs;
busyTimeMs = acceptedCount * serviceTimeMs;
systemTimeAreaMessageMs = sum(acceptedLatencyMs);

nominalUtilization = serviceTimeMs / arrivalPeriodMs;
utilizationTolerance = 64 * eps(max(1,nominalUtilization));
if nominalUtilization < 1 - utilizationTolerance
    nominalLoadState = 'underloaded';
elseif nominalUtilization <= 1 + utilizationTolerance
    nominalLoadState = 'critical';
else
    nominalLoadState = 'overloaded';
end
if droppedCount > 0
    queueState = 'capacity-limited-with-drops';
elseif maxWaitingTimeMs > comparisonToleranceMs && releaseBatchMessages > 1 && ...
        nominalUtilization < 1
    queueState = 'transient-burst-backlog';
elseif maxWaitingTimeMs > comparisonToleranceMs
    queueState = 'growing-backlog';
else
    queueState = 'no-backlog';
end
if releaseBatchMessages > 1
    arrivalPattern = 'p03-release-burst';
else
    arrivalPattern = 'periodic';
end

out = struct();
out.messageCount = messageCount;
out.arrivalPeriodMs = arrivalPeriodMs;
out.serviceTimeMs = serviceTimeMs;
out.capacityMessages = capacityMessages;
out.deadlineMs = deadlineMs;
out.releaseBatchMessages = releaseBatchMessages;
out.releaseStartIndex = releaseStartIndex;
out.releaseEndIndex = releaseEndIndex;
out.recordIndex = recordIndex;
out.arrivalTimeMs = arrivalTimeMs;
out.acceptedMask = acceptedMask;
out.droppedMask = droppedMask;
out.serviceStartTimeMs = serviceStartTimeMs;
out.departureTimeMs = departureTimeMs;
out.waitingTimeMs = waitingTimeMs;
out.systemLatencyMs = systemLatencyMs;
out.unfinishedBeforeArrivalCount = unfinishedBeforeArrivalCount;
out.systemOccupancyAfterArrivalCount = systemOccupancyAfterArrivalCount;
out.waitingAfterArrivalCount = waitingAfterArrivalCount;
out.onTimeMask = onTimeMask;
out.lateMask = lateMask;
out.acceptedCount = acceptedCount;
out.droppedCount = droppedCount;
out.onTimeCount = onTimeCount;
out.lateCount = lateCount;
out.usefulFraction = onTimeCount / messageCount;
out.dropFraction = droppedCount / messageCount;
out.unsuccessfulFraction = (droppedCount + lateCount) / messageCount;
out.maxWaitingTimeMs = maxWaitingTimeMs;
out.maxSystemLatencyMs = maxSystemLatencyMs;
out.meanWaitingTimeMs = meanWaitingTimeMs;
out.meanSystemLatencyMs = meanSystemLatencyMs;
out.nominalOfferedRateMessagesPerSecond = 1000 / arrivalPeriodMs;
out.serviceRateMessagesPerSecond = 1000 / serviceTimeMs;
out.nominalUtilization = nominalUtilization;
out.nominalLoadState = nominalLoadState;
out.queueState = queueState;
out.arrivalPattern = arrivalPattern;
out.peakSystemOccupancyCount = max(systemOccupancyAfterArrivalCount);
out.peakWaitingCount = max(waitingAfterArrivalCount);
out.observationStartMs = observationStartMs;
out.observationEndMs = observationEndMs;
out.observationHorizonMs = observationHorizonMs;
out.busyTimeMs = busyTimeMs;
out.serverBusyFraction = busyTimeMs / observationHorizonMs;
out.systemTimeAreaMessageMs = systemTimeAreaMessageMs;
out.meanSystemOccupancyByArea = systemTimeAreaMessageMs / observationHorizonMs;
out.admissionComparisonCount = admissionComparisonCount;
out.maxAdmissionComparisonCount = maxMessageCount * (maxMessageCount - 1) / 2;
out.maxMessageCount = maxMessageCount;
out.maxCapacityMessages = maxCapacityMessages;
out.maxReleaseBatchMessages = maxReleaseBatchMessages;
out.comparisonToleranceMs = comparisonToleranceMs;
out.capacityIncludesService = true;
out.departureBeforeCoincidentArrival = true;
out.fifoTiesUseRecordIndex = true;
out.dropPolicy = 'tail-drop-on-arrival';
out.deadlineOnlyClassifies = true;
out.cancellationModeled = false;
out.timeoutModeled = false;
out.actualWaitPerformed = false;
end
