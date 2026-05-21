classdef MockTransport < ITransport
    %MOCKTRANSPORT 虚拟设备通信类
    % 用于在无真机、无下位机时，模拟设备的在线注册、查询返回等行为进行联调
    
    properties(SetAccess=private)
        TimerObj
        TargetVoltage = 0
        CurrentVoltage = 0
        TargetCurrent = 0
        BoostSpeed = 1000
        IsBoosting = false
    end
    properties(SetAccess=public)
        DropPackets logical = false 
    end
    
    methods
        function obj = MockTransport()
        end
        
        function connect(obj, varargin)
            obj.IsConnected = true;
            disp("启动虚拟设备... 模拟连接成功！");
            
            % 启动一个定时器，模拟设备内部的状态更新
            obj.TimerObj = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.5, ...
                'TimerFcn', @obj.onTimerTick);
            start(obj.TimerObj);
            
            % 模拟设备连上电脑后，主动发送REGISTER信息注册
            regMsg = '{"DeviceType":30006,"DeviceNo":"HDZGFP28A0001","CdCode":"REGISTER","Body":{"Action":0,"HardwareVer":"HDZGFP28A_100_5","SoftwareVer":"V1.0.9"}}';
            % 延迟一秒钟后虚拟设备自发注册 (防止上位机监听没挂好)
            start(timer('ExecutionMode', 'singleShot', 'StartDelay', 1, 'TimerFcn', @(~,~) obj.mockReceive(regMsg)));
        end
        
        function disconnect(obj)
            if obj.IsConnected
                stop(obj.TimerObj);
                delete(obj.TimerObj);
                obj.IsConnected = false;
                disp("虚拟设备已断开。");
            end
        end
        
        function sendString(obj, strData)
            if obj.DropPackets
                disp("🔌 [模拟器]: 物理线缆已断开，报文丢弃...");
                return;
            end
            disp("-> [PC发出]: " + strData);
            
            % 解析UI下发的JSON并生成模拟硬件的回复
            try
                data = jsondecode(strData);
                if isfield(data, 'CdCode') && strcmp(data.CdCode, 'REGISTER')
                   % PC回复注册结果，虚拟设备不需返回额外报文
                elseif isfield(data, 'CmdCode')
                    cmd = data.CmdCode;
                    if strcmp(cmd, 'Boost')
                        action = data.Body.Action;
                        if strcmp(action, 'Boost')
                           % 处理升压指令请求
                           obj.TargetVoltage = data.Body.Voltage_V;
                           obj.TargetCurrent = data.Body.Current_mA;
                           obj.BoostSpeed = data.Body.BoostSpeed_Vs;
                           if obj.TargetVoltage > 0
                               obj.IsBoosting = true;
                               reply = '{"CmdCode":"Boost","Body":{"Result":"Boosting"}}';
                               obj.mockReceive(reply);
                           else
                               obj.IsBoosting = false;
                               reply = '{"CmdCode":"Boost","Body":{"Result":"Stop_ManualStop"}}';
                               obj.mockReceive(reply);
                           end
                        elseif strcmp(action, 'Query')
                           % 模拟处理UI周期性的状态查询
                           status = "BoostEnd";
                           if obj.IsBoosting
                               status = "Boosting";
                           end
                           
                           % 1. 使用结构体组织数据，避免任何手动拼接或转义字符错误
                           resp = struct();
                           resp.DeviceType = 50003;
                           resp.DeviceNo = "HVDC0001";
                           resp.CmdCode = "Boost";
                           
                           % 2. 严格按照协议，将电压和电流序列化为“字符串类型”
                           resp.Body.Status = status;
                           resp.Body.Voltage_V = sprintf("%.1f", obj.CurrentVoltage); % 转为带1位小数的字符串
                           resp.Body.Current_mA = sprintf("%.2f", obj.TargetCurrent); % 转为带2位小数的字符串
                           resp.Body.BoostSpeed_Vs = 1000;
                           resp.Body.WorkMode = "remote_ctrl";
                    
                           % 3. 一键转换为标准 JSON 字符串
                           reply = jsonencode(resp);
                           obj.mockReceive(reply);
                        end
                    elseif strcmp(cmd, 'AlarmMessage')
                        if strcmp(data.Body.Action, 'Clear')
                            reply = '{"CmdCode":"AlarmMessage","Body":{"Result":"Clear_OK"}}';
                            obj.mockReceive(reply);
                        end
                    end
                end
            catch ME
                warning('MockTransport:JsonParseFailed', '虚拟设备不识别该包(JSON解析失败): %s', ME.message);
            end
        end
    end
    
    methods(Access=private)
        function onTimerTick(obj, ~, ~)
            % 定时器模拟电压动态变化（真实设备物理过程的仿真）
            dt = obj.TimerObj.Period;
            stepVoltage = obj.BoostSpeed * dt;
            
            if obj.TargetVoltage > 0
               if obj.IsBoosting
                   if obj.CurrentVoltage < obj.TargetVoltage
                       obj.CurrentVoltage = obj.CurrentVoltage + stepVoltage; % 阶梯增长
                       if obj.CurrentVoltage >= obj.TargetVoltage
                           obj.CurrentVoltage = obj.TargetVoltage;
                           obj.IsBoosting = false; % 到位后转入恒压保持 (BoostEnd)
                       end
                   end
               else
                   % 已处于 BoostEnd 状态，只做恒压保持，此时设备不应该掉电泄放
               end
            else
               obj.IsBoosting = false;
               if obj.CurrentVoltage > 0
                   obj.CurrentVoltage = obj.CurrentVoltage - 500; % 停止升压后掉电泄放
                   if obj.CurrentVoltage < 0
                       obj.CurrentVoltage = 0;
                   end
               end
            end
        end
        
        function mockReceive(obj, strData)
            % 假装硬件将数据通过串口线发回来
            disp("<- [硬件回传]: " + strData);
            notify(obj, 'DataReceived', DataEvent(strData));
        end
    end
end