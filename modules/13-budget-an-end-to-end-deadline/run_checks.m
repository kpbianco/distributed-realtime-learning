function run_checks
%RUN_CHECKS Verify P13 budget arithmetic and evidence boundaries.

%% Deterministic baseline and independent arithmetic
baseline = model(12,26,90,true);
repeated = model(12,26,90,true);
defaults = model();
typed = model(single(12),uint16(26),uint32(90),uint8(1));

assert(isequaln(repeated,baseline));
assert(isequaln(defaults,baseline));
assert(isequaln(typed,baseline));
assert(baseline.stageCount == 5);
assert(isequal(baseline.stageId,1:5));
assert(isequal(baseline.stageLabel,{ ...
    'Source task response', ...
    'Queue/admission wait', ...
    'Serialize + network', ...
    'Coordination evidence wait', ...
    'Destination task response'}));
assert(baseline.queueWaitMs == 12);
assert(baseline.coordinationWaitMs == 26);
assert(baseline.deadlineMs == 90);
assert(baseline.includeCoordinationBudget);

expectedContributionMs = [8 12 10 26 9];
expectedBudgetMs = [10 16 14 32 12];
expectedMarginMs = expectedBudgetMs - expectedContributionMs;
assert(isequal(expectedContributionMs,[8 12 10 26 9]));
assert(isequal(expectedBudgetMs,[10 16 14 32 12]));
assert(isequal(expectedMarginMs,[2 4 4 6 3]));
assert(isequal(baseline.stageContributionMs,expectedContributionMs));
assert(isequal(baseline.referenceStageBudgetMs,expectedBudgetMs));
assert(isequal(baseline.budgetedStageMask,true(1,5)));
assert(isequal(baseline.assignedStageBudgetMs,expectedBudgetMs));
assert(isequal(baseline.stageBudgetMarginMs,expectedMarginMs));
assert(isequal(baseline.accountedStageContributionMs, ...
    expectedContributionMs));
assert(baseline.fullPathContributionMs == sum(expectedContributionMs));
assert(baseline.fullPathContributionMs == 65);
assert(baseline.accountedPathContributionMs == 65);
assert(baseline.assignedBudgetTotalMs == sum(expectedBudgetMs));
assert(baseline.assignedBudgetTotalMs == 84);
assert(baseline.unbudgetedContributionMs == 0);
assert(isequal(baseline.cumulativeFullPathMs,[0 8 20 30 56 65]));
assert(isequal(baseline.cumulativeAccountedPathMs, ...
    [0 8 20 30 56 65]));
assert(isequal(baseline.cumulativeAssignedBudgetMs, ...
    [0 10 26 40 72 84]));
assert(baseline.deadlineSlackMs == 25);
assert(baseline.deadlineMissMs == 0);
assert(baseline.apparentAccountedSlackMs == 25);
assert(baseline.allocationReserveMs == 6);
assert(baseline.stageMarginTotalMs == 19);
assert(baseline.deadlineSlackMs == ...
    baseline.allocationReserveMs + baseline.stageMarginTotalMs);
assert(baseline.fullSlackIdentityResidualMs == 0);
assert(baseline.accountedSlackIdentityResidualMs == 0);
assert(baseline.budgetCoverageComplete);
assert(baseline.allOwnedStagesWithinBudget);
assert(baseline.allStageBudgetsMet);
assert(baseline.allocationFitsDeadline);
assert(baseline.accountedPathFitsDeadline);
assert(baseline.endToEndBoundMeetsDeadline);
assert(baseline.budgetPlanCredible);
assert(~baseline.falseConfidenceSymptom);
assert(~baseline.stageAllocationExceededWhileDeadlineMet);

fractional = model(12.5,26.25,90.5,true);
assert(fractional.queueWaitMs == 12.5);
assert(fractional.coordinationWaitMs == 26.25);
assert(fractional.deadlineMs == 90.5);
assert(isequal(fractional.stageContributionMs, ...
    [8 12.5 10 26.25 9]));
assert(fractional.fullPathContributionMs == 65.75);
assert(fractional.deadlineSlackMs == 24.75);
assert(isequal(fractional.stageBudgetMarginMs, ...
    [2 3.5 4 5.75 3]));
assert(fractional.allocationReserveMs == 6.5);
assert(fractional.fullSlackIdentityResidualMs == 0);

