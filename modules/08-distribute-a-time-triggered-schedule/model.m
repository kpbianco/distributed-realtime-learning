function out = model(clockErrorBoundUs,activationLeadUs, ...
    distributionDelayScale,allOrNothingActivation)
%MODEL Deterministic distributed time-triggered schedule model for P08.
% Each node clock is C_i(t) = t + e_i, where e_i is node-local time
% minus coordinator time. A shared local activation timestamp A therefore
% occurs at true time A-e_i. No clock, packet, scheduler, or hardware is
% accessed; all timing and readiness values are analytical fixtures.

if nargin < 1
    clockErrorBoundUs = 20;
end
if nargin < 2
    activationLeadUs = 1500;
end
if nargin < 3
    distributionDelayScale = 1;
end
if nargin < 4
    allOrNothingActivation = true;
end

maxClockErrorBoundUs = 250;
maxActivationLeadUs = 1e6;
maxDistributionDelayScale = 100;
nodeCount = 4;
actionCount = 4;
scheduleVersionCount = 2;
cyclePeriodUs = 1000;
actionDurationUs = 160;
slotSpacingUs = 250;
nominalGuardUs = slotSpacingUs - actionDurationUs;
maxDerivedTimeUs = 1.2e6;
sharedResourceName = 'exclusive shared channel';

if ~(isnumeric(clockErrorBoundUs) && isreal(clockErrorBoundUs) && ...
        isscalar(clockErrorBoundUs) && isfinite(clockErrorBoundUs) && ...
        clockErrorBoundUs >= 0 && ...
        clockErrorBoundUs <= maxClockErrorBoundUs)
    error('P08:InvalidClockErrorBound', ...
        'clockErrorBoundUs must be a finite scalar from 0 through %.0f us.', ...
        maxClockErrorBoundUs);
end
if ~(isnumeric(activationLeadUs) && isreal(activationLeadUs) && ...
        isscalar(activationLeadUs) && isfinite(activationLeadUs) && ...
        activationLeadUs >= 0 && activationLeadUs <= maxActivationLeadUs)
    error('P08:InvalidActivationLead', ...
        'activationLeadUs must be a finite scalar from 0 through %.0f us.', ...
        maxActivationLeadUs);
end
if ~(isnumeric(distributionDelayScale) && ...
        isreal(distributionDelayScale) && ...
        isscalar(distributionDelayScale) && ...
        isfinite(distributionDelayScale) && ...
        distributionDelayScale >= 0 && ...
        distributionDelayScale <= maxDistributionDelayScale)
    error('P08:InvalidDistributionScale', ...
        ['distributionDelayScale must be a finite scalar from 0 ' ...
         'through %.0f.'],maxDistributionDelayScale);
end
if ~((islogical(allOrNothingActivation) || ...
        isnumeric(allOrNothingActivation)) && ...
        isreal(allOrNothingActivation) && ...
        isscalar(allOrNothingActivation) && ...
        isfinite(allOrNothingActivation) && ...
        (allOrNothingActivation == 0 || allOrNothingActivation == 1))
    error('P08:InvalidActivationPolicy', ...
        'allOrNothingActivation must be a scalar logical or numeric 0 or 1.');
end

clockErrorBoundUs = double(clockErrorBoundUs);
activationLeadUs = double(activationLeadUs);
distributionDelayScale = double(distributionDelayScale);
allOrNothingActivation = logical(allOrNothingActivation);

nodeIndex = 1:nodeCount;
nodeLabels = {'Node A','Node B','Node C','Node D'};

% The residual offsets are a deterministic teaching fixture that reaches
% both signs of the declared bound. Positive offset means a clock is ahead
% and therefore fires its local schedule timestamp early in true time.
clockOffsetShape = [-1 0.5 1 -0.5];
clockOffsetUs = clockErrorBoundUs * clockOffsetShape;
maximumPairwiseClockOffsetUs = max(clockOffsetUs) - min(clockOffsetUs);

