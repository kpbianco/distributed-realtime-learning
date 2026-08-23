function interactive
%INTERACTIVE Manipulate one P07 timestamp-placement lever at a time.

timestampModel = @model;
startTimeNs = 100000;
clockOffsetNs = 120;
forwardDelayNs = 800;
followerTurnaroundNs = 4000;
baselineHostLatencyScale = 1;
baselineHardwareTickNs = 8;
baselineCalibrationFraction = 1;
baselineReverseDelayNs = 800;
interactiveFigureTag = 'P07InteractiveFigure';
existingWindows = findall(groot,'Type','figure','Tag',interactiveFigureTag);
if ~isempty(existingWindows)
    close(existingWindows);
end

window = uifigure('Name','P07 - PTP timestamp capture planes', ...
    'Tag',interactiveFigureTag,'Position',[100 100 1180 720]);
layout = uigridlayout(window,[5 4]);
layout.RowHeight = {24,34,58,'1x','1x'};
layout.ColumnWidth = {'1x','1x','1x','1x'};

hostLabel = uilabel(layout,'Text','Host timestamp-path scale (x)');
hostLabel.Layout.Row = 1; hostLabel.Layout.Column = 1;
tickLabel = uilabel(layout,'Text','Hardware timestamp tick (ns)');
tickLabel.Layout.Row = 1; tickLabel.Layout.Column = 2;
calibrationLabel = uilabel(layout,'Text','Reference-plane calibration fraction');
calibrationLabel.Layout.Row = 1; calibrationLabel.Layout.Column = 3;
reverseLabel = uilabel(layout,'Text','Reverse wire delay (ns)');
reverseLabel.Layout.Row = 1; reverseLabel.Layout.Column = 4;

hostControl = uispinner(layout,'Limits',[0 2], ...
    'Value',baselineHostLatencyScale,'Step',0.25);
hostControl.Layout.Row = 2; hostControl.Layout.Column = 1;
tickControl = uispinner(layout,'Limits',[1 128], ...
    'Value',baselineHardwareTickNs,'Step',1,'RoundFractionalValues','on');
tickControl.Layout.Row = 2; tickControl.Layout.Column = 2;
calibrationControl = uispinner(layout,'Limits',[0 1.5], ...
    'Value',baselineCalibrationFraction,'Step',0.1);
calibrationControl.Layout.Row = 2; calibrationControl.Layout.Column = 3;
reverseControl = uispinner(layout,'Limits',[0 1600], ...
    'Value',baselineReverseDelayNs,'Step',100,'RoundFractionalValues','on');
reverseControl.Layout.Row = 2; reverseControl.Layout.Column = 4;

resetButton = uibutton(layout,'Text','Reset baseline', ...
    'ButtonPushedFcn',@resetBaseline);
resetButton.Layout.Row = 3; resetButton.Layout.Column = 1;
statusLabel = uilabel(layout,'Text','','WordWrap','on');
statusLabel.Layout.Row = 3; statusLabel.Layout.Column = [2 4];

offsetAxes = uiaxes(layout);
offsetAxes.Layout.Row = [4 5]; offsetAxes.Layout.Column = [1 2];
errorAxes = uiaxes(layout);
errorAxes.Layout.Row = [4 5]; errorAxes.Layout.Column = [3 4];

hostControl.ValueChangedFcn = @redraw;
tickControl.ValueChangedFcn = @redraw;
calibrationControl.ValueChangedFcn = @redraw;
reverseControl.ValueChangedFcn = @redraw;
redraw([],[]);

    function redraw(~,~)
        current = timestampModel(startTimeNs,clockOffsetNs,forwardDelayNs, ...
            reverseControl.Value,followerTurnaroundNs,hostControl.Value, ...
            tickControl.Value,calibrationControl.Value);

        cla(offsetAxes);
        plot(offsetAxes,current.exchangeIndex, ...
            current.softwareEstimatedClockOffsetNs,'o-','LineWidth',1.4, ...
            'DisplayName','Software capture'); hold(offsetAxes,'on');
        plot(offsetAxes,current.exchangeIndex, ...
            current.hardwareEstimatedClockOffsetNs,'s-','LineWidth',1.4, ...
            'DisplayName','Hardware capture');
        yline(offsetAxes,current.clockOffsetNs,'k--','LineWidth',1.2, ...
            'DisplayName','Simulated true offset');
        hold(offsetAxes,'off'); grid(offsetAxes,'on');
        xlabel(offsetAxes,'Deterministic exchange index');
        ylabel(offsetAxes,'Estimated follower-minus-leader offset (ns)');
        title(offsetAxes,'Capture-plane offset estimates');
        legend(offsetAxes,'Location','best');

        cla(errorAxes);
        displayedErrorNs = [current.softwareMaxAbsClockOffsetErrorNs, ...
            current.hardwareMaxAbsClockOffsetErrorNs; ...
            current.softwareMaxAbsRoundTripErrorNs, ...
            current.hardwareMaxAbsRoundTripErrorNs];
        bar(errorAxes,1:2,displayedErrorNs);
        grid(errorAxes,'on');
        errorAxes.XTick = 1:2;
        errorAxes.XTickLabel = {'Offset','Round trip'};
        xlabel(errorAxes,'Four-timestamp estimate');
        ylabel(errorAxes,'Maximum absolute error (ns)');
        title(errorAxes,'Accuracy error, not just precision');
        legend(errorAxes,{'Software capture','Hardware capture'}, ...
            'Location','best');

        if current.pathSymmetrySatisfiedInTruth
            pathText = 'truth diagnostic: symmetric wire path';
        else
            pathText = 'truth diagnostic: ASYMMETRIC wire path';
        end
        statusLabel.Text = sprintf([ ...
            'Software mean/range %.1f/%.1f ns; hardware mean/range %.1f/%.1f ns; ' ...
            'hardware RTT max error %.1f ns; %s; state: %s.'], ...
            current.softwareMeanClockOffsetEstimateNs, ...
            current.softwareOffsetPeakToPeakNs, ...
            current.hardwareMeanClockOffsetEstimateNs, ...
            current.hardwareOffsetPeakToPeakNs, ...
            current.hardwareMaxAbsRoundTripErrorNs,pathText,current.hardwareState);
        drawnow limitrate;
    end

    function resetBaseline(~,~)
        hostControl.Value = baselineHostLatencyScale;
        tickControl.Value = baselineHardwareTickNs;
        calibrationControl.Value = baselineCalibrationFraction;
        reverseControl.Value = baselineReverseDelayNs;
        redraw([],[]);
    end
end