%% Sweep 1: queue/admission wait only
queueWaitValuesMs = [0 6 12 24];
queueSweepFullPathMs = zeros(size(queueWaitValuesMs));
queueSweepDeadlineSlackMs = zeros(size(queueWaitValuesMs));
queueSweepStageMarginMs = zeros(size(queueWaitValuesMs));
queueSweepAllStageBudgetsMet = false(size(queueWaitValuesMs));
queueSweepDeadlineMet = false(size(queueWaitValuesMs));
for caseIndex = 1:numel(queueWaitValuesMs)
    current = model(queueWaitValuesMs(caseIndex),26,90,true);
    assert(current.coordinationWaitMs == 26);
    assert(current.deadlineMs == 90);
    assert(current.includeCoordinationBudget);
    assert(isequal(current.stageContributionMs([1 3 4 5]), ...
        [8 10 26 9]));
    queueSweepFullPathMs(caseIndex) = current.fullPathContributionMs;
    queueSweepDeadlineSlackMs(caseIndex) = current.deadlineSlackMs;
    queueSweepStageMarginMs(caseIndex) = ...
        current.stageBudgetMarginMs(2);
    queueSweepAllStageBudgetsMet(caseIndex) = ...
        current.allStageBudgetsMet;
    queueSweepDeadlineMet(caseIndex) = ...
        current.endToEndBoundMeetsDeadline;
end
assert(isequal(queueSweepFullPathMs,[53 59 65 77]));
assert(isequal(queueSweepDeadlineSlackMs,[37 31 25 13]));
assert(isequal(queueSweepStageMarginMs,[16 10 4 -8]));
assert(isequal(queueSweepAllStageBudgetsMet, ...
    [true true true false]));
assert(isequal(queueSweepDeadlineMet,true(1,4)));

%% Sweep 2: end-to-end deadline only
deadlineValuesMs = [60 65 84 90];
deadlineSweepFullPathMs = zeros(size(deadlineValuesMs));
deadlineSweepSlackMs = zeros(size(deadlineValuesMs));
deadlineSweepAllocationReserveMs = zeros(size(deadlineValuesMs));
deadlineSweepPathMet = false(size(deadlineValuesMs));
deadlineSweepAllocationFits = false(size(deadlineValuesMs));
for caseIndex = 1:numel(deadlineValuesMs)
    current = model(12,26,deadlineValuesMs(caseIndex),true);
    assert(current.queueWaitMs == 12);
    assert(current.coordinationWaitMs == 26);
    assert(current.includeCoordinationBudget);
    assert(isequal(current.stageContributionMs, ...
        baseline.stageContributionMs));
    deadlineSweepFullPathMs(caseIndex) = ...
        current.fullPathContributionMs;
    deadlineSweepSlackMs(caseIndex) = current.deadlineSlackMs;
    deadlineSweepAllocationReserveMs(caseIndex) = ...
        current.allocationReserveMs;
    deadlineSweepPathMet(caseIndex) = ...
        current.endToEndBoundMeetsDeadline;
    deadlineSweepAllocationFits(caseIndex) = ...
        current.allocationFitsDeadline;
end
assert(isequal(deadlineSweepFullPathMs,[65 65 65 65]));
assert(isequal(deadlineSweepSlackMs,[-5 0 19 25]));
assert(isequal(deadlineSweepAllocationReserveMs,[-24 -19 0 6]));
assert(isequal(deadlineSweepPathMet,[false true true true]));
assert(isequal(deadlineSweepAllocationFits, ...
    [false false true true]));

%% Deliberately broken incomplete budget coverage
broken = model(12,26,60,false);
completeTight = model(12,26,60,true);
assert(~broken.includeCoordinationBudget);
assert(isequal(broken.budgetedStageMask, ...
    [true true true false true]));
assert(isequaln(broken.assignedStageBudgetMs, ...
    [10 16 14 nan 12]));
assert(isequaln(broken.stageBudgetMarginMs,[2 4 4 nan 3]));
assert(isequal(broken.accountedStageContributionMs, ...
    [8 12 10 0 9]));
assert(broken.fullPathContributionMs == 65);
assert(broken.accountedPathContributionMs == 39);
assert(broken.assignedBudgetTotalMs == 52);
assert(broken.unbudgetedContributionMs == 26);
assert(isequal(broken.cumulativeFullPathMs,[0 8 20 30 56 65]));
assert(isequal(broken.cumulativeAccountedPathMs, ...
    [0 8 20 30 30 39]));