% Each action occupies the same exclusive, non-preemptive shared channel.
% Version 1 and version 2 are individually collision-free permutations of
% four 250 us channel slots. Version 2 swaps the Node C and Node D
% assignments. A partial version transition can therefore duplicate the
% 500 us slot and request the shared channel concurrently.
versionOnePhaseUs = [0 250 750 500];
versionTwoPhaseUs = [0 250 500 750];

% Publication is at coordinator true time zero. Each node has a fixed
% distribution delay and validation/staging cost. The local ready time is
% C_i(t_ready) = t_ready + e_i and is compared with shared activation A.
baseDistributionDelayUs = [180 420 760 1120];
scheduleValidationUs = [80 80 120 100];
distributionArrivalTrueTimeUs = ...
    distributionDelayScale * baseDistributionDelayUs;
scheduleReadyTrueTimeUs = ...
    distributionArrivalTrueTimeUs + scheduleValidationUs;
scheduleReadyLocalTimeUs = scheduleReadyTrueTimeUs + clockOffsetUs;
nodeActivationTrueTimeUs = activationLeadUs - clockOffsetUs;
activationSlackUs = activationLeadUs - scheduleReadyLocalTimeUs;

% Readiness is a semantic deadline predicate. Do not widen the deadline by
% an arithmetic tolerance: an accepted input that is even slightly late is
% late in this analytical model.
nodeReadyAtActivation = scheduleReadyLocalTimeUs <= activationLeadUs;
readyNodeCount = sum(nodeReadyAtActivation);
lateNodeCount = nodeCount - readyNodeCount;
allNodesReady = all(nodeReadyAtActivation);
requiredActivationLeadUs = max(scheduleReadyLocalTimeUs);
minimumActivationSlackUs = min(activationSlackUs);
maximumActivationLatenessUs = max(max(-activationSlackUs,0));

% The all-or-nothing policy is a visible coordinator decision over
% teaching truth, not an implemented commit protocol. If any node is late,
% the new selection is withheld and all nodes retain version 1. Disabling
% the policy lets ready nodes switch independently and deliberately exposes
% a mixed-version failure. Coherent versions do not by themselves prove
% adequate clock-error guard.
if allNodesReady
    activeScheduleVersion = 2 * ones(1,nodeCount);
elseif allOrNothingActivation
    activeScheduleVersion = ones(1,nodeCount);
else
    activeScheduleVersion = ones(1,nodeCount);
    activeScheduleVersion(nodeReadyAtActivation) = 2;
end

newVersionSelectedForAllNodes = all(activeScheduleVersion == 2);
oldVersionRetainedForAllNodes = all(activeScheduleVersion == 1);
partialNewVersionSelected = any(activeScheduleVersion == 2) && ...
    any(activeScheduleVersion == 1);
newVersionSelectionWithheld = ~allNodesReady && allOrNothingActivation;

selectedPhaseUs = versionOnePhaseUs;
newVersionMask = activeScheduleVersion == 2;
selectedPhaseUs(newVersionMask) = versionTwoPhaseUs(newVersionMask);
scheduledActionLocalTimeUs = activationLeadUs + selectedPhaseUs;
actionStartTrueTimeUs = scheduledActionLocalTimeUs - clockOffsetUs;
actionEndTrueTimeUs = actionStartTrueTimeUs + actionDurationUs;
actionStartErrorUs = actionStartTrueTimeUs - ...
    (activationLeadUs + selectedPhaseUs);
actionStartRelativeToActivationUs = selectedPhaseUs - clockOffsetUs;

[orderedActionStartRelativeToActivationUs,orderedNodeIndex] = ...
    sort(actionStartRelativeToActivationUs);
orderedActionStartTrueTimeUs = actionStartTrueTimeUs(orderedNodeIndex);
orderedActionEndTrueTimeUs = ...
    orderedActionStartTrueTimeUs + actionDurationUs;
