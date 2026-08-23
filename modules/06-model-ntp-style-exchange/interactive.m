function interactive
%INTERACTIVE Manipulate one P06 four-timestamp input at a time.

exchangeModel = @model;
clientSendTimeMs = 100;
baselineOffsetMs = 7;
baselineForwardDelayMs = 4;
baselineReverseDelayMs = 4;
baselineServerProcessingMs = 2;
interactiveFigureTag = 'P06InteractiveFigure';
existingWindows = findall(groot,'Type','figure','Tag',interactiveFigureTag);
if ~isempty(existingWindows)
    close(existingWindows);
end

window = uifigure('Name','P06 - NTP-style four-timestamp exchange', ...
    'Tag',interactiveFigureTag,'Position',[100 100 1160 720]);
layout = uigridlayout(window,[5 4]);
layout.RowHeight = {24,34,58,'1x','1x'};
layout.ColumnWidth = {'1x','1x','1x','1x'};

offsetLabel = uilabel(layout,'Text','Server - client offset (ms)');
offsetLabel.Layout.Row = 1; offsetLabel.Layout.Column = 1;
forwardLabel = uilabel(layout,'Text','Forward path delay (ms)');
forwardLabel.Layout.Row = 1; forwardLabel.Layout.Column = 2;
reverseLabel = uilabel(layout,'Text','Reverse path delay (ms)');
reverseLabel.Layout.Row = 1; reverseLabel.Layout.Column = 3;
processingLabel = uilabel(layout,'Text','Server residence (ms)');
processingLabel.Layout.Row = 1; processingLabel.Layout.Column = 4;

offsetControl = uispinner(layout,'Limits',[-20 20],'Value',baselineOffsetMs, ...
    'Step',1,'RoundFractionalValues','on');
offsetControl.Layout.Row = 2; offsetControl.Layout.Column = 1;
forwardControl = uispinner(layout,'Limits',[0 20], ...
    'Value',baselineForwardDelayMs,'Step',1,'RoundFractionalValues','on');
forwardControl.Layout.Row = 2; forwardControl.Layout.Column = 2;
reverseControl = uispinner(layout,'Limits',[0 20], ...
    'Value',baselineReverseDelayMs,'Step',1,'RoundFractionalValues','on');
reverseControl.Layout.Row = 2; reverseControl.Layout.Column = 3;
processingControl = uispinner(layout,'Limits',[0 20], ...
    'Value',baselineServerProcessingMs,'Step',1,'RoundFractionalValues','on');
processingControl.Layout.Row = 2; processingControl.Layout.Column = 4;

resetButton = uibutton(layout,'Text','Reset baseline', ...
    'ButtonPushedFcn',@resetBaseline);
resetButton.Layout.Row = 3; resetButton.Layout.Column = 1;
statusLabel = uilabel(layout,'Text','','WordWrap','on');
statusLabel.Layout.Row = 3; statusLabel.Layout.Column = [2 4];

eventAxes = uiaxes(layout);
eventAxes.Layout.Row = [4 5]; eventAxes.Layout.Column = [1 2];
estimateAxes = uiaxes(layout);
estimateAxes.Layout.Row = [4 5]; estimateAxes.Layout.Column = [3 4];

offsetControl.ValueChangedFcn = @redraw;
forwardControl.ValueChangedFcn = @redraw;
reverseControl.ValueChangedFcn = @redraw;
processingControl.ValueChangedFcn = @redraw;
redraw([],[]);

    function redraw(~,~)
        current = exchangeModel(clientSendTimeMs,offsetControl.Value, ...
            forwardControl.Value,reverseControl.Value,processingControl.Value);

        cla(eventAxes);
        eventEndpoint = [1;2;2;1];
        plot(eventAxes,current.trueEventElapsedMs,eventEndpoint,'o-', ...
            'LineWidth',1.4);
        grid(eventAxes,'on');
        eventAxes.YTick = [1 2];
        eventAxes.YTickLabel = {'Client','Server'};
        eventAxes.YLim = [0.7 2.3];
        xlabel(eventAxes,'Simulated true elapsed time since T1 (ms)');
        ylabel(eventAxes,'Endpoint (simulation truth)');
        title(eventAxes,'Four-event request/reply path');

        cla(estimateAxes);
        displayedMetricsMs = [current.clockOffsetMs; ...
            current.estimatedClockOffsetMs;current.forwardDelayMs; ...
            current.reverseDelayMs;current.estimatedSymmetricOneWayDelayMs];
        bar(estimateAxes,1:5,displayedMetricsMs);
        grid(estimateAxes,'on');
        estimateAxes.XTick = 1:5;
        estimateAxes.XTickLabel = {'True offset','Estimated offset', ...
            'Forward truth','Reverse truth','RTT / 2'};
        estimateAxes.XTickLabelRotation = 18;
        xlabel(estimateAxes,'Truth-only metric or endpoint estimate');
        ylabel(estimateAxes,'Time (ms)');
        title(estimateAxes,'Offset and directional-delay inference');

        if current.pathSymmetrySatisfiedInTruth
            symmetryText = 'truth diagnostic: symmetric path';
        else
            symmetryText = 'truth diagnostic: ASYMMETRIC path';
        end
        statusLabel.Text = sprintf([ ...
            'T=[%.0f %.0f %.0f %.0f] ms; offset estimate %.1f ms (error %+.1f ms); ' ...
            'network RTT %.1f ms; client elapsed %.1f ms; %s.'], ...
            current.timestampObservationMs,current.estimatedClockOffsetMs, ...
            current.clockOffsetErrorMs,current.estimatedNetworkRoundTripDelayMs, ...
            current.clientElapsedMs,symmetryText);
        drawnow limitrate;
    end

    function resetBaseline(~,~)
        offsetControl.Value = baselineOffsetMs;
        forwardControl.Value = baselineForwardDelayMs;
        reverseControl.Value = baselineReverseDelayMs;
        processingControl.Value = baselineServerProcessingMs;
        redraw([],[]);
    end
end