assert(isequal(broken.cumulativeAssignedBudgetMs, ...
    [0 10 26 40 40 52]));
assert(broken.deadlineSlackMs == -5);
assert(broken.deadlineMissMs == 5);
assert(broken.apparentAccountedSlackMs == 21);
assert(broken.allocationReserveMs == 8);
assert(broken.stageMarginTotalMs == 13);
assert(~broken.budgetCoverageComplete);
assert(broken.allOwnedStagesWithinBudget);
assert(~broken.allStageBudgetsMet);
assert(broken.allocationFitsDeadline);
assert(broken.accountedPathFitsDeadline);
assert(~broken.endToEndBoundMeetsDeadline);
assert(~broken.budgetPlanCredible);
assert(broken.falseConfidenceSymptom);
assert(~broken.stageAllocationExceededWhileDeadlineMet);
assert(broken.fullSlackIdentityResidualMs == -26);
assert(broken.accountedSlackIdentityResidualMs == 0);

assert(completeTight.includeCoordinationBudget);
assert(completeTight.budgetCoverageComplete);
assert(completeTight.allStageBudgetsMet);
assert(~completeTight.allocationFitsDeadline);
assert(~completeTight.endToEndBoundMeetsDeadline);
assert(~completeTight.budgetPlanCredible);
assert(~completeTight.falseConfidenceSymptom);
assert(completeTight.deadlineSlackMs == -5);
assert(completeTight.apparentAccountedSlackMs == -5);
assert(completeTight.unbudgetedContributionMs == 0);

%% Zero-contribution omission still violates stage ownership
% A zero contribution can hide an ownership gap from every total and slack
% identity. Coverage must therefore come from the explicit stage mask, not
% from whether the currently unbudgeted contribution happens to be nonzero.
zeroContributionUnowned = model(12,0,90,false);
zeroContributionOwned = model(12,0,90,true);
assert(~zeroContributionUnowned.includeCoordinationBudget);
assert(isequal(zeroContributionUnowned.budgetedStageMask, ...
    [true true true false true]));
assert(zeroContributionUnowned.fullPathContributionMs == 39);
assert(zeroContributionUnowned.accountedPathContributionMs == 39);
assert(zeroContributionUnowned.unbudgetedContributionMs == 0);
assert(zeroContributionUnowned.deadlineSlackMs == 51);
assert(zeroContributionUnowned.apparentAccountedSlackMs == 51);
assert(zeroContributionUnowned.fullSlackIdentityResidualMs == 0);
assert(zeroContributionUnowned.accountedSlackIdentityResidualMs == 0);
assert(~zeroContributionUnowned.budgetCoverageComplete);
assert(zeroContributionUnowned.allOwnedStagesWithinBudget);
assert(~zeroContributionUnowned.allStageBudgetsMet);
assert(zeroContributionUnowned.allocationFitsDeadline);
assert(zeroContributionUnowned.accountedPathFitsDeadline);
assert(zeroContributionUnowned.endToEndBoundMeetsDeadline);
assert(~zeroContributionUnowned.budgetPlanCredible);
assert(~zeroContributionUnowned.falseConfidenceSymptom);

assert(zeroContributionOwned.budgetCoverageComplete);
assert(zeroContributionOwned.budgetPlanCredible);
assert(zeroContributionOwned.fullPathContributionMs == ...
    zeroContributionUnowned.fullPathContributionMs);
assert(zeroContributionOwned.deadlineSlackMs == ...
    zeroContributionUnowned.deadlineSlackMs);

%% Limiting cases and exact boundary policy
zeroWaits = model(0,0,27,true);
assert(isequal(zeroWaits.stageContributionMs,[8 0 10 0 9]));
assert(zeroWaits.fullPathContributionMs == 27);
assert(zeroWaits.deadlineSlackMs == 0);
assert(zeroWaits.endToEndBoundMeetsDeadline);
assert(~zeroWaits.allocationFitsDeadline);
assert(zeroWaits.deadlineTiePasses);