nextOrderedActionStartTrueTimeUs = ...
    [orderedActionStartTrueTimeUs(2:end), ...
    orderedActionStartTrueTimeUs(1) + cyclePeriodUs];
nextOrderedActionStartRelativeToActivationUs = ...
    [orderedActionStartRelativeToActivationUs(2:end), ...
    orderedActionStartRelativeToActivationUs(1) + cyclePeriodUs];
separationToNextActionUs = ...
    nextOrderedActionStartRelativeToActivationUs - ...
    (orderedActionStartRelativeToActivationUs + actionDurationUs);
overlapDurationToNextActionUs = max(-separationToNextActionUs,0);
% Half-open intervals touch when separation is exactly zero. Every negative
% computed separation is an overlap; a tolerance must not hide it.
collisionToNextAction = separationToNextActionUs < 0;
nextOrderedNodeIndex = [orderedNodeIndex(2:end),orderedNodeIndex(1)];
transitionCollisionFromNodeIndex = ...
    orderedNodeIndex(collisionToNextAction);
transitionCollisionToNodeIndex = ...
    nextOrderedNodeIndex(collisionToNextAction);
transitionCollisionCount = sum(collisionToNextAction);
minimumSeparationUs = min(separationToNextActionUs);
totalResourceOvercommitUs = sum(overlapDurationToNextActionUs);
totalNonoverlapIdleUs = sum(max(separationToNextActionUs,0));

% Adjacent negative gaps are sufficient to detect an unsafe schedule and to
% calculate aggregate channel overcommit, but they do not enumerate every
% conflicting pair when three actions overlap at once. Check every unordered
% node pair on the cyclic timeline so collisionCount and the pair inventory
% remain complete at every accepted clock-error bound. Since 2D < T for this
% fixed fixture, an unordered pair can overlap in at most one direction.
maxCollisionPairCount = actionCount * (actionCount - 1) / 2;
collisionFromNodeIndex = zeros(1,maxCollisionPairCount);
collisionToNodeIndex = zeros(1,maxCollisionPairCount);
collisionOverlapDurationUs = zeros(1,maxCollisionPairCount);
collisionCount = 0;
for firstNodeIndex = 1:nodeCount - 1
    for secondNodeIndex = firstNodeIndex + 1:nodeCount
        firstToSecondStartDeltaUs = mod( ...
            actionStartRelativeToActivationUs(secondNodeIndex) - ...
            actionStartRelativeToActivationUs(firstNodeIndex), ...
            cyclePeriodUs);
        secondToFirstStartDeltaUs = mod( ...
            actionStartRelativeToActivationUs(firstNodeIndex) - ...
            actionStartRelativeToActivationUs(secondNodeIndex), ...
            cyclePeriodUs);
        if firstToSecondStartDeltaUs < actionDurationUs
            collisionCount = collisionCount + 1;
            collisionFromNodeIndex(collisionCount) = firstNodeIndex;
            collisionToNodeIndex(collisionCount) = secondNodeIndex;
            collisionOverlapDurationUs(collisionCount) = ...
                actionDurationUs - firstToSecondStartDeltaUs;
        elseif secondToFirstStartDeltaUs < actionDurationUs
            collisionCount = collisionCount + 1;
            collisionFromNodeIndex(collisionCount) = secondNodeIndex;
            collisionToNodeIndex(collisionCount) = firstNodeIndex;
            collisionOverlapDurationUs(collisionCount) = ...
                actionDurationUs - secondToFirstStartDeltaUs;
        end
    end
end
collisionFromNodeIndex = collisionFromNodeIndex(1:collisionCount);
collisionToNodeIndex = collisionToNodeIndex(1:collisionCount);
collisionOverlapDurationUs = ...
    collisionOverlapDurationUs(1:collisionCount);
if collisionCount == 0
    maximumOverlapUs = 0;
    totalPairwiseOverlapUs = 0;
