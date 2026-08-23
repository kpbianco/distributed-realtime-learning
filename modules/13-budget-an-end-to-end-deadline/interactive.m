function interactive
%INTERACTIVE Manipulate one P13 deadline-budget lever at a time.

budgetModel = @model;
baselineQueueWaitMs = 12;
baselineCoordinationWaitMs = 26;
baselineDeadlineMs = 90;
baselineIncludeCoordinationBudget = true;
interactiveFigureTag = 'P13InteractiveFigure';
existingWindows = findall(groot,'Type','figure','Tag',interactiveFigureTag);
if ~isempty(existingWindows)
    close(existingWindows);
end

window = uifigure('Name','P13 - Budget an end-to-end deadline', ...
    'Tag',interactiveFigureTag,'Position',[70 70 1360 760]);
layout = uigridlayout(window,[5 4]);
layout.RowHeight = {24,34,72,'1x','1x'};
layout.ColumnWidth = {'1x','1x','1x','1.2x'};

queueLabel = uilabel(layout,'Text','Queue/admission wait (ms)');
queueLabel.Layout.Row = 1; queueLabel.Layout.Column = 1;
coordinationLabel = uilabel(layout, ...
    'Text','Coordination evidence wait (ms)');
coordinationLabel.Layout.Row = 1; coordinationLabel.Layout.Column = 2;
deadlineLabel = uilabel(layout,'Text','End-to-end deadline (ms)');
deadlineLabel.Layout.Row = 1; deadlineLabel.Layout.Column = 3;
coverageLabel = uilabel(layout,'Text','Budget ownership');
coverageLabel.Layout.Row = 1; coverageLabel.Layout.Column = 4;

queueControl = uispinner(layout,'Limits',[0 40], ...
    'Value',baselineQueueWaitMs,'Step',2);
queueControl.Layout.Row = 2; queueControl.Layout.Column = 1;
coordinationControl = uispinner(layout,'Limits',[0 60], ...
    'Value',baselineCoordinationWaitMs,'Step',2);
coordinationControl.Layout.Row = 2; coordinationControl.Layout.Column = 2;
deadlineControl = uispinner(layout,'Limits',[0 120], ...
    'Value',baselineDeadlineMs,'Step',5);
deadlineControl.Layout.Row = 2; deadlineControl.Layout.Column = 3;
coverageControl = uicheckbox(layout, ...
    'Text','Include coordination stage', ...
    'Value',baselineIncludeCoordinationBudget);
coverageControl.Layout.Row = 2; coverageControl.Layout.Column = 4;

resetButton = uibutton(layout,'Text','Reset baseline', ...
    'ButtonPushedFcn',@resetBaseline);
resetButton.Layout.Row = 3; resetButton.Layout.Column = 1;
statusLabel = uilabel(layout,'Text','','WordWrap','on');
statusLabel.Layout.Row = 3; statusLabel.Layout.Column = [2 4];

stageAxes = uiaxes(layout);
stageAxes.Layout.Row = [4 5]; stageAxes.Layout.Column = [1 2];
cumulativeAxes = uiaxes(layout);
cumulativeAxes.Layout.Row = [4 5]; cumulativeAxes.Layout.Column = [3 4];

queueControl.ValueChangedFcn = @redraw;
coordinationControl.ValueChangedFcn = @redraw;
deadlineControl.ValueChangedFcn = @redraw;
coverageControl.ValueChangedFcn = @redraw;
redraw([],[]);

    function redraw(~,~)
        current = budgetModel(queueControl.Value, ...
            coordinationControl.Value,deadlineControl.Value, ...
            coverageControl.Value);

        cla(stageAxes);
        bar(stageAxes,current.stageId,[current.stageContributionMs(:) ...
            current.assignedStageBudgetMs(:)]);
        grid(stageAxes,'on');
        xlabel(stageAxes,'Ordered end-to-end stage (identifier)');
        ylabel(stageAxes,'Declared contribution or allocation (ms)');
        title(stageAxes,'Per-stage contribution and ownership');
        stageAxes.XTick = current.stageId;
        stageAxes.XTickLabel = ...
            {'Source','Queue','Network','Coordination','Destination'};
        legend(stageAxes,{'Declared contribution','Assigned budget'}, ...
            'Location','best');

        cla(cumulativeAxes);
        plot(cumulativeAxes,0:current.stageCount, ...
            current.cumulativeFullPathMs,'o-','LineWidth',1.5, ...
            'DisplayName','Complete path');
        hold(cumulativeAxes,'on');
        plot(cumulativeAxes,0:current.stageCount, ...
            current.cumulativeAccountedPathMs,'s-', ...
            'LineWidth',1.5,'DisplayName','Accounted path');
        plot(cumulativeAxes,0:current.stageCount, ...
            current.cumulativeAssignedBudgetMs,'d-', ...
            'LineWidth',1.5,'DisplayName','Assigned budget');
        yline(cumulativeAxes,current.deadlineMs,'k--', ...
            'LineWidth',1.2,'DisplayName','Deadline');
        hold(cumulativeAxes,'off');
        grid(cumulativeAxes,'on');
        xlabel(cumulativeAxes,'Completed stage boundary (count)');
        ylabel(cumulativeAxes,'Cumulative time (ms)');
        title(cumulativeAxes,'Complete path versus accounted budget');
        legend(cumulativeAxes,'Location','best');

        if current.endToEndBoundMeetsDeadline
            pathText = sprintf('DECLARED PATH WITHIN DEADLINE by %.1f ms', ...
                current.deadlineSlackMs);
        else
            pathText = sprintf('NO GUARANTEE: path exceeds deadline by %.1f ms', ...
                current.deadlineMissMs);
        end
        if current.budgetPlanCredible
            planText = 'complete allocation plan is credible';
        elseif ~current.budgetCoverageComplete
            planText = sprintf('INCOMPLETE: %.1f ms is unowned', ...
                current.unbudgetedContributionMs);
        elseif ~current.allocationFitsDeadline
            planText = sprintf('allocations exceed deadline by %.1f ms', ...
                -current.allocationReserveMs);
        else
            planText = 'one or more stage allocations are exceeded';
        end
        % Deadline is a classification, not a running timeout.
        statusLabel.Text = sprintf([ ...
            '%s; %s; full/apparent slack %.1f/%.1f ms; ' ...
            'allocation reserve %.1f ms. Deadline is a classification, ' ...
            'not a running timeout.'],pathText,planText, ...
            current.deadlineSlackMs,current.apparentAccountedSlackMs, ...
            current.allocationReserveMs);
        drawnow limitrate;
    end

    function resetBaseline(~,~)
        queueControl.Value = baselineQueueWaitMs;
        coordinationControl.Value = baselineCoordinationWaitMs;
        deadlineControl.Value = baselineDeadlineMs;
        coverageControl.Value = baselineIncludeCoordinationBudget;
        redraw([],[]);
    end
end