exactDeadline = model(12,26,65,true);
assert(exactDeadline.fullPathContributionMs == 65);
assert(exactDeadline.deadlineSlackMs == 0);
assert(exactDeadline.endToEndBoundMeetsDeadline);
justBeforeDeadline = model(12,26,65 - 1e-12,true);
assert(justBeforeDeadline.deadlineSlackMs < 0);
assert(justBeforeDeadline.deadlineMissMs > 0);
assert(~justBeforeDeadline.endToEndBoundMeetsDeadline);

exactQueueAllocation = model(16,26,90,true);
assert(exactQueueAllocation.stageBudgetMarginMs(2) == 0);
assert(exactQueueAllocation.allStageBudgetsMet);
assert(exactQueueAllocation.endToEndBoundMeetsDeadline);
assert(exactQueueAllocation.budgetPlanCredible);
justOverQueueAllocation = model(16 + 1e-12,26,90,true);
assert(justOverQueueAllocation.stageBudgetMarginMs(2) < 0);
assert(~justOverQueueAllocation.allStageBudgetsMet);
assert(justOverQueueAllocation.endToEndBoundMeetsDeadline);
assert(~justOverQueueAllocation.budgetPlanCredible);
assert(justOverQueueAllocation.stageAllocationExceededWhileDeadlineMet);

exactCoordinationAllocation = model(12,32,90,true);
assert(exactCoordinationAllocation.stageBudgetMarginMs(4) == 0);
assert(exactCoordinationAllocation.allStageBudgetsMet);
justOverCoordinationAllocation = model(12,32 + 1e-12,90,true);
assert(justOverCoordinationAllocation.stageBudgetMarginMs(4) < 0);
assert(~justOverCoordinationAllocation.allStageBudgetsMet);

zeroDeadline = model(12,26,0,true);
assert(~zeroDeadline.endToEndBoundMeetsDeadline);
assert(zeroDeadline.deadlineMissMs == 65);
assert(zeroDeadline.stageContributionsRetainedAfterClassification);

%% Timeout, cancellation, rollback, recovery, and isolation boundaries
assert(baseline.deadlineOnlyClassifies);
assert(baseline.deadlineMissMeansGuaranteeFailureOnly);
assert(~baseline.timeoutModeled);
assert(~baseline.actualWallClockWaitPerformed);
assert(~baseline.cancellationModeled);
assert(~baseline.actualAsynchronousCancellationPerformed);
assert(~baseline.rollbackModeled);
assert(~baseline.actualRollbackPerformed);
assert(baseline.stageContributionsRetainedAfterClassification);
assert(~baseline.recoveryModeled);
assert(~baseline.retryModeled);
assert(baseline.freshEvaluationRequiredForRecoveryTarget);

recoveryAfterMiss = model(12,26,90,true);
recoveryAfterBrokenCoverage = model(12,26,90,true);
recoveryAfterAllocationBreach = model(12,26,90,true);
assert(isequaln(recoveryAfterMiss,baseline));
assert(isequaln(recoveryAfterBrokenCoverage,baseline));
assert(isequaln(recoveryAfterAllocationBreach,baseline));
assert(baseline.p12CoordinationEvidenceReusedAsDeclaredInput);
assert(~baseline.consensusProtocolModeled);
assert(~baseline.queueSimulationModeled);
assert(~baseline.periodicSchedulingModeled);
assert(~baseline.qualityOfServiceModeled);
assert(~baseline.admissionControlPolicyModeled);
assert(~baseline.networkIoPerformed);
assert(~baseline.storageIoPerformed);
assert(~baseline.randomnessUsed);
assert(~baseline.backgroundWorkStarted);
assert(~baseline.physicalHardwareUsed);
assert(baseline.declaredAnalyticalFixtureOnly);
assert(~baseline.measuredTimingEvidence);

%% Maximum resource bounds
bounded = model(1000,1000,1e6,true);
assert(isequal(bounded.stageContributionMs,[8 1000 10 1000 9]));
assert(bounded.fullPathContributionMs == 2027);
assert(bounded.deadlineSlackMs == 1e6 - 2027);
assert(bounded.endToEndBoundMeetsDeadline);
assert(~bounded.allStageBudgetsMet);
assert(bounded.stageAllocationExceededWhileDeadlineMet);
assert(numel(bounded.stageContributionMs) == bounded.stageCount);
assert(numel(bounded.cumulativeFullPathMs) == ...
    bounded.maxCumulativePointCount);