else
    maximumOverlapUs = max(collisionOverlapDurationUs);
    totalPairwiseOverlapUs = sum(collisionOverlapDurationUs);
end
totalOverlapUs = totalPairwiseOverlapUs;

activeVersionCount = numel(unique(activeScheduleVersion));
configurationCoherent = activeVersionCount == 1;
coherentGuaranteedMinSeparationUs = ...
    nominalGuardUs - 2 * clockErrorBoundUs;
coherentTimingBoundApplicable = configurationCoherent;
coherentTimingBoundSatisfiedByActual = configurationCoherent && ...
    minimumSeparationUs >= coherentGuaranteedMinSeparationUs;
coherentTimingGuaranteeNonnegative = ...
    coherentGuaranteedMinSeparationUs >= 0;
unsafeOverlapDetected = collisionCount > 0;

if newVersionSelectedForAllNodes
    scheduleState = 'new-schedule-selected';
elseif newVersionSelectionWithheld
    scheduleState = 'old-schedule-retained';
elseif oldVersionRetainedForAllNodes
    scheduleState = 'old-schedule-selected';
elseif unsafeOverlapDetected
    scheduleState = 'mixed-version-overlap';
else
    scheduleState = 'mixed-version-no-overlap-in-fixture';
end

out = struct();
out.clockErrorBoundUs = clockErrorBoundUs;
out.activationLeadUs = activationLeadUs;
out.distributionDelayScale = distributionDelayScale;
out.allOrNothingActivation = allOrNothingActivation;
out.nodeIndex = nodeIndex;
out.nodeLabels = nodeLabels;
out.clockOffsetShape = clockOffsetShape;
out.clockOffsetUs = clockOffsetUs;
out.maximumPairwiseClockOffsetUs = maximumPairwiseClockOffsetUs;
out.versionOnePhaseUs = versionOnePhaseUs;
out.versionTwoPhaseUs = versionTwoPhaseUs;
out.baseDistributionDelayUs = baseDistributionDelayUs;
out.scheduleValidationUs = scheduleValidationUs;
out.distributionArrivalTrueTimeUs = distributionArrivalTrueTimeUs;
out.scheduleReadyTrueTimeUs = scheduleReadyTrueTimeUs;
out.scheduleReadyLocalTimeUs = scheduleReadyLocalTimeUs;
out.nodeActivationTrueTimeUs = nodeActivationTrueTimeUs;
out.activationSlackUs = activationSlackUs;
out.nodeReadyAtActivation = nodeReadyAtActivation;
out.readyNodeCount = readyNodeCount;
out.lateNodeCount = lateNodeCount;
out.allNodesReady = allNodesReady;
out.requiredActivationLeadUs = requiredActivationLeadUs;
out.minimumActivationSlackUs = minimumActivationSlackUs;
out.maximumActivationLatenessUs = maximumActivationLatenessUs;
out.activeScheduleVersion = activeScheduleVersion;
out.newVersionSelectedForAllNodes = newVersionSelectedForAllNodes;
out.oldVersionRetainedForAllNodes = oldVersionRetainedForAllNodes;
out.partialNewVersionSelected = partialNewVersionSelected;
out.newVersionSelectionWithheld = newVersionSelectionWithheld;
out.selectedPhaseUs = selectedPhaseUs;
out.scheduledActionLocalTimeUs = scheduledActionLocalTimeUs;
out.actionStartTrueTimeUs = actionStartTrueTimeUs;
out.actionEndTrueTimeUs = actionEndTrueTimeUs;
out.actionStartErrorUs = actionStartErrorUs;
out.actionStartRelativeToActivationUs = ...
    actionStartRelativeToActivationUs;
out.orderedActionStartRelativeToActivationUs = ...
    orderedActionStartRelativeToActivationUs;
out.orderedActionStartTrueTimeUs = orderedActionStartTrueTimeUs;
out.orderedActionEndTrueTimeUs = orderedActionEndTrueTimeUs;
out.orderedNodeIndex = orderedNodeIndex;
out.nextOrderedNodeIndex = nextOrderedNodeIndex;
out.nextOrderedActionStartTrueTimeUs = ...
    nextOrderedActionStartTrueTimeUs;
