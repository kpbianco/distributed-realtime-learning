function out = model(queueWaitMs,coordinationWaitMs,deadlineMs, ...
    includeCoordinationBudget)
%MODEL Deterministic end-to-end deadline-budget arithmetic for P13.
% One sequential transaction owns five declared timing contributions. The
% calculation compares the complete path with per-stage allocations and an
% end-to-end deadline. It starts no task, queue, protocol, timer, network,
% cancellation, rollback, recovery, or background work.

if nargin < 1
    queueWaitMs = 12;
end
if nargin < 2
    coordinationWaitMs = 26;
end
if nargin < 3
    deadlineMs = 90;
end
if nargin < 4
    includeCoordinationBudget = true;
end

maxQueueWaitMs = 1000;
maxCoordinationWaitMs = 1000;
maxDeadlineMs = 1e6;
stageCount = 5;
maxCumulativePointCount = stageCount + 1;
maxTotalContributionMs = 2027;

if ~(isnumeric(queueWaitMs) && isreal(queueWaitMs) && ...
        isscalar(queueWaitMs) && isfinite(queueWaitMs) && ...
        queueWaitMs >= 0 && queueWaitMs <= maxQueueWaitMs)
    error('P13:InvalidQueueWait', ...
        'queueWaitMs must be a finite scalar from 0 through %.0f ms.', ...
        maxQueueWaitMs);
end
if ~(isnumeric(coordinationWaitMs) && ...
        isreal(coordinationWaitMs) && ...
        isscalar(coordinationWaitMs) && ...
        isfinite(coordinationWaitMs) && ...
        coordinationWaitMs >= 0 && ...
        coordinationWaitMs <= maxCoordinationWaitMs)
    error('P13:InvalidCoordinationWait', ...
        ['coordinationWaitMs must be a finite scalar from 0 through ' ...
        '%.0f ms.'],maxCoordinationWaitMs);
end
if ~(isnumeric(deadlineMs) && isreal(deadlineMs) && ...
        isscalar(deadlineMs) && isfinite(deadlineMs) && ...
        deadlineMs >= 0 && deadlineMs <= maxDeadlineMs)
    error('P13:InvalidDeadline', ...
        'deadlineMs must be a finite scalar from 0 through %.0f ms.', ...
        maxDeadlineMs);
end
if ~((islogical(includeCoordinationBudget) || ...
        isnumeric(includeCoordinationBudget)) && ...
        isreal(includeCoordinationBudget) && ...
        isscalar(includeCoordinationBudget) && ...
        isfinite(includeCoordinationBudget) && ...
        (includeCoordinationBudget == 0 || ...
        includeCoordinationBudget == 1))
    error('P13:InvalidBudgetCoverage', ...
        ['includeCoordinationBudget must be a scalar logical or ' ...
        'numeric 0 or 1.']);
end

queueWaitMs = double(queueWaitMs);
coordinationWaitMs = double(coordinationWaitMs);
deadlineMs = double(deadlineMs);
includeCoordinationBudget = logical(includeCoordinationBudget);

stageId = 1:stageCount;
stageLabel = { ...
    'Source task response', ...
    'Queue/admission wait', ...
    'Serialize + network', ...
    'Coordination evidence wait', ...
    'Destination task response'};
stageContributionMs = [8 queueWaitMs 10 coordinationWaitMs 9];
referenceStageBudgetMs = [10 16 14 32 12];
budgetedStageMask = [true true true ...
    includeCoordinationBudget true];

assignedStageBudgetMs = nan(1,stageCount);
assignedStageBudgetMs(budgetedStageMask) = ...
    referenceStageBudgetMs(budgetedStageMask);
stageBudgetMarginMs = nan(1,stageCount);
stageBudgetMarginMs(budgetedStageMask) = ...
    assignedStageBudgetMs(budgetedStageMask) - ...
    stageContributionMs(budgetedStageMask);

accountedStageContributionMs = zeros(1,stageCount);
accountedStageContributionMs(budgetedStageMask) = ...
    stageContributionMs(budgetedStageMask);
fullPathContributionMs = sum(stageContributionMs);
accountedPathContributionMs = sum(accountedStageContributionMs);
assignedBudgetTotalMs = sum(assignedStageBudgetMs(budgetedStageMask));
unbudgetedContributionMs = fullPathContributionMs - ...
    accountedPathContributionMs;

cumulativeFullPathMs = [0 cumsum(stageContributionMs)];
cumulativeAccountedPathMs = [0 cumsum(accountedStageContributionMs)];
cumulativeAssignedBudgetMs = [0 cumsum( ...
    referenceStageBudgetMs .* double(budgetedStageMask))];

deadlineSlackMs = deadlineMs - fullPathContributionMs;
deadlineMissMs = max(0,-deadlineSlackMs);
apparentAccountedSlackMs = deadlineMs - ...
    accountedPathContributionMs;
allocationReserveMs = deadlineMs - assignedBudgetTotalMs;
stageMarginTotalMs = sum(stageBudgetMarginMs(budgetedStageMask));