assert(bounded.maxQueueWaitMs == 1000);
assert(bounded.maxCoordinationWaitMs == 1000);
assert(bounded.maxDeadlineMs == 1e6);
assert(bounded.maxCumulativePointCount == 6);
assert(bounded.maxTotalContributionMs == 2027);
assert(bounded.calculationBounded);
assert(bounded.derivedContributionWithinBound);

%% Stable malformed-input failures and stateless recovery
assertThrows(@() model([],26,90,true), ...
    'P13:InvalidQueueWait');
assertThrows(@() model('12',26,90,true), ...
    'P13:InvalidQueueWait');
assertThrows(@() model([12 12],26,90,true), ...
    'P13:InvalidQueueWait');
assertThrows(@() model(12 + 1i,26,90,true), ...
    'P13:InvalidQueueWait');
assertThrows(@() model(nan,26,90,true), ...
    'P13:InvalidQueueWait');
assertThrows(@() model(inf,26,90,true), ...
    'P13:InvalidQueueWait');
assertThrows(@() model(-1,26,90,true), ...
    'P13:InvalidQueueWait');
assertThrows(@() model(1000 + eps(1000),26,90,true), ...
    'P13:InvalidQueueWait');

assertThrows(@() model(12,[],90,true), ...
    'P13:InvalidCoordinationWait');
assertThrows(@() model(12,'26',90,true), ...
    'P13:InvalidCoordinationWait');
assertThrows(@() model(12,[26 26],90,true), ...
    'P13:InvalidCoordinationWait');
assertThrows(@() model(12,26 + 1i,90,true), ...
    'P13:InvalidCoordinationWait');
assertThrows(@() model(12,nan,90,true), ...
    'P13:InvalidCoordinationWait');
assertThrows(@() model(12,inf,90,true), ...
    'P13:InvalidCoordinationWait');
assertThrows(@() model(12,-1,90,true), ...
    'P13:InvalidCoordinationWait');
assertThrows(@() model(12,1000 + eps(1000),90,true), ...
    'P13:InvalidCoordinationWait');

assertThrows(@() model(12,26,[],true), ...
    'P13:InvalidDeadline');
assertThrows(@() model(12,26,'90',true), ...
    'P13:InvalidDeadline');
assertThrows(@() model(12,26,[90 90],true), ...
    'P13:InvalidDeadline');
assertThrows(@() model(12,26,90 + 1i,true), ...
    'P13:InvalidDeadline');
assertThrows(@() model(12,26,nan,true), ...
    'P13:InvalidDeadline');
assertThrows(@() model(12,26,inf,true), ...
    'P13:InvalidDeadline');
assertThrows(@() model(12,26,-1,true), ...
    'P13:InvalidDeadline');
assertThrows(@() model(12,26,1e6 + 1,true), ...
    'P13:InvalidDeadline');

assertThrows(@() model(12,26,90,[]), ...
    'P13:InvalidBudgetCoverage');
assertThrows(@() model(12,26,90,'true'), ...
    'P13:InvalidBudgetCoverage');
assertThrows(@() model(12,26,90,[1 1]), ...
    'P13:InvalidBudgetCoverage');
assertThrows(@() model(12,26,90,1 + 1i), ...
    'P13:InvalidBudgetCoverage');
assertThrows(@() model(12,26,90,nan), ...
    'P13:InvalidBudgetCoverage');
assertThrows(@() model(12,26,90,2), ...
    'P13:InvalidBudgetCoverage');
assertThrows(@() model(12,26,90,-1), ...
    'P13:InvalidBudgetCoverage');

recoveredAfterMalformed = model(12,26,90,true);
assert(isequaln(recoveredAfterMalformed,baseline));

fprintf(['P13 checks passed: complete budget accounting, two sweeps, ' ...
    'broken coverage, deadline boundaries, recovery targets, and bounds.\n']);
end

function assertThrows(action,expectedIdentifier)
%ASSERTTHROWS Check one stable malformed-input identifier.
caught = false;
try
    action();
catch caughtError
    caught = true;
    assert(strcmp(caughtError.identifier,expectedIdentifier), ...
        'Expected %s but received %s.', ...
        expectedIdentifier,caughtError.identifier);
end
assert(caught,'Expected error %s was not thrown.',expectedIdentifier);
end