out.nextOrderedActionStartRelativeToActivationUs = ...
    nextOrderedActionStartRelativeToActivationUs;
out.separationToNextActionUs = separationToNextActionUs;
out.overlapDurationToNextActionUs = overlapDurationToNextActionUs;
out.collisionToNextAction = collisionToNextAction;
out.transitionCollisionFromNodeIndex = ...
    transitionCollisionFromNodeIndex;
out.transitionCollisionToNodeIndex = transitionCollisionToNodeIndex;
out.transitionCollisionCount = transitionCollisionCount;
out.collisionFromNodeIndex = collisionFromNodeIndex;
out.collisionToNodeIndex = collisionToNodeIndex;
out.collisionOverlapDurationUs = collisionOverlapDurationUs;
out.collisionCount = collisionCount;
out.minimumSeparationUs = minimumSeparationUs;
out.maximumOverlapUs = maximumOverlapUs;
out.totalPairwiseOverlapUs = totalPairwiseOverlapUs;
out.totalOverlapUs = totalOverlapUs;
out.totalResourceOvercommitUs = totalResourceOvercommitUs;
out.totalNonoverlapIdleUs = totalNonoverlapIdleUs;
out.activeVersionCount = activeVersionCount;
out.configurationCoherent = configurationCoherent;
out.coherentGuaranteedMinSeparationUs = ...
    coherentGuaranteedMinSeparationUs;
out.coherentTimingBoundApplicable = coherentTimingBoundApplicable;
out.coherentTimingBoundSatisfiedByActual = ...
    coherentTimingBoundSatisfiedByActual;
out.coherentTimingGuaranteeNonnegative = ...
    coherentTimingGuaranteeNonnegative;
out.unsafeOverlapDetected = unsafeOverlapDetected;
out.scheduleState = scheduleState;
out.cyclePeriodUs = cyclePeriodUs;
out.actionDurationUs = actionDurationUs;
out.slotSpacingUs = slotSpacingUs;
out.nominalGuardUs = nominalGuardUs;
out.scheduleUtilization = nodeCount * actionDurationUs / cyclePeriodUs;
out.sharedActivationEpochRequired = true;
out.scheduleVersionCoherenceRequired = true;
out.clockErrorConsumesGuardBand = true;
out.truthAvailableForTeachingOnly = true;
out.scheduleDistributionModeled = true;
out.activationWithholdDecisionModeled = true;
out.rollbackDecisionModeled = false;
out.actualRollbackPerformed = false;
out.readinessAcknowledgmentModeled = false;
out.transactionalCommitProtocolModeled = false;
out.configurationMessageEncodingModeled = false;
out.configurationIntegrityModeled = false;
out.clockRateErrorModeled = false;
out.clockServoModeled = false;
out.packetLossModeled = false;
out.networkIoPerformed = false;
out.physicalHardwareUsed = false;
out.fullTsnProtocolModeled = false;
out.fullTteProtocolModeled = false;
out.timeoutModeled = false;
out.cancellationModeled = false;
out.backgroundCancellationModeled = false;
out.actualWaitPerformed = false;
out.sharedResourceName = sharedResourceName;
out.exclusiveSharedResourceRequired = true;
out.nonpreemptiveResourceOccupancyModeled = true;
out.nodeCount = nodeCount;
out.actionCount = actionCount;
out.scheduleVersionCount = scheduleVersionCount;
out.maxCollisionPairCount = maxCollisionPairCount;
out.maxClockErrorBoundUs = maxClockErrorBoundUs;
out.maxActivationLeadUs = maxActivationLeadUs;
out.maxDistributionDelayScale = maxDistributionDelayScale;
out.maxDerivedTimeUs = maxDerivedTimeUs;
out.calculationBounded = true;
end
