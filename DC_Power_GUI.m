function app = DC_Power_GUI(controller)
% DC_POWER_GUI 高压直流电源上位机纯代码主界面
% 运行此函数即可启动上位机UI。

    if nargin < 1
        controller = [];
    end

    % 创建结构体用于存储所有 UI 句柄
    app = struct();
    app.Controller = controller;
    
    %% ================= 1. 主窗口设置 =================
    app.UIFigure = uifigure('Name', '高压直流电源', ...
                            'Position', [100, 100, 1200, 800], ...
                            'Color', '#F2F4F7');
    % 存储初始默认的保护参数和跨回调共享的数据（避免按值传递丢失）
    app.UIFigure.UserData = struct('OV_kV', 75, 'OC_mA', 6.5, 'MaxC_mA', 5.0, ...
                                   'StartTime', datetime('now'), ...
                                   'TimerHandle', [], ...
                                   'LastStatus', "", ...
                                   'LogData', []);

                        
    % 主布局：4行1列
    app.MainGrid = uigridlayout(app.UIFigure, [4, 1]);
    app.MainGrid.RowHeight = {60, '1x', 150, 100};
    app.MainGrid.ColumnWidth = {'1x'};
    app.MainGrid.Padding = [0 0 0 0];
    app.MainGrid.RowSpacing = 5;

    %% ================= 2. 顶部导航栏 (第一行) =================
    app.TopPanel = uipanel(app.MainGrid, 'BackgroundColor', '#4169E1', 'BorderType', 'none');
    
    app.TopGrid = uigridlayout(app.TopPanel, [1, 3]);
    app.TopGrid.ColumnWidth = {300, '1x', 300};
    app.TopGrid.RowHeight = {'1x'};
    app.TopGrid.Padding = [10 5 10 5];
    
    % 左侧按钮区
    app.NavBtnGrid = uigridlayout(app.TopGrid, [1, 3]);
    app.NavBtnGrid.Padding = [0 0 0 0];
    app.BtnMonitor = uibutton(app.NavBtnGrid, 'Text', '设备监控', 'FontColor', 'w', 'BackgroundColor', '#4169E1', 'FontWeight', 'bold');
    app.BtnData = uibutton(app.NavBtnGrid, 'Text', '数据浏览', 'FontColor', '#D3D3D3', 'BackgroundColor', '#4169E1');
    app.BtnSetting = uibutton(app.NavBtnGrid, 'Text', '参数设置', 'FontColor', '#D3D3D3', 'BackgroundColor', '#4169E1');

    % 中间标题
    uilabel(app.TopGrid, 'Text', '高压直流电源', 'FontColor', 'b', 'FontSize', 24, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    
    % 右侧状态与退出按钮
    app.StatusGrid = uigridlayout(app.TopGrid, [1, 3]);
    app.StatusGrid.Padding = [0 0 0 0];
    app.StatusGrid.ColumnWidth = {'1x', '1x', 80};
    
    app.LblMode = uilabel(app.StatusGrid, 'Text', '手动控制', 'FontColor', 'b', 'HorizontalAlignment', 'right');
    app.LblConnect = uilabel(app.StatusGrid, 'Text', '未连接', 'FontColor', '#FF6347', 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
    app.BtnExit = uibutton(app.StatusGrid, 'Text', '退出', 'BackgroundColor', '#DC143C', 'FontColor', 'w', 'FontWeight', 'bold');
    
    %% ================= 3. 主体数据区 (第二行) =================
    app.DataGrid = uigridlayout(app.MainGrid, [1, 2]);
    app.DataGrid.ColumnWidth = {'3x', '1x'}; % 左侧 75%, 右侧 25%
    app.DataGrid.Padding = [20 10 20 10];
    app.DataGrid.ColumnSpacing = 20;
    
    % --- 左侧 波形图区 ---
    app.WavePanel = uipanel(app.DataGrid, 'BackgroundColor', 'w', 'BorderType', 'none', 'Title', '实时波形监控');
    app.WaveGrid = uigridlayout(app.WavePanel, [1, 1]);
    app.UIAxes = uiaxes(app.WaveGrid);
    grid(app.UIAxes, 'on');
    app.UIAxes.XLabel.String = '时间';
    
    % 双 Y 轴配置
    yyaxis(app.UIAxes, 'left');
    app.UIAxes.YColor = 'r';
    app.UIAxes.YLabel.String = '电压 (kV)';
    app.UIAxes.YLim = [0 70];
    app.LineVol = animatedline(app.UIAxes, 'Color', 'r', 'LineWidth', 1.5, 'MaximumNumPoints', 1200);
    
    yyaxis(app.UIAxes, 'right');
    app.UIAxes.YColor = '#00008B'; % 深蓝色
    app.UIAxes.YLabel.String = '电流 (mA)';
    app.UIAxes.YLim = [0 6];
    app.LineCur = animatedline(app.UIAxes, 'Color', '#00008B', 'LineWidth', 1.5, 'MaximumNumPoints', 1200);
    
    % --- 右侧 仪表盘区 ---
    app.GaugeGrid = uigridlayout(app.DataGrid, [2, 1]);
    app.GaugeGrid.Padding = [0 0 0 0];
    app.GaugeGrid.RowSpacing = 20;
    
    % 上面板：CV 恒压
    app.VolPanel = uipanel(app.GaugeGrid, 'BackgroundColor', 'w', 'Title', '输出电压 (kV)', 'BorderType', 'none');
    app.VolGrid = uigridlayout(app.VolPanel, [2, 1]);
    app.VolGrid.RowHeight = {'3x', '1x'};
    
    app.GaugeVol = uigauge(app.VolGrid, 'semicircular', 'Limits', [0 70], 'ScaleColors', {'y','r'}, 'ScaleColorLimits', [50 70]);
    app.LblVolVal = uilabel(app.VolGrid, 'Text', '0.00', 'FontSize', 36, 'FontColor', 'r', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    
    % 下面板：CC 恒流
    app.CurPanel = uipanel(app.GaugeGrid, 'BackgroundColor', 'w', 'Title', '输出电流 (mA)', 'BorderType', 'none');
    app.CurGrid = uigridlayout(app.CurPanel, [2, 1]);
    app.CurGrid.RowHeight = {'3x', '1x'};
    
    app.GaugeCur = uigauge(app.CurGrid, 'semicircular', 'Limits', [0 6], 'ScaleColors', {'y','r'}, 'ScaleColorLimits', [4 6]);
    app.LblCurVal = uilabel(app.CurGrid, 'Text', '0.00', 'FontSize', 36, 'FontColor', '#00008B', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

    %% ================= 4. 底部控制区 (第三行) =================
    app.CtrlPanel = uipanel(app.MainGrid, 'BackgroundColor', 'w', 'BorderType', 'none');
    app.CtrlGrid = uigridlayout(app.CtrlPanel, [1, 5]);
    app.CtrlGrid.ColumnWidth = {'1x', '1x', '1x', '1.5x', '1x'};
    app.CtrlGrid.Padding = [20 20 20 20];
    app.CtrlGrid.ColumnSpacing = 30;
    
    % 区块 1：模式控制 (ButtonGroup)
    app.BgMode = uibuttongroup(app.CtrlGrid, 'Title', '工作模式', 'BackgroundColor', 'w', 'BorderType', 'line');
    app.RbManual = uiradiobutton(app.BgMode, 'Text', '手动控制', 'Position', [10 50 100 22]);
    app.RbWithstand = uiradiobutton(app.BgMode, 'Text', '耐压控制', 'Position', [10 25 100 22]);
    
    % 区块 2：电压设置
    app.SetVolGrid = uigridlayout(app.CtrlGrid, [2, 1], 'Padding', [0 0 0 0]);
    uilabel(app.SetVolGrid, 'Text', '目标电压 (kV)', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    app.EditTargetVol = uieditfield(app.SetVolGrid, 'numeric', 'Value', 0, 'FontSize', 24, 'HorizontalAlignment', 'center');
    
    % 区块 3：变化率设置
    app.SetRateGrid = uigridlayout(app.CtrlGrid, [2, 1], 'Padding', [0 0 0 0]);
    uilabel(app.SetRateGrid, 'Text', '变化率 (kV/s)', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    app.EditRate = uieditfield(app.SetRateGrid, 'numeric', 'Value', 20, 'FontSize', 24, 'HorizontalAlignment', 'center');
    
    % 区块 4：耐压时长设置
    app.DurGrid = uigridlayout(app.CtrlGrid, [2, 1], 'Padding', [0 0 0 0]);
    uilabel(app.DurGrid, 'Text', '耐压时长 (s)', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    app.EditDuration = uieditfield(app.DurGrid, 'numeric', 'Value', 60, 'FontSize', 24, 'HorizontalAlignment', 'center');
    
    % 区块 5：操作按钮
    app.BtnStart = uibutton(app.CtrlGrid, 'Text', '启 动', 'FontSize', 24, 'FontWeight', 'bold', 'BackgroundColor', '#32CD32', 'FontColor', 'w');

    %% ================= 4.5 数据浏览区 (与2,3行重叠) =================
    app.HistoryGrid = uigridlayout(app.MainGrid, [2, 1]);
    app.HistoryGrid.Layout.Row = [2, 3];
    app.HistoryGrid.Layout.Column = 1;
    app.HistoryGrid.RowHeight = {'1x', 60};
    app.HistoryGrid.Visible = 'off';

    % 主体视图面板
    app.HistViewPanel = uipanel(app.HistoryGrid, 'BackgroundColor', 'w', 'BorderType', 'none');
    pGrid = uigridlayout(app.HistViewPanel, [1, 1]);
    
    app.LblHistPlaceholder = uilabel(pGrid, 'Text', '请选择数据文件查看预览', ...
        'FontSize', 20, 'FontColor', '#808080', 'HorizontalAlignment', 'center');
    
    app.HistAxes = uiaxes(pGrid);
    app.HistAxes.Visible = 'off';
    grid(app.HistAxes, 'on');
    app.HistAxes.XLabel.String = '时间 (s)';
    yyaxis(app.HistAxes, 'left');
    app.HistAxes.YColor = 'r';
    app.HistAxes.YLabel.String = '电压 (kV)';
    yyaxis(app.HistAxes, 'right');
    app.HistAxes.YColor = '#00008B';
    app.HistAxes.YLabel.String = '电流 (mA)';

    % 底部控制面板
    app.HistCtrlGrid = uigridlayout(app.HistoryGrid, [1, 2]);
    app.HistCtrlGrid.ColumnWidth = {'1x', 300};
    app.HistCtrlGrid.Padding = [10 0 10 0];
    
    app.HistTimeGrid = uigridlayout(app.HistCtrlGrid, [2, 1]);
    app.HistTimeGrid.Padding = [0 0 0 0];
    app.LblHistStartTime = uilabel(app.HistTimeGrid, 'Text', '开始时间: --', 'FontColor', '#0000EE');
    app.LblHistEndTime = uilabel(app.HistTimeGrid, 'Text', '结束时间: --', 'FontColor', '#0000EE');
    
    app.HistBtnGrid = uigridlayout(app.HistCtrlGrid, [1, 3]);
    app.HistBtnGrid.Padding = [0 0 0 0];
    app.BtnHistLoad = uibutton(app.HistBtnGrid, 'Text', '加载数据');
    app.BtnHistClear = uibutton(app.HistBtnGrid, 'Text', '数据清理');
    app.BtnHistExport = uibutton(app.HistBtnGrid, 'Text', '导出Excel');

    %% ================= 5. 绑定所有完整对象的事件回调 =================
    
    app.BtnMonitor.ButtonPushedFcn = @(~, ~) cbSwitchTab(app, 'Monitor');
    app.BtnData.ButtonPushedFcn = @(~, ~) cbSwitchTab(app, 'History');
    app.BtnSetting.ButtonPushedFcn = @(~, ~) openParamDialog(app);
    app.BtnStart.ButtonPushedFcn = @(~, ~) cbStartPushed(app);
    app.BtnHistLoad.ButtonPushedFcn = @(~,~) cbHistLoad(app);
    app.BtnHistClear.ButtonPushedFcn = @(~,~) cbHistClear(app);
    app.BtnHistExport.ButtonPushedFcn = @(~,~) cbHistExport(app);

    % 附加：退出按钮与窗口关闭事件
    app.BtnExit.ButtonPushedFcn = @(~,~) cbAppClose(app);
    app.UIFigure.CloseRequestFcn = @(~,~) cbAppClose(app);
    
    app.EditDuration.Enable = 'off';
    app.BgMode.SelectionChangedFcn = @(~, event) cbModeChanged(app, event);
    
    app.LogArea = uitextarea(app.MainGrid, 'Editable', 'off');
    
    %% ================= 6. 控制器事件联调监听 =================
    if ~isempty(app.Controller)
        addlistener(app.Controller, 'StatusUpdated', @(~, evt) cbStatusUpdated(app, evt));
        addlistener(app.Controller, 'RegisterReceived', @(~, evt) cbRegisterReceived(app, evt));
        addlistener(app.Controller, 'AlarmReceived', @(~, evt) cbAlarmReceived(app, evt));
        addlistener(app.Controller, 'ResultReceived', @(~, evt) cbResultReceived(app, evt));
    end
    
end

%% ================= 隐藏面板/弹窗逻辑：参数设置 =================
function openParamDialog(app)
    % 仅允许打开一个参数弹窗（如果存在则置顶前排）
    persistent paramFig
    if ~isempty(paramFig) && isvalid(paramFig)
        figure(paramFig);
        return;
    end
    
    config = app.UIFigure.UserData;
    
    paramFig = uifigure('Name', '参数设置保护', 'Position', [400 300 400 300], 'WindowStyle', 'modal');
    
    pGrid = uigridlayout(paramFig, [4, 2]);
    pGrid.ColumnWidth = {'1x', '1x'};
    
    uilabel(pGrid, 'Text', '过压保护 (kV):', 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
    editPmtOV = uieditfield(pGrid, 'numeric', 'Value', config.OV_kV);
    
    uilabel(pGrid, 'Text', '过流保护 (mA):', 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
    editPmtOC = uieditfield(pGrid, 'numeric', 'Value', config.OC_mA);
    
    uilabel(pGrid, 'Text', '最大电流 (mA):', 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
    editPmtMaxC = uieditfield(pGrid, 'numeric', 'Value', config.MaxC_mA);
    
    btnGrid = uigridlayout(pGrid, [1, 2], 'Padding', [0 0 0 0]);
    pGrid.RowHeight = {40, 40, 40, 60};
    
    btnSave = uibutton(btnGrid, 'Text', '保存并应用', 'BackgroundColor', '#4169E1', 'FontColor', 'w');
    btnCancel = uibutton(btnGrid, 'Text', '取消');
    
    % 弹窗回调绑定
    btnCancel.ButtonPushedFcn = @(~,~) delete(paramFig);
    btnSave.ButtonPushedFcn = @(~,~) cbParamSaved(paramFig, app, editPmtOV.Value, editPmtOC.Value, editPmtMaxC.Value);
end

%% ================= 回调函数存放区 =================

function logMsg(app, msg)
    if isvalid(app.UIFigure)
        newMsg = sprintf('[%s] %s', datestr(now, 'HH:MM:SS'), msg);
        app.LogArea.Value = [app.LogArea.Value; {newMsg}];
        scroll(app.LogArea, 'bottom');
    end
end

function cbSwitchTab(app, tabName)
    if strcmp(tabName, 'Monitor')
        app.BtnMonitor.FontWeight = 'bold';
        app.BtnMonitor.FontColor = 'w';
        app.BtnData.FontWeight = 'normal';
        app.BtnData.FontColor = '#D3D3D3';
        
        app.HistoryGrid.Visible = 'off';
        app.DataGrid.Visible = 'on';
        app.CtrlPanel.Visible = 'on';
    else
        app.BtnData.FontWeight = 'bold';
        app.BtnData.FontColor = 'w';
        app.BtnMonitor.FontWeight = 'normal';
        app.BtnMonitor.FontColor = '#D3D3D3';
        
        app.DataGrid.Visible = 'off';
        app.CtrlPanel.Visible = 'off';
        app.HistoryGrid.Visible = 'on';
    end
end

function cbHistLoad(app)
    % 浏览并加载本地 mat 数据
    [file, path] = uigetfile({'*.mat', 'MATLAB 数据文件 (*.mat)'}, '选择历史数据', 'Data/');
    if isequal(file, 0)
        return;
    end
    
    fullpath = fullfile(path, file);
    try
        data = load(fullpath);
        % 校验存在性
        fields = fieldnames(data);
        if isempty(fields)
            uialert(app.UIFigure, "加载的文件为空！", "错误", 'Icon', 'error');
            return;
        end
        T = data.(fields{1}); % 我们存的 timetable
        
        if ~istimetable(T)
            uialert(app.UIFigure, "数据格式不兼容！请选择当前软件生成的历史文件。", "格式错误", 'Icon', 'error');
            return;
        end
        
        % 隐藏提示词
        app.LblHistPlaceholder.Visible = 'off';
        % 展示并绘制图表
        app.HistAxes.Visible = 'on';
        cla(app.HistAxes);
        
        t_sec = seconds(T.Time - T.Time(1)); % 重算0秒相对时间
        
        yyaxis(app.HistAxes, 'left');
        plot(app.HistAxes, t_sec, T.Voltage_kV, 'r-', 'LineWidth', 1.5);
        app.HistAxes.YLim = [0 max(70, max(T.Voltage_kV)*1.2+1)];
        
        yyaxis(app.HistAxes, 'right');
        plot(app.HistAxes, t_sec, T.Current_mA, 'b-', 'LineWidth', 1.5);
        app.HistAxes.YColor = '#00008B';
        app.HistAxes.YLim = [0 max(6, max(T.Current_mA)*1.2+0.1)];
        
        % 更新底部时间
        app.LblHistStartTime.Text = "开始时间: " + datestr(T.Time(1), 'yyyy/mm/dd HH:MM:SS');
        app.LblHistEndTime.Text = "结束时间: " + datestr(T.Time(end), 'yyyy/mm/dd HH:MM:SS');
        
        % 将表暂存供导出分享
        app.UIFigure.UserData.LoadedHist = T;
        
    catch ME
        uialert(app.UIFigure, "读取数据出错: " + ME.message, "错误", 'Icon', 'error');
    end
end

function cbHistClear(app)
    % 清理历史数据视图
    cla(app.HistAxes);
    app.HistAxes.Visible = 'off';
    app.LblHistPlaceholder.Visible = 'on';
    app.LblHistStartTime.Text = "开始时间: --";
    app.LblHistEndTime.Text = "结束时间: --";
    if isfield(app.UIFigure.UserData, 'LoadedHist')
        app.UIFigure.UserData.LoadedHist = [];
    end
end

function cbHistExport(app)
    % 导出为 Excel
    config = app.UIFigure.UserData;
    if ~isfield(config, 'LoadedHist') || isempty(config.LoadedHist)
        uialert(app.UIFigure, "还未加载任何历史数据，无法导出！", "提示", 'Icon', 'warning');
        return;
    end
    
    [file, path] = uiputfile({'*.xlsx', 'Excel 工作簿 (*.xlsx)'}, '导出历史数据');
    if isequal(file, 0)
        return;
    end
    
    fullpath = fullfile(path, file);
    try
        writetable(config.LoadedHist, fullpath);
        uialert(app.UIFigure, "成功导出至: " + fullpath, "导出成功", 'Icon', 'success');
    catch ME
        uialert(app.UIFigure, "导出失败: " + ME.message, "导出错误", 'Icon', 'error');
    end
end

function cbModeChanged(app, event)
    if strcmp(event.NewValue.Text, '耐压控制')
        app.EditDuration.Enable = 'on';
    else
        app.EditDuration.Enable = 'off';
    end
end

function cbAppClose(app)
    disp(">>> [GUI]: 准备退出，正在清理资源...");
    if isvalid(app.UIFigure)
        config = app.UIFigure.UserData;
        if isfield(config, 'TimerHandle') && ~isempty(config.TimerHandle) && isvalid(config.TimerHandle)
            stop(config.TimerHandle);
            delete(config.TimerHandle);
        end
    end
    if ~isempty(app.Controller)
        app.Controller.disconnect(); % 停止定时器并关闭串口
    end
    delete(app.UIFigure); % 最后销毁界面
end

function saveHistoricalData(app)
    if isvalid(app.UIFigure)
        % 【修改点】：动态获取最新的 UserData，不要用老句柄覆盖
        config = app.UIFigure.UserData;
        
        if isfield(config, 'LogData') && ~isempty(config.LogData) && ~isempty(config.LogData.Time)
            fprintf(">>> [Debug Save]: 当前缓存中有 %d 条数据记录。\n", length(config.LogData.Time));
            
            % 提取局部变量进行耗时的序列化，不影响 UI 句柄
            logDataCopy = config.LogData;
            
            % 只要有数据就执行保存
            if ~isempty(logDataCopy.Time)
                if ~exist('Data', 'dir')
                    mkdir('Data');
                end
                
                T = timetable(logDataCopy.Timestamps(:), ...
                              logDataCopy.Vol(:), ...
                              logDataCopy.Cur(:), ...
                              'VariableNames', {'Voltage_kV', 'Current_mA'});
                              
                filename = fullfile('Data', sprintf('TestLog_%s.mat', datestr(now, 'yyyymmdd_HHMMSS')));
                save(filename, 'T');
                logMsg(app, "💾 测试数据已自动归档至: " + filename);
                
                % 【关键修改】：只清空缓存，必须重新 get 一下防止磁盘写入期间有新数据进来
                latestConfig = app.UIFigure.UserData;
                latestConfig.LogData = []; 
                app.UIFigure.UserData = latestConfig;
            end
        else
            fprintf(">>> [Debug Save]: 警告！LogData 为空，无需保存。\n");
        end
    end
end

function cbStartPushed(app)
    % [回调] 点击 启动 / 停止 按钮时触发
    
    % 1. 立刻禁用按钮，防止用户在卡顿期间连续狂点导致重复触发
    app.BtnStart.Enable = 'off';
    drawnow; % 立刻刷新按钮的禁用状态
    
    currentState = app.BtnStart.Text;
    if strcmp(currentState, '启 动')
        config = app.UIFigure.UserData;
        config.StartTime = datetime('now'); % 重置时间零点为当前点击时间
        config.LogData = struct('Time', double.empty(0,1), 'Vol', double.empty(0,1), 'Cur', double.empty(0,1), 'Timestamps', datetime.empty(0, 1)); 
        app.UIFigure.UserData = config; % 写回
        
        clearpoints(app.LineVol);        % 清空旧的电压波形
        clearpoints(app.LineCur);        % 清空旧的电流波形

        % 读取 UI 给定的目标电压(kV) 转换为 (V)
        targetVol_V = app.EditTargetVol.Value * 1000;
        rate_Vs = app.EditRate.Value * 1000;
        
        % 检查工作模式并配置耐压控制定时器
        modeStr = app.BgMode.SelectedObject.Text;
        if strcmp(modeStr, '耐压控制')
            duration_s = app.EditDuration.Value;
            if duration_s > 0
                if ~isempty(config.TimerHandle) && isvalid(config.TimerHandle)
                    stop(config.TimerHandle);
                    delete(config.TimerHandle);
                end
                
                config.TimerHandle = timer('ExecutionMode', 'singleShot', ...
                                           'StartDelay', duration_s, ...
                                           'TimerFcn', @(~,~) cbWithstandTimeout(app));
                app.UIFigure.UserData = config; % 写回
                start(config.TimerHandle);
                disp(">>> [GUI请求]: 启动耐压模式, 已设置 " + duration_s + " 秒后自动停机。");
            end
        end
        
        maxC_mA = config.MaxC_mA;
        
        disp(">>> [GUI请求]: 尝试下发升压指令...");
        if ~isempty(app.Controller)
            app.Controller.startBoost(targetVol_V, maxC_mA, rate_Vs);
        end
        
        % 变更 UI 状态为 终止
        app.BtnStart.Text = '终 止';
        app.BtnStart.BackgroundColor = '#DC143C'; % 变红警告
        app.BtnStart.Enable = 'on'; % 重新启用按钮供用户终止
        drawnow; % 强刷新界面

    else
        disp(">>> [GUI请求]: 用户手动终止，执行安全停机...");
        safeStopAndCleanup(app);
    end
end    

function cbWithstandTimeout(app)
    disp(">>> [GUI]: 耐压时间到，自动触发停机操作！");
    if isvalid(app.UIFigure)
        % 模拟点击终止动作
        if strcmp(app.BtnStart.Text, '终 止')
            cbStartPushed(app);
            uialert(app.UIFigure, "耐压时长已达到，已自动停机，数据已保存。", "耐压完成", 'Icon', 'info');
        end
    end
end

function cbParamSaved(paramFig, app, ov_kv, oc_ma, maxc_ma)
    % [回调] 点击参数面板保存时触发
    disp(">>> [GUI请求]: 参数已更新并保存：过压=" + ov_kv + "kV | 过流=" + oc_ma + "mA | 目标上限=" + maxc_ma + "mA");
    
    % 保存回 UserData
    if isvalid(app.UIFigure)
        config = app.UIFigure.UserData;
        config.OV_kV = ov_kv;
        config.OC_mA = oc_ma;
        config.MaxC_mA = maxc_ma;
        app.UIFigure.UserData = config;
    end
    
    % 保存后销毁弹窗
    delete(paramFig);
end

function cbResultReceived(app, evt)
    if isvalid(app.UIFigure)
        if isfield(evt.Payload, 'Result')
            logMsg(app, "⚙️ 设备指令回执: " + string(evt.Payload.Result));
        end
    end
end

function cbStatusUpdated(app, evt)
    if ~isvalid(app.UIFigure)
        return;
    end
    
    try
        vol_V = double(string(evt.Payload.Voltage_V));
        cur_mA = double(string(evt.Payload.Current_mA));
    catch
        vol_V = 0;
        cur_mA = 0;
    end
    
    vol_kV = vol_V / 1000;
    
    % 【核心修复 1】：每次都直接从最新的句柄中获取
    config = app.UIFigure.UserData;
    t_sec = seconds(datetime('now') - config.StartTime);
    
    % 【核心修复 2】：确保结构体和字段存在，采用直接赋值防丢
    if ~isfield(config, 'LogData') || isempty(config.LogData)
        config.LogData = struct('Time', [], 'Vol', [], 'Cur', [], 'Timestamps', datetime.empty(0, 1));
    end
    
    % 数据追加
    config.LogData.Time(end+1) = t_sec;
    config.LogData.Vol(end+1) = vol_kV;
    config.LogData.Cur(end+1) = cur_mA;
    config.LogData.Timestamps(end+1) = datetime('now');
    
    % 【核心修复 3】：关键！数据一变，立刻存回 UIFigure，防止被其他回调抢先读取空数据
    app.UIFigure.UserData = config;
    
    % 更新波形图
    addpoints(app.LineVol, t_sec, vol_kV);
    addpoints(app.LineCur, t_sec, cur_mA);
    drawnow limitrate;
    
    % 更新仪表盘
    app.GaugeVol.Value = max(app.GaugeVol.Limits(1), min(vol_kV, app.GaugeVol.Limits(2)));
    app.LblVolVal.Text = sprintf('%.2f', vol_kV);
    
    app.GaugeCur.Value = max(app.GaugeCur.Limits(1), min(cur_mA, app.GaugeCur.Limits(2)));
    app.LblCurVal.Text = sprintf('%.2f', cur_mA);
    
    % 设备状态变更记录
    if isfield(evt.Payload, 'Status')
        statusStr = string(evt.Payload.Status);
        if ~strcmp(config.LastStatus, statusStr)
            logMsg(app, "🔄 设备状态: " + statusStr);
            config.LastStatus = statusStr;
            app.UIFigure.UserData = config; % 变更后写回
        end
    end
    
    % 软件过压/过流保护
    if vol_kV > config.OV_kV || cur_mA > config.OC_mA
        if strcmp(app.BtnStart.Text, '终 止')
            warnMsg = sprintf('⚠️ 触发软件保护! 当前 %.2fkV, %.2fmA (限制: OV=%.1fkV, OC=%.1fmA)', ...
                vol_kV, cur_mA, config.OV_kV, config.OC_mA);
            logMsg(app, warnMsg);
            
            % 使用统一函数安全停机并清理资源
            safeStopAndCleanup(app);
            
            uialert(app.UIFigure, warnMsg, "软件保护触发", 'Icon', 'error');
        end
    end
end

function cbRegisterReceived(app, evt)
    if isvalid(app.UIFigure)
        app.LblConnect.Text = '已连接';
        app.LblConnect.FontColor = '#32CD32'; % 绿色
    end
end

function cbAlarmReceived(app, evt)
    if isvalid(app.UIFigure)
        if strcmp(app.BtnStart.Text, '终 止')
             saveHistoricalData(app);
        end
        uialert(app.UIFigure, "收到硬件告警！设备可能已急停。数据已自动封档。", "硬件告警", 'Icon', 'warning');
        % 恢复按钮状态为启动
        app.BtnStart.Text = '启 动';
        app.BtnStart.BackgroundColor = '#32CD32'; 
        app.BtnStart.Enable = 'on';
        
        errFields = fieldnames(evt.Payload);
        for i = 1:length(errFields)
            val = evt.Payload.(errFields{i});
            if ischar(val) || isstring(val)
                if strcmp(val, 'Alarm')
                    logMsg(app, "❌ 收到异常: " + string(errFields{i}));
                end
            end
        end
    end
end
function safeStopAndCleanup(app)
    % 1. 向下位机下发停止指令
    if ~isempty(app.Controller)
        try
            app.Controller.stopBoost();
        catch ME
            warning(">>> [GUI 警告]: 下发停止指令失败: %s", ME.message);
        end
    end

    if isvalid(app.UIFigure)
        config = app.UIFigure.UserData;
        
        % 2. 清理耐压模式定时器
        if isfield(config, 'TimerHandle') && ~isempty(config.TimerHandle) && isvalid(config.TimerHandle)
            if strcmp(config.TimerHandle.Running, 'on')
                stop(config.TimerHandle);
            end
            delete(config.TimerHandle);
            config.TimerHandle = [];
            app.UIFigure.UserData = config;
            disp(">>> [GUI]: 耐压模式定时器已安全销毁。");
        end
        
        % 3. 安全保存历史数据
        try
            saveHistoricalData(app); 
        catch ME
            warning(">>> [GUI 警告]: 自动保存历史数据失败: %s", ME.message);
        end
        
        % 4. 统一恢复按钮及 UI 状态
        app.BtnStart.Text = '启 动';
        app.BtnStart.BackgroundColor = '#32CD32'; % 恢复绿色
        app.BtnStart.Enable = 'on';
        drawnow;
    end
end