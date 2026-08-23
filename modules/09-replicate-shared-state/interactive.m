function interactive
%INTERACTIVE Manipulate one P09 replicated-state lever at a time.

replicationModel = @model;
baselinePropagationDelayScale = 1;
baselineRequiredAckCount = 4;
baselineReadAfterResponseMs = 0;
baselineSlowReplicaAvailable = true;
baselineAckTimeoutMs = 160;
interactiveFigureTag = 'P09InteractiveFigure';
existingWindows = findall(groot,'Type','figure','Tag',interactiveFigureTag);
if ~isempty(existingWindows)
    close(existingWindows);
end

window = uifigure('Name','P09 - Replicate shared state', ...
    'Tag',interactiveFigureTag,'Position',[80 80 1260 720]);
layout = uigridlayout(window,[5 5]);
layout.RowHeight = {24,34,62,'1x','1x'};
layout.ColumnWidth = {'1x','1x','1x','1x','1x'};

delayLabel = uilabel(layout,'Text','Propagation delay scale (x)');
delayLabel.Layout.Row = 1; delayLabel.Layout.Column = 1;
ackLabel = uilabel(layout,'Text','Required acknowledgments W');
ackLabel.Layout.Row = 1; ackLabel.Layout.Column = 2;
readLabel = uilabel(layout,'Text','Read after response (ms)');
readLabel.Layout.Row = 1; readLabel.Layout.Column = 3;
timeoutLabel = uilabel(layout,'Text','Acknowledgment timeout (ms)');
timeoutLabel.Layout.Row = 1; timeoutLabel.Layout.Column = 4;
availabilityLabel = uilabel(layout,'Text','Replica D availability');
availabilityLabel.Layout.Row = 1; availabilityLabel.Layout.Column = 5;

delayControl = uispinner(layout,'Limits',[0 5], ...
    'Value',baselinePropagationDelayScale,'Step',0.25);
delayControl.Layout.Row = 2; delayControl.Layout.Column = 1;
ackControl = uispinner(layout,'Limits',[1 4], ...
    'Value',baselineRequiredAckCount,'Step',1, ...
    'RoundFractionalValues','on');
ackControl.Layout.Row = 2; ackControl.Layout.Column = 2;
readControl = uispinner(layout,'Limits',[0 200], ...
    'Value',baselineReadAfterResponseMs,'Step',5, ...
    'RoundFractionalValues','on');
readControl.Layout.Row = 2; readControl.Layout.Column = 3;
timeoutControl = uispinner(layout,'Limits',[0 500], ...
    'Value',baselineAckTimeoutMs,'Step',5, ...
    'RoundFractionalValues','on');
timeoutControl.Layout.Row = 2; timeoutControl.Layout.Column = 4;
availabilityControl = uicheckbox(layout, ...
    'Text','Replica D online','Value',baselineSlowReplicaAvailable);
availabilityControl.Layout.Row = 2;
availabilityControl.Layout.Column = 5;

resetButton = uibutton(layout,'Text','Reset baseline', ...
    'ButtonPushedFcn',@resetBaseline);
resetButton.Layout.Row = 3; resetButton.Layout.Column = 1;
statusLabel = uilabel(layout,'Text','','WordWrap','on');
statusLabel.Layout.Row = 3; statusLabel.Layout.Column = [2 5];

versionAxes = uiaxes(layout);
versionAxes.Layout.Row = [4 5]; versionAxes.Layout.Column = [1 3];
timingAxes = uiaxes(layout);
timingAxes.Layout.Row = [4 5]; timingAxes.Layout.Column = [4 5];

delayControl.ValueChangedFcn = @redraw;
ackControl.ValueChangedFcn = @redraw;
readControl.ValueChangedFcn = @redraw;
timeoutControl.ValueChangedFcn = @redraw;
availabilityControl.ValueChangedFcn = @redraw;
redraw([],[]);

    function redraw(~,~)
        current = replicationModel(delayControl.Value,ackControl.Value, ...
            readControl.Value,availabilityControl.Value, ...
            timeoutControl.Value);

        cla(versionAxes);
        bar(versionAxes,current.replicaIndex, ...
            [current.replicaVersionAtResponse(:), ...
            current.replicaVersionAtRead(:)]);
        grid(versionAxes,'on');
        versionAxes.XTick = current.replicaIndex;
        versionAxes.XTickLabel = current.replicaLabels;
        xlabel(versionAxes,'Replica');
        ylabel(versionAxes,'Applied state version (integer)');
        title(versionAxes,'Visibility at response and slow-replica read');
        legend(versionAxes,{'At client response','At read time'}, ...
            'Location','best');

        cla(timingAxes);
        bar(timingAxes,current.replicaIndex,current.nominalApplyTimeMs);
        hold(timingAxes,'on');
        yline(timingAxes,current.clientResponseTimeMs,'k--', ...
            'Client response','LineWidth',1.2);
        hold(timingAxes,'off'); grid(timingAxes,'on');
        timingAxes.XTick = current.replicaIndex;
        timingAxes.XTickLabel = current.replicaLabels;
        xlabel(timingAxes,'Replica');
        ylabel(timingAxes,'Time after primary accepts update (ms)');
        title(timingAxes,'Apply time versus acknowledgment/timeout response');

        if current.writeAcknowledged
            responseText = sprintf('acknowledged at %.1f ms', ...
                current.clientResponseTimeMs);
        else
            responseText = sprintf('TIMED OUT at %.1f ms', ...
                current.clientResponseTimeMs);
        end
        if current.readSucceeded
            readText = sprintf('Replica D returned version %.0f at %.1f ms', ...
                current.readVersion,current.readTimeMs);
        else
            readText = sprintf('Replica D read unavailable at %.1f ms', ...
                current.readTimeMs);
        end
        statusLabel.Text = sprintf([ ...
            'Write %s with %d/%d replicas current; %s; outcome: %s. ' ...
            'Acknowledgment count is not universal visibility.'], ...
            responseText,current.currentReplicaCountAtResponse, ...
            current.replicaCount,readText,current.outcome);
        drawnow limitrate;
    end

    function resetBaseline(~,~)
        delayControl.Value = baselinePropagationDelayScale;
        ackControl.Value = baselineRequiredAckCount;
        readControl.Value = baselineReadAfterResponseMs;
        availabilityControl.Value = baselineSlowReplicaAvailable;
        timeoutControl.Value = baselineAckTimeoutMs;
        redraw([],[]);
    end
end
