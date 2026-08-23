function interactive
%INTERACTIVE Manipulate one P11 backpressure lever at a time.

backpressureModel = @model;
baselineProducerIntervalMs = 10;
baselineServiceTimeMs = 20;
baselineReceiverCapacityMessages = 3;
baselineMaxBackpressureWaitMs = 200;
baselineUseBackpressure = true;
baselineCancelMessageSix = false;
interactiveFigureTag = 'P11InteractiveFigure';
existingWindows = findall(groot,'Type','figure','Tag',interactiveFigureTag);
if ~isempty(existingWindows)
    close(existingWindows);
end

window = uifigure('Name','P11 - Apply backpressure', ...
    'Tag',interactiveFigureTag,'Position',[60 60 1380 760]);
layout = uigridlayout(window,[5 6]);
layout.RowHeight = {24,34,68,'1x','1x'};
layout.ColumnWidth = {'1x','1x','1x','1x','1.2x','1.2x'};

producerLabel = uilabel(layout,'Text','Demand interval (ms)');
producerLabel.Layout.Row = 1; producerLabel.Layout.Column = 1;
serviceLabel = uilabel(layout,'Text','Service time (ms)');
serviceLabel.Layout.Row = 1; serviceLabel.Layout.Column = 2;
capacityLabel = uilabel(layout,'Text','Receiver capacity (messages)');
capacityLabel.Layout.Row = 1; capacityLabel.Layout.Column = 3;
waitLabel = uilabel(layout,'Text','Maximum upstream wait (ms)');
waitLabel.Layout.Row = 1; waitLabel.Layout.Column = 4;
policyLabel = uilabel(layout,'Text','Readiness policy');
policyLabel.Layout.Row = 1; policyLabel.Layout.Column = 5;
cancelLabel = uilabel(layout,'Text','Pending cancellation');
cancelLabel.Layout.Row = 1; cancelLabel.Layout.Column = 6;

producerControl = uispinner(layout,'Limits',[5 30], ...
    'Value',baselineProducerIntervalMs,'Step',5, ...
    'RoundFractionalValues','on');
producerControl.Layout.Row = 2; producerControl.Layout.Column = 1;
serviceControl = uispinner(layout,'Limits',[5 40], ...
    'Value',baselineServiceTimeMs,'Step',5, ...
    'RoundFractionalValues','on');
serviceControl.Layout.Row = 2; serviceControl.Layout.Column = 2;
capacityControl = uispinner(layout,'Limits',[0 12], ...
    'Value',baselineReceiverCapacityMessages,'Step',1, ...
    'RoundFractionalValues','on');
capacityControl.Layout.Row = 2; capacityControl.Layout.Column = 3;
waitControl = uispinner(layout,'Limits',[0 300], ...
    'Value',baselineMaxBackpressureWaitMs,'Step',10, ...
    'RoundFractionalValues','on');
waitControl.Layout.Row = 2; waitControl.Layout.Column = 4;
policyControl = uicheckbox(layout, ...
    'Text','Apply completion-credit backpressure', ...
    'Value',baselineUseBackpressure);
policyControl.Layout.Row = 2; policyControl.Layout.Column = 5;
cancelControl = uicheckbox(layout, ...
    'Text','Cancel message 6 if waiting', ...
    'Value',baselineCancelMessageSix);
cancelControl.Layout.Row = 2; cancelControl.Layout.Column = 6;

resetButton = uibutton(layout,'Text','Reset baseline', ...
    'ButtonPushedFcn',@resetBaseline);
resetButton.Layout.Row = 3; resetButton.Layout.Column = 1;
statusLabel = uilabel(layout,'Text','','WordWrap','on');
statusLabel.Layout.Row = 3; statusLabel.Layout.Column = [2 6];

flowAxes = uiaxes(layout);
flowAxes.Layout.Row = [4 5]; flowAxes.Layout.Column = [1 3];
pressureAxes = uiaxes(layout);
pressureAxes.Layout.Row = [4 5]; pressureAxes.Layout.Column = [4 6];

