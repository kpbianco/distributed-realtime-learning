function interactive
%INTERACTIVE Manipulate one P05 timestamp-decomposition input at a time.

clockModel = @model;
sampleCount = 8;
propagationDelayMs = 3;
baselineOffsetMs = 7;
baselineQueuePeakMs = 8;
baselineHiddenCommonMs = 0;
baselineAssumedMinimumMs = 3;
interactiveFigureTag = 'P05InteractiveFigure';
existingWindows = findall(groot,'Type','figure','Tag',interactiveFigureTag);
if ~isempty(existingWindows)
    close(existingWindows);
end

window = uifigure('Name','P05 - Clock offset versus network delay', ...
    'Tag',interactiveFigureTag,'Position',[100 100 1120 700]);
layout = uigridlayout(window,[5 4]);
layout.RowHeight = {24,34,52,'1x','1x'};
layout.ColumnWidth = {'1x','1x','1x','1x'};

offsetLabel = uilabel(layout,'Text','Receiver - sender offset (ms)');
offsetLabel.Layout.Row = 1; offsetLabel.Layout.Column = 1;
queueLabel = uilabel(layout,'Text','Peak additional queue delay (ms)');
queueLabel.Layout.Row = 1; queueLabel.Layout.Column = 2;
hiddenLabel = uilabel(layout,'Text','Hidden common network delay (ms)');
hiddenLabel.Layout.Row = 1; hiddenLabel.Layout.Column = 3;
floorLabel = uilabel(layout,'Text','Assumed attainable delay floor (ms)');
floorLabel.Layout.Row = 1; floorLabel.Layout.Column = 4;

offsetControl = uispinner(layout,'Limits',[-20 20],'Value',baselineOffsetMs, ...
    'Step',1,'RoundFractionalValues','on');
offsetControl.Layout.Row = 2; offsetControl.Layout.Column = 1;
queueControl = uispinner(layout,'Limits',[0 20],'Value',baselineQueuePeakMs, ...
    'Step',1,'RoundFractionalValues','on');
queueControl.Layout.Row = 2; queueControl.Layout.Column = 2;
hiddenControl = uispinner(layout,'Limits',[0 10],'Value',baselineHiddenCommonMs, ...
    'Step',1,'RoundFractionalValues','on');
hiddenControl.Layout.Row = 2; hiddenControl.Layout.Column = 3;
floorControl = uispinner(layout,'Limits',[0 20],'Value',baselineAssumedMinimumMs, ...
    'Step',1,'RoundFractionalValues','on');
floorControl.Layout.Row = 2; floorControl.Layout.Column = 4;

resetButton = uibutton(layout,'Text','Reset baseline', ...
    'ButtonPushedFcn',@resetBaseline);
resetButton.Layout.Row = 3; resetButton.Layout.Column = 1;
statusLabel = uilabel(layout,'Text','','WordWrap','on');
statusLabel.Layout.Row = 3; statusLabel.Layout.Column = [2 4];

observationAxes = uiaxes(layout);
observationAxes.Layout.Row = [4 5]; observationAxes.Layout.Column = [1 2];
delayAxes = uiaxes(layout);
delayAxes.Layout.Row = [4 5]; delayAxes.Layout.Column = [3 4];

offsetControl.ValueChangedFcn = @redraw;
queueControl.ValueChangedFcn = @redraw;
hiddenControl.ValueChangedFcn = @redraw;
floorControl.ValueChangedFcn = @redraw;
redraw([],[]);

    function redraw(~,~)
        current = clockModel(sampleCount,offsetControl.Value,propagationDelayMs, ...
            queueControl.Value,hiddenControl.Value,floorControl.Value);

        cla(observationAxes);
        plot(observationAxes,current.sampleIndex, ...
            current.observedTimestampDifferenceMs,'o-','LineWidth',1.4, ...
            'DisplayName','Receiver minus sender timestamp');
        hold(observationAxes,'on');
        yline(observationAxes,current.minimumObservedDifferenceMs,'k--', ...
            'LineWidth',1.2,'DisplayName','Observed lower envelope');
        hold(observationAxes,'off');
        grid(observationAxes,'on');
        xlabel(observationAxes,'Paired sample index');
        ylabel(observationAxes,'Cross-clock timestamp difference (ms)');
        title(observationAxes,'Endpoint-observable sum');
        legend(observationAxes,'Location','best');

        cla(delayAxes);
        plot(delayAxes,current.sampleIndex,current.trueNetworkDelayMs,'o-', ...
            'LineWidth',1.4,'DisplayName','Simulated true network delay');
        hold(delayAxes,'on');
        plot(delayAxes,current.sampleIndex,current.estimatedNetworkDelayMs,'s--', ...
            'LineWidth',1.4,'DisplayName','Anchored delay estimate');
        yline(delayAxes,current.assumedMinimumDelayMs,'k:', ...
            'LineWidth',1.2,'DisplayName','Assumed attainable floor');
        hold(delayAxes,'off');
        grid(delayAxes,'on');
        xlabel(delayAxes,'Paired sample index');
        ylabel(delayAxes,'One-way network delay (ms)');
        title(delayAxes,'Teaching truth versus inferred component');
        legend(delayAxes,'Location','best');

        if current.minimumDelayAnchorSatisfiedInTruth
            anchorText = 'truth diagnostic: anchor satisfied';
        else
            anchorText = 'truth diagnostic: AMBIGUOUS false anchor';
        end
        statusLabel.Text = sprintf([ ...
            'True offset %.0f ms; estimate %.0f ms (error %+.0f ms); spread %.0f ms; ' ...
            'residual %.3g ms; %s.'],current.clockOffsetMs, ...
            current.estimatedClockOffsetMs,current.clockOffsetErrorMs, ...
            current.observedDifferenceSpreadMs, ...
            current.maxAbsReconstructionResidualMs,anchorText);
        drawnow limitrate;
    end

    function resetBaseline(~,~)
        offsetControl.Value = baselineOffsetMs;
        queueControl.Value = baselineQueuePeakMs;
        hiddenControl.Value = baselineHiddenCommonMs;
        floorControl.Value = baselineAssumedMinimumMs;
        redraw([],[]);
    end
end
