function interactive
%INTERACTIVE Manipulate one P08 schedule-distribution lever at a time.

scheduleModel = @model;
baselineClockErrorBoundUs = 20;
baselineActivationLeadUs = 1500;
baselineDistributionDelayScale = 1;
baselineAllOrNothingActivation = true;
interactiveFigureTag = 'P08InteractiveFigure';
existingWindows = findall(groot,'Type','figure','Tag',interactiveFigureTag);
if ~isempty(existingWindows)
    close(existingWindows);
end

window = uifigure('Name','P08 - Distributed time-triggered schedule', ...
    'Tag',interactiveFigureTag,'Position',[100 100 1180 720]);
layout = uigridlayout(window,[5 4]);
layout.RowHeight = {24,34,62,'1x','1x'};
layout.ColumnWidth = {'1x','1x','1x','1x'};

clockLabel = uilabel(layout,'Text','Residual clock-error bound E (us)');
clockLabel.Layout.Row = 1; clockLabel.Layout.Column = 1;
leadLabel = uilabel(layout,'Text','Shared activation lead (us)');
leadLabel.Layout.Row = 1; leadLabel.Layout.Column = 2;
delayLabel = uilabel(layout,'Text','Distribution delay scale (x)');
delayLabel.Layout.Row = 1; delayLabel.Layout.Column = 3;
policyLabel = uilabel(layout,'Text','Version activation policy');
policyLabel.Layout.Row = 1; policyLabel.Layout.Column = 4;

clockControl = uispinner(layout,'Limits',[0 100], ...
    'Value',baselineClockErrorBoundUs,'Step',5, ...
    'RoundFractionalValues','on');
clockControl.Layout.Row = 2; clockControl.Layout.Column = 1;
leadControl = uispinner(layout,'Limits',[0 2500], ...
    'Value',baselineActivationLeadUs,'Step',50, ...
    'RoundFractionalValues','on');
leadControl.Layout.Row = 2; leadControl.Layout.Column = 2;
delayControl = uispinner(layout,'Limits',[0 2], ...
    'Value',baselineDistributionDelayScale,'Step',0.25);
delayControl.Layout.Row = 2; delayControl.Layout.Column = 3;
policyControl = uicheckbox(layout,'Text','All-or-nothing versions', ...
    'Value',baselineAllOrNothingActivation);
policyControl.Layout.Row = 2; policyControl.Layout.Column = 4;

resetButton = uibutton(layout,'Text','Reset baseline', ...
    'ButtonPushedFcn',@resetBaseline);
resetButton.Layout.Row = 3; resetButton.Layout.Column = 1;
statusLabel = uilabel(layout,'Text','','WordWrap','on');
statusLabel.Layout.Row = 3; statusLabel.Layout.Column = [2 4];

startAxes = uiaxes(layout);
startAxes.Layout.Row = [4 5]; startAxes.Layout.Column = [1 2];
gapAxes = uiaxes(layout);
gapAxes.Layout.Row = [4 5]; gapAxes.Layout.Column = [3 4];

clockControl.ValueChangedFcn = @redraw;
leadControl.ValueChangedFcn = @redraw;
delayControl.ValueChangedFcn = @redraw;
policyControl.ValueChangedFcn = @redraw;
redraw([],[]);

    function redraw(~,~)
        current = scheduleModel(clockControl.Value,leadControl.Value, ...
            delayControl.Value,policyControl.Value);

        cla(startAxes);
        relativeStartUs = current.actionStartRelativeToActivationUs;
        bar(startAxes,current.nodeIndex, ...
            [current.selectedPhaseUs(:),relativeStartUs(:)]);
        grid(startAxes,'on');
        startAxes.XTick = current.nodeIndex;
        startAxes.XTickLabel = current.nodeLabels;
        xlabel(startAxes,'Scheduled node');
        ylabel(startAxes,'Action start relative to activation (us)');
        title(startAxes,'Local schedule time versus true start');
        legend(startAxes,{'Selected schedule phase','True start'}, ...
            'Location','best');

        cla(gapAxes);
        bar(gapAxes,1:current.actionCount, ...
            current.separationToNextActionUs);
        hold(gapAxes,'on');
        yline(gapAxes,0,'k--','LineWidth',1.2);
        hold(gapAxes,'off'); grid(gapAxes,'on');
        xlabel(gapAxes, ...
            'Action transition in true-time order (including cycle wrap)');
        ylabel(gapAxes,'Separation before next action (us)');
        title(gapAxes,'Negative separation means shared-channel overlap');

        if current.configurationCoherent
            versionText = sprintf('coherent version %d', ...
                current.activeScheduleVersion(1));
        else
            versionText = 'MIXED schedule versions';
        end
        statusLabel.Text = sprintf([ ...
            '%d/%d nodes ready; min readiness slack %.1f us; %s; ' ...
            'min separation %.1f us; max overlap %.1f us; state: %s.'], ...
            current.readyNodeCount,current.nodeCount, ...
            current.minimumActivationSlackUs,versionText, ...
            current.minimumSeparationUs,current.maximumOverlapUs, ...
            current.scheduleState);
        drawnow limitrate;
    end

    function resetBaseline(~,~)
        clockControl.Value = baselineClockErrorBoundUs;
        leadControl.Value = baselineActivationLeadUs;
        delayControl.Value = baselineDistributionDelayScale;
        policyControl.Value = baselineAllOrNothingActivation;
        redraw([],[]);
    end
end