budgetCoverageComplete = all(budgetedStageMask);
allOwnedStagesWithinBudget = ...
    all(stageBudgetMarginMs(budgetedStageMask) >= 0);
allStageBudgetsMet = budgetCoverageComplete && ...
    allOwnedStagesWithinBudget;
allocationFitsDeadline = assignedBudgetTotalMs <= deadlineMs;
accountedPathFitsDeadline = accountedPathContributionMs <= deadlineMs;
endToEndBoundMeetsDeadline = fullPathContributionMs <= deadlineMs;
budgetPlanCredible = budgetCoverageComplete && ...
    allStageBudgetsMet && allocationFitsDeadline;
falseConfidenceSymptom = ~budgetCoverageComplete && ...
    accountedPathFitsDeadline && ~endToEndBoundMeetsDeadline;
stageAllocationExceededWhileDeadlineMet = ...
    budgetCoverageComplete && ~allOwnedStagesWithinBudget && ...
    endToEndBoundMeetsDeadline;

fullSlackIdentityResidualMs = deadlineSlackMs - ...
    (allocationReserveMs + stageMarginTotalMs);
accountedSlackIdentityResidualMs = apparentAccountedSlackMs - ...
    (allocationReserveMs + stageMarginTotalMs);

out.stageCount = stageCount;
out.stageId = stageId;
out.stageLabel = stageLabel;
out.queueWaitMs = queueWaitMs;
out.coordinationWaitMs = coordinationWaitMs;
out.deadlineMs = deadlineMs;
out.includeCoordinationBudget = includeCoordinationBudget;
out.stageContributionMs = stageContributionMs;
out.referenceStageBudgetMs = referenceStageBudgetMs;
out.budgetedStageMask = budgetedStageMask;
out.assignedStageBudgetMs = assignedStageBudgetMs;
out.stageBudgetMarginMs = stageBudgetMarginMs;
out.accountedStageContributionMs = accountedStageContributionMs;
out.fullPathContributionMs = fullPathContributionMs;
out.accountedPathContributionMs = accountedPathContributionMs;
out.assignedBudgetTotalMs = assignedBudgetTotalMs;
out.unbudgetedContributionMs = unbudgetedContributionMs;
out.cumulativeFullPathMs = cumulativeFullPathMs;
out.cumulativeAccountedPathMs = cumulativeAccountedPathMs;
out.cumulativeAssignedBudgetMs = cumulativeAssignedBudgetMs;
out.deadlineSlackMs = deadlineSlackMs;
out.deadlineMissMs = deadlineMissMs;
out.apparentAccountedSlackMs = apparentAccountedSlackMs;
out.allocationReserveMs = allocationReserveMs;
out.stageMarginTotalMs = stageMarginTotalMs;
out.budgetCoverageComplete = budgetCoverageComplete;
out.allOwnedStagesWithinBudget = allOwnedStagesWithinBudget;
out.allStageBudgetsMet = allStageBudgetsMet;
out.allocationFitsDeadline = allocationFitsDeadline;
out.accountedPathFitsDeadline = accountedPathFitsDeadline;
out.endToEndBoundMeetsDeadline = endToEndBoundMeetsDeadline;
out.budgetPlanCredible = budgetPlanCredible;
out.falseConfidenceSymptom = falseConfidenceSymptom;
out.stageAllocationExceededWhileDeadlineMet = ...
    stageAllocationExceededWhileDeadlineMet;
out.fullSlackIdentityResidualMs = fullSlackIdentityResidualMs;
out.accountedSlackIdentityResidualMs = ...
    accountedSlackIdentityResidualMs;
out.deadlineTiePasses = true;
out.deadlineOnlyClassifies = true;
out.deadlineMissMeansGuaranteeFailureOnly = true;
out.timeoutModeled = false;
out.actualWallClockWaitPerformed = false;
out.cancellationModeled = false;
out.actualAsynchronousCancellationPerformed = false;
out.rollbackModeled = false;
out.actualRollbackPerformed = false;
out.stageContributionsRetainedAfterClassification = true;
out.recoveryModeled = false;
out.retryModeled = false;
out.freshEvaluationRequiredForRecoveryTarget = true;
out.p12CoordinationEvidenceReusedAsDeclaredInput = true;
out.consensusProtocolModeled = false;
out.queueSimulationModeled = false;
out.periodicSchedulingModeled = false;
out.qualityOfServiceModeled = false;
out.admissionControlPolicyModeled = false;
out.networkIoPerformed = false;
out.storageIoPerformed = false;
out.randomnessUsed = false;
out.backgroundWorkStarted = false;
out.physicalHardwareUsed = false;
out.declaredAnalyticalFixtureOnly = true;
out.measuredTimingEvidence = false;
out.maxQueueWaitMs = maxQueueWaitMs;
out.maxCoordinationWaitMs = maxCoordinationWaitMs;
out.maxDeadlineMs = maxDeadlineMs;
out.maxCumulativePointCount = maxCumulativePointCount;
out.maxTotalContributionMs = maxTotalContributionMs;
out.calculationBounded = true;
out.derivedContributionWithinBound = ...
    fullPathContributionMs <= maxTotalContributionMs;
end