producerControl.ValueChangedFcn = @redraw;
serviceControl.ValueChangedFcn = @redraw;
capacityControl.ValueChangedFcn = @redraw;
waitControl.ValueChangedFcn = @redraw;
policyControl.ValueChangedFcn = @redraw;
cancelControl.ValueChangedFcn = @redraw;
redraw([],[]);

    function redraw(~,~)
        current = backpressureModel(producerControl.Value, ...
            serviceControl.Value,capacityControl.Value, ...
            waitControl.Value,policyControl.Value,cancelControl.Value);

        cla(flowAxes);
        stairs(flowAxes,current.observationTimeMs, ...
            current.offeredCumulative,'o-','LineWidth',1.4);
        hold(flowAxes,'on');
        stairs(flowAxes,current.observationTimeMs, ...
            current.admittedCumulative,'s--','LineWidth',1.4);
        stairs(flowAxes,current.observationTimeMs, ...
            current.completedCumulative,'d-','LineWidth',1.4);
        stairs(flowAxes,current.observationTimeMs, ...
            current.failedCumulative,'x-','LineWidth',1.4);
        hold(flowAxes,'off'); grid(flowAxes,'on');
        xlabel(flowAxes,'Analytical event time (ms)');
        ylabel(flowAxes,'Cumulative messages (count)');
        title(flowAxes,'Demand ready, receiver admission, completion, and failure');
        legend(flowAxes,{'Demand ready','Admitted','Completed','Failed'}, ...
            'Location','best');

        cla(pressureAxes);
        stairs(pressureAxes,current.observationTimeMs, ...
            current.receiverOccupancyMessages,'o-', ...
            'LineWidth',1.4);
        hold(pressureAxes,'on');
        stairs(pressureAxes,current.observationTimeMs, ...
            current.upstreamPendingMessages,'s--', ...
            'LineWidth',1.4);
        hold(pressureAxes,'off'); grid(pressureAxes,'on');
        xlabel(pressureAxes,'Analytical event time (ms)');
        ylabel(pressureAxes,'Messages (count)');
        title(pressureAxes,'Bounded receiver occupancy versus upstream pressure');
        legend(pressureAxes,{'Receiver unfinished','Upstream pending'}, ...
            'Location','best');

        if current.losslessCompletion
            decisionText = sprintf('LOSSLESS at %.1f ms', ...
                current.completionTimeOfBatchMs);
        elseif current.timedOutCount > 0
            decisionText = sprintf('TIMEOUT at %.1f ms; prefix %d', ...
                current.streamStopTimeMs,current.admittedCount);
        elseif current.canceledCount > 0
            decisionText = sprintf('CANCELED pending message 6 at %.1f ms; prefix %d', ...
                current.streamStopTimeMs,current.admittedCount);
        elseif current.droppedCount > 0
            decisionText = sprintf('READINESS IGNORED; dropped %d', ...
                current.droppedCount);
        else
            decisionText = current.outcome;
        end
        statusLabel.Text = sprintf([ ...
            '%s; admitted/completed/demand %d/%d/%d; failed %d; receiver high-water %d/%d messages; ' ...
            'upstream pending peak %d; upstream wait %.1f message-ms; service rate %.1f msg/s.'], ...
            decisionText,current.admittedCount,current.completedCount, ...
            current.messageCount,current.failedCount, ...
            current.receiverHighWaterMessages, ...
            current.receiverCapacityMessages, ...
            current.peakUpstreamPendingMessages, ...
            current.totalUpstreamWaitMessageMs, ...
            current.serviceRateMessagesPerSecond);
        drawnow limitrate;
    end

    function resetBaseline(~,~)
        producerControl.Value = baselineProducerIntervalMs;
        serviceControl.Value = baselineServiceTimeMs;
        capacityControl.Value = baselineReceiverCapacityMessages;
        waitControl.Value = baselineMaxBackpressureWaitMs;
        policyControl.Value = baselineUseBackpressure;
        cancelControl.Value = baselineCancelMessageSix;
        redraw([],[]);
    end
end
