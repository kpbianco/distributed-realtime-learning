function interactive
%INTERACTIVE Manipulate one P12 quorum-evidence lever at a time.

consensusModel = @model;
baselineDelayScale = 1;
baselineQuorumSize = 3;
baselineDecisionTimeoutMs = 100;
baselineNodeFiveOnline = true;
baselineCancelPendingProposal = false;
interactiveFigureTag = 'P12InteractiveFigure';
existingWindows = findall(groot,'Type','figure','Tag',interactiveFigureTag);
if ~isempty(existingWindows)
    close(existingWindows);
end

window = uifigure('Name','P12 - Build consensus intuition', ...
    'Tag',interactiveFigureTag,'Position',[60 60 1380 760]);
layout = uigridlayout(window,[5 5]);
layout.RowHeight = {24,34,68,'1x','1x'};
layout.ColumnWidth = {'1x','1x','1x','1.2x','1.2x'};

delayLabel = uilabel(layout,'Text','Round-trip delay scale');
delayLabel.Layout.Row = 1; delayLabel.Layout.Column = 1;
quorumLabel = uilabel(layout,'Text','Quorum size (votes)');
quorumLabel.Layout.Row = 1; quorumLabel.Layout.Column = 2;
timeoutLabel = uilabel(layout,'Text','Decision timeout (ms)');
timeoutLabel.Layout.Row = 1; timeoutLabel.Layout.Column = 3;
availabilityLabel = uilabel(layout,'Text','Node availability');
availabilityLabel.Layout.Row = 1; availabilityLabel.Layout.Column = 4;
cancelLabel = uilabel(layout,'Text','Pending cancellation');
cancelLabel.Layout.Row = 1; cancelLabel.Layout.Column = 5;

delayControl = uispinner(layout,'Limits',[0 3], ...
    'Value',baselineDelayScale,'Step',0.25);
delayControl.Layout.Row = 2; delayControl.Layout.Column = 1;
quorumControl = uispinner(layout,'Limits',[1 5], ...
    'Value',baselineQuorumSize,'Step',1, ...
    'RoundFractionalValues','on');
quorumControl.Layout.Row = 2; quorumControl.Layout.Column = 2;
timeoutControl = uispinner(layout,'Limits',[0 150], ...
    'Value',baselineDecisionTimeoutMs,'Step',5, ...
    'RoundFractionalValues','on');
timeoutControl.Layout.Row = 2; timeoutControl.Layout.Column = 3;
availabilityControl = uicheckbox(layout, ...
    'Text','Node 5 online','Value',baselineNodeFiveOnline);
availabilityControl.Layout.Row = 2; availabilityControl.Layout.Column = 4;
cancelControl = uicheckbox(layout, ...
    'Text','Cancel pending proposal at 20 ms', ...
    'Value',baselineCancelPendingProposal);
cancelControl.Layout.Row = 2; cancelControl.Layout.Column = 5;

resetButton = uibutton(layout,'Text','Reset baseline', ...
    'ButtonPushedFcn',@resetBaseline);
resetButton.Layout.Row = 3; resetButton.Layout.Column = 1;
statusLabel = uilabel(layout,'Text','','WordWrap','on');
statusLabel.Layout.Row = 3; statusLabel.Layout.Column = [2 5];

voteAxes = uiaxes(layout);
voteAxes.Layout.Row = [4 5]; voteAxes.Layout.Column = [1 2];
evidenceAxes = uiaxes(layout);
evidenceAxes.Layout.Row = [4 5]; evidenceAxes.Layout.Column = [3 5];

delayControl.ValueChangedFcn = @redraw;
quorumControl.ValueChangedFcn = @redraw;
timeoutControl.ValueChangedFcn = @redraw;
availabilityControl.ValueChangedFcn = @redraw;
cancelControl.ValueChangedFcn = @redraw;
redraw([],[]);

    function redraw(~,~)
        current = consensusModel(delayControl.Value, ...
            quorumControl.Value,timeoutControl.Value, ...
            availabilityControl.Value,cancelControl.Value);

        cla(voteAxes);
        bar(voteAxes,current.nodeId,current.potentialVoteTimeMs, ...
            'DisplayName','Potential vote evidence');
        hold(voteAxes,'on');
        yline(voteAxes,current.requestResolutionTimeMs,'k--', ...
            'LineWidth',1.2,'DisplayName','Request resolution');
        hold(voteAxes,'off');
        grid(voteAxes,'on');
        xlabel(voteAxes,'Node identifier (integer)');
        ylabel(voteAxes,'Vote observed by proposer (ms)');
        title(voteAxes,'Per-node evidence timing');
        legend(voteAxes,'Location','best');

        cla(evidenceAxes);
        stairs(evidenceAxes,current.observationTimeMs, ...
            current.observedVoteCumulative,'o-', ...
            'LineWidth',1.5,'DisplayName','Distinct votes observed');
        hold(evidenceAxes,'on');
        stairs(evidenceAxes,current.observationTimeMs, ...
            current.quorumThresholdTrace,'k--', ...
            'LineWidth',1.2,'DisplayName','Quorum threshold');
        hold(evidenceAxes,'off');
        grid(evidenceAxes,'on');
        xlabel(evidenceAxes,'Analytical event time (ms)');
        ylabel(evidenceAxes,'Observed votes (count)');
        title(evidenceAxes,'Evidence accumulation before resolution');
        legend(evidenceAxes,'Location','best');

        if current.decided
            decisionText = sprintf('CERTIFICATE OBSERVED for value %.0f at %.1f ms', ...
                current.chosenValue,current.decisionTimeMs);
        elseif current.timedOut
            decisionText = sprintf('EVALUATOR TIMED OUT at %.1f ms', ...
                current.requestResolutionTimeMs);
        else
            decisionText = sprintf('EVALUATOR CANCELED while pending at %.1f ms', ...
                current.requestResolutionTimeMs);
        end
        if current.safeMajorityQuorum
            safetyText = sprintf('intersects by at least %d node(s)', ...
                current.minimumQuorumIntersectionNodes);
        else
            safetyText = 'UNSAFE: disjoint conflicting certificates possible';
        end
        statusLabel.Text = sprintf([ ...
            '%s; observed/required/available %d/%d/%d votes; %s; ' ...
            'unavailable-follower tolerance %d (fixed proposer online).'], ...
            decisionText, ...
            current.observedVoteCount,current.quorumSize, ...
            current.availableVoteCount,safetyText, ...
            current.unavailableFollowerTolerance);
        drawnow limitrate;
    end

    function resetBaseline(~,~)
        delayControl.Value = baselineDelayScale;
        quorumControl.Value = baselineQuorumSize;
        timeoutControl.Value = baselineDecisionTimeoutMs;
        availabilityControl.Value = baselineNodeFiveOnline;
        cancelControl.Value = baselineCancelPendingProposal;
        redraw([],[]);
    end
end
