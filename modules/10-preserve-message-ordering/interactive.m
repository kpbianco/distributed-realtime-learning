function interactive
%INTERACTIVE Manipulate one P10 message-ordering lever at a time.

orderingModel = @model;
baselineDelayScale = 1;
baselineBufferCapacity = 2;
baselineGapTimeoutMs = 100;
baselineMessageThreeAvailable = true;
baselinePreserveSequenceOrder = true;
interactiveFigureTag = 'P10InteractiveFigure';
existingWindows = findall(groot,'Type','figure','Tag',interactiveFigureTag);
if ~isempty(existingWindows)
    close(existingWindows);
end

window = uifigure('Name','P10 - Preserve message ordering', ...
    'Tag',interactiveFigureTag,'Position',[80 80 1280 720]);
layout = uigridlayout(window,[5 5]);
layout.RowHeight = {24,34,62,'1x','1x'};
layout.ColumnWidth = {'1x','1x','1x','1x','1x'};

delayLabel = uilabel(layout,'Text','Path-delay scale (x)');
delayLabel.Layout.Row = 1; delayLabel.Layout.Column = 1;
capacityLabel = uilabel(layout,'Text','Reorder capacity (messages)');
capacityLabel.Layout.Row = 1; capacityLabel.Layout.Column = 2;
timeoutLabel = uilabel(layout,'Text','Gap timeout (ms)');
timeoutLabel.Layout.Row = 1; timeoutLabel.Layout.Column = 3;
availabilityLabel = uilabel(layout,'Text','Message 3 availability');
availabilityLabel.Layout.Row = 1; availabilityLabel.Layout.Column = 4;
policyLabel = uilabel(layout,'Text','Receiver delivery policy');
policyLabel.Layout.Row = 1; policyLabel.Layout.Column = 5;

delayControl = uispinner(layout,'Limits',[0 3], ...
    'Value',baselineDelayScale,'Step',0.25);
delayControl.Layout.Row = 2; delayControl.Layout.Column = 1;
capacityControl = uispinner(layout,'Limits',[0 6], ...
    'Value',baselineBufferCapacity,'Step',1, ...
    'RoundFractionalValues','on');
capacityControl.Layout.Row = 2; capacityControl.Layout.Column = 2;
timeoutControl = uispinner(layout,'Limits',[0 200], ...
    'Value',baselineGapTimeoutMs,'Step',5, ...
    'RoundFractionalValues','on');
timeoutControl.Layout.Row = 2; timeoutControl.Layout.Column = 3;
availabilityControl = uicheckbox(layout, ...
    'Text','Message 3 arrives','Value',baselineMessageThreeAvailable);
availabilityControl.Layout.Row = 2;
availabilityControl.Layout.Column = 4;
policyControl = uicheckbox(layout, ...
    'Text','Use sequence reorder buffer', ...
    'Value',baselinePreserveSequenceOrder);
policyControl.Layout.Row = 2; policyControl.Layout.Column = 5;

resetButton = uibutton(layout,'Text','Reset baseline', ...
    'ButtonPushedFcn',@resetBaseline);
resetButton.Layout.Row = 3; resetButton.Layout.Column = 1;
statusLabel = uilabel(layout,'Text','','WordWrap','on');
statusLabel.Layout.Row = 3; statusLabel.Layout.Column = [2 5];

timingAxes = uiaxes(layout);
timingAxes.Layout.Row = [4 5]; timingAxes.Layout.Column = [1 3];
orderAxes = uiaxes(layout);
orderAxes.Layout.Row = [4 5]; orderAxes.Layout.Column = [4 5];

delayControl.ValueChangedFcn = @redraw;
capacityControl.ValueChangedFcn = @redraw;
timeoutControl.ValueChangedFcn = @redraw;
availabilityControl.ValueChangedFcn = @redraw;
policyControl.ValueChangedFcn = @redraw;
redraw([],[]);

    function redraw(~,~)
        current = orderingModel(delayControl.Value, ...
            capacityControl.Value,timeoutControl.Value, ...
            availabilityControl.Value,policyControl.Value);

        cla(timingAxes);
        plot(timingAxes,current.sequence,current.sendTimeMs,'o-', ...
            'LineWidth',1.4);
        hold(timingAxes,'on');
        receivedSequence = current.sequence(current.receivedMask);
        receivedArrivalTimeMs = current.arrivalTimeMs(current.receivedMask);
        plot(timingAxes,receivedSequence,receivedArrivalTimeMs, ...
            's--','LineWidth',1.4);
        plot(timingAxes,current.sequence,current.deliveryTimeBySequenceMs, ...
            'd-','LineWidth',1.4);
        hold(timingAxes,'off'); grid(timingAxes,'on');
        xlabel(timingAxes,'Message sequence number (integer)');
        ylabel(timingAxes,'Time from batch start (ms)');
        title(timingAxes,'Emission, raw arrival, and receiver delivery');
        legend(timingAxes,{'Sender emission','Network arrival', ...
            'Receiver delivery'},'Location','best');

        cla(orderAxes);
        arrivalRank = 1:current.receivedMessageCount;
        deliveryRank = 1:current.deliveredMessageCount;
        plot(orderAxes,arrivalRank,current.arrivalSequence,'o--', ...
            'LineWidth',1.4);
        hold(orderAxes,'on');
        plot(orderAxes,deliveryRank,current.deliverySequence,'s-', ...
            'LineWidth',1.4);
        hold(orderAxes,'off'); grid(orderAxes,'on');
        xlabel(orderAxes,'Event rank (integer)');
        ylabel(orderAxes,'Message sequence / state version (integer)');
        title(orderAxes,'Raw arrival order versus applied state order');
        legend(orderAxes,{'Network arrival','Receiver delivery'}, ...
            'Location','best');

        if ~current.preserveSequenceOrder
            if current.completeOrderedDelivery
                outcomeText = 'raw arrival delivery, in order by chance';
            else
                outcomeText = sprintf( ...
                    'raw arrival delivery, final version %d', ...
                    current.finalStateVersion);
            end
        elseif current.completeOrderedDelivery
            outcomeText = sprintf('ordered complete at %.1f ms', ...
                current.completionTimeMs);
        elseif current.timedOut
            outcomeText = sprintf('GAP TIMEOUT at %.1f ms, expected %d', ...
                current.failureTimeMs,current.timeoutExpectedSequence);
        elseif current.bufferOverflow
            outcomeText = sprintf('BUFFER FULL at %.1f ms, rejected %d', ...
                current.failureTimeMs,current.rejectedSequence);
        else
            outcomeText = sprintf('ordered prefix stopped at version %d', ...
                current.finalStateVersion);
        end
        statusLabel.Text = sprintf([ ...
            '%s; arrival inversions: %d; delivered: %d/%d; ' ...
            'buffer high-water: %d messages; delivered holding: %.1f message-ms.'], ...
            outcomeText,current.arrivalInversionCount, ...
            current.deliveredMessageCount,current.messageCount, ...
            current.reorderBufferHighWaterCount, ...
            current.totalOrderingHoldMessageMs);
        drawnow limitrate;
    end

    function resetBaseline(~,~)
        delayControl.Value = baselineDelayScale;
        capacityControl.Value = baselineBufferCapacity;
        timeoutControl.Value = baselineGapTimeoutMs;
        availabilityControl.Value = baselineMessageThreeAvailable;
        policyControl.Value = baselinePreserveSequenceOrder;
        redraw([],[]);
    end
end
