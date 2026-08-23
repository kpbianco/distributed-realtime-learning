function interactive
%INTERACTIVE Manipulate one P04 FIFO input at a time.

queueModel = @model;
messageCount = 12;
baselinePeriodMs = 4;
baselineServiceMs = 6;
baselineCapacity = 4;
baselineDeadlineMs = 20;

window = uifigure('Name','P04 - Queue latency','Position',[100 100 1120 700]);
layout = uigridlayout(window,[5 5]);
layout.RowHeight = {24,34,46,'1x','1x'};
layout.ColumnWidth = {'1x','1x','1x','1x','1x'};

periodLabel = uilabel(layout,'Text','Arrival period (ms)');
periodLabel.Layout.Row = 1; periodLabel.Layout.Column = 1;
serviceLabel = uilabel(layout,'Text','Service time (ms)');
serviceLabel.Layout.Row = 1; serviceLabel.Layout.Column = 2;
capacityLabel = uilabel(layout,'Text','Capacity incl. service (records)');
capacityLabel.Layout.Row = 1; capacityLabel.Layout.Column = 3;
deadlineLabel = uilabel(layout,'Text','Deadline (ms)');
deadlineLabel.Layout.Row = 1; deadlineLabel.Layout.Column = 4;
burstLabel = uilabel(layout,'Text','Arrival shape');
burstLabel.Layout.Row = 1; burstLabel.Layout.Column = 5;

periodControl = uispinner(layout,'Limits',[1 20],'Value',baselinePeriodMs, ...
    'Step',1,'RoundFractionalValues','on');
periodControl.Layout.Row = 2; periodControl.Layout.Column = 1;
serviceControl = uispinner(layout,'Limits',[1 20],'Value',baselineServiceMs, ...
    'Step',1,'RoundFractionalValues','on');
serviceControl.Layout.Row = 2; serviceControl.Layout.Column = 2;
capacityControl = uispinner(layout,'Limits',[1 messageCount],'Value',baselineCapacity, ...
    'Step',1,'RoundFractionalValues','on');
capacityControl.Layout.Row = 2; capacityControl.Layout.Column = 3;
deadlineControl = uispinner(layout,'Limits',[1 60],'Value',baselineDeadlineMs, ...
    'Step',1,'RoundFractionalValues','on');
deadlineControl.Layout.Row = 2; deadlineControl.Layout.Column = 4;
burstControl = uicheckbox(layout,'Text','P03 release burst (4)','Value',false);
burstControl.Layout.Row = 2; burstControl.Layout.Column = 5;

resetButton = uibutton(layout,'Text','Reset baseline', ...
    'ButtonPushedFcn',@resetBaseline);
resetButton.Layout.Row = 3; resetButton.Layout.Column = 1;
statusLabel = uilabel(layout,'Text','','WordWrap','on');
statusLabel.Layout.Row = 3; statusLabel.Layout.Column = [2 5];

occupancyAxes = uiaxes(layout);
occupancyAxes.Layout.Row = [4 5]; occupancyAxes.Layout.Column = [1 2];
latencyAxes = uiaxes(layout);
latencyAxes.Layout.Row = [4 5]; latencyAxes.Layout.Column = [3 5];

periodControl.ValueChangedFcn = @redraw;
serviceControl.ValueChangedFcn = @redraw;
capacityControl.ValueChangedFcn = @redraw;
deadlineControl.ValueChangedFcn = @redraw;
burstControl.ValueChangedFcn = @redraw;
redraw([],[]);

    function redraw(~,~)
        if burstControl.Value
            releaseBatchMessages = 4;
        else
            releaseBatchMessages = 1;
        end
        current = queueModel(messageCount,periodControl.Value,serviceControl.Value, ...
            capacityControl.Value,deadlineControl.Value,releaseBatchMessages);

        cla(occupancyAxes);
        stairs(occupancyAxes,current.recordIndex, ...
            current.systemOccupancyAfterArrivalCount,'o-','LineWidth',1.4, ...
            'DisplayName','Unfinished after arrival');
        hold(occupancyAxes,'on');
        yline(occupancyAxes,current.capacityMessages,'k--','LineWidth',1.2, ...
            'DisplayName','Capacity');
        scatter(occupancyAxes,current.recordIndex(current.droppedMask), ...
            current.systemOccupancyAfterArrivalCount(current.droppedMask),90,'x', ...
            'LineWidth',1.8,'DisplayName','Tail drop');
        hold(occupancyAxes,'off');
        grid(occupancyAxes,'on');
        xlabel(occupancyAxes,'Application record index');
        ylabel(occupancyAxes,'Unfinished records (count)');
        title(occupancyAxes,'Finite FIFO occupancy');
        legend(occupancyAxes,'Location','best');

        cla(latencyAxes);
        plot(latencyAxes,current.recordIndex,current.waitingTimeMs,'o-', ...
            'LineWidth',1.4,'DisplayName','FIFO waiting');
        hold(latencyAxes,'on');
        plot(latencyAxes,current.recordIndex,current.systemLatencyMs,'s-', ...
            'LineWidth',1.4,'DisplayName','System latency');
        yline(latencyAxes,current.deadlineMs,'k--','LineWidth',1.2, ...
            'DisplayName','Deadline');
        scatter(latencyAxes,current.recordIndex(current.droppedMask), ...
            current.deadlineMs * ones(current.droppedCount,1),90,'x', ...
            'LineWidth',1.8,'DisplayName','Dropped: latency undefined');
        hold(latencyAxes,'off');
        grid(latencyAxes,'on');
        xlabel(latencyAxes,'Application record index');
        ylabel(latencyAxes,'Time (ms)');
        title(latencyAxes,'Waiting and arrival-to-departure latency');
        legend(latencyAxes,'Location','best');

        statusLabel.Text = sprintf([ ...
            'Utilization %.2f (%s); accepted %d/%d, on time %d, late %d, ' ...
            'dropped %d; max latency %.0f ms. %s'], ...
            current.nominalUtilization,current.nominalLoadState,current.acceptedCount, ...
            current.messageCount,current.onTimeCount,current.lateCount, ...
            current.droppedCount,current.maxSystemLatencyMs,current.queueState);
        drawnow limitrate;
    end

    function resetBaseline(~,~)
        periodControl.Value = baselinePeriodMs;
        serviceControl.Value = baselineServiceMs;
        capacityControl.Value = baselineCapacity;
        deadlineControl.Value = baselineDeadlineMs;
        burstControl.Value = false;
        redraw([],[]);
    end
end
