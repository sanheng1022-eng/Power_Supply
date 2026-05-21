classdef DeviceController < handle
    %DEVICECONTROLLER 高压直流发生器控制及协议层
    % 解析《高压直流电源命令集.pdf》中的 JSON 格式协议命令，不包含 UI 相关逻辑。
    
    events
        StatusUpdated    % 生命周期查询，包含电压电流等参数 (Payload 为 struct)
        AlarmReceived    % 收到硬件发来的报警信号 (Payload 为 struct)
        RegisterReceived % 设备初次上线连接确认 (Payload 为 struct)
        ResultReceived   % 指令操作的回执 (Payload 为 struct)
    end
    
    properties
        Transport % 依赖注入的传输对象(可以是 SerialTransport 或者 MockTransport)
        TimerObj  % 周期查询状态的定时器 (用于每隔一段时间触发 Query 指令)
        LastResponseTime % 最后一次收到响应的时间
    end
    
    methods
        function obj = DeviceController(transportObj)
            obj.Transport = transportObj;
            obj.LastResponseTime = datetime('now');
            
            % 将底层传来的 String 进行监听，交给当前控制器的 onDataReceived 处理
            addlistener(obj.Transport, 'DataReceived', @obj.onDataReceived);
            
            % 创建查询定时器，每 250ms 查询一次硬件实时数据
            obj.TimerObj = timer('ExecutionMode', 'fixedRate', ...
                'Period', 0.25, ...
                'TimerFcn', @(~,~) obj.queryStatus());
        end
        
        function delete(obj)
            if ~isempty(obj.TimerObj) && isvalid(obj.TimerObj)
                stop(obj.TimerObj);
                delete(obj.TimerObj);
            end
        end
        
        function connect(obj, varargin)
            % 穿透调用底层的连接
            obj.Transport.connect(varargin{:});
        end
        
        function disconnect(obj)
            % 停下查询并断开连接
            stop(obj.TimerObj);
            obj.Transport.disconnect();
        end
        
        % ============ 向下位机发送业务指令 ============
        
        function startBoost(obj, voltage, current, speed)
            % 下发升压指令
            % 参数(参考PDF)：升压电流mA, 目标电压V, 升压速度V/s
            req.CmdCode = "Boost";
            req.Body.Action = "Boost";
            req.Body.Current_mA = current;
            req.Body.Voltage_V = voltage;
            req.Body.BoostSpeed_Vs = speed;
            
            % 将 struct 结构体一键转换为 JSON 并发给下位机
            strjson = jsonencode(req);
            obj.Transport.sendString(strjson);
        end
        
        function stopBoost(obj)
            % 停止升压/急停：手册要求压置0为停止升压
            % 将保护电流设小、目标电压给 0
            obj.startBoost(0, 0, 1000);
        end
        
        function queryStatus(obj)
            % 周期性向硬件查询目前真实状态
            if obj.Transport.IsConnected
                if seconds(datetime('now') - obj.LastResponseTime) > 2.0
                    disp("[安全机制] 通信超时，断开连接...");
                    notify(obj, 'AlarmReceived', DynamicEvent(struct('CommunicationTimeout', 'Alarm', 'Message', '2秒内未收到设备响应，判定通信中断')));
                    obj.disconnect();
                    return;
                end
                
                req.CmdCode = "Boost";
                req.Body.Action = "Query";
                
                strjson = jsonencode(req);
                obj.Transport.sendString(strjson);
            end
        end
        
        function clearAlarm(obj)
            % 清除告警信息
            req.CmdCode = "AlarmMessage";
            req.Body.Action = "Clear";
            
            strjson = jsonencode(req);
            obj.Transport.sendString(strjson);
        end
        
    end
    
    methods(Access=private)
        
        function replyRegister(obj)
            % [内部方法]：根据手册，上位机收到 REGISTER 请求后，需复传确认上线
            req.CdCode = "REGISTER";
            req.Body.Action = 0;
            
            strjson = jsonencode(req);
            obj.Transport.sendString(strjson);
        end
        
        % ============ 接受与解析下位机反馈 ============
        function onDataReceived(obj, ~, eventData)
            obj.LastResponseTime = datetime('now');
            rawStr = eventData.Data;
            try
                % JSON 解析为 struct 字典
                data = jsondecode(rawStr);
                
                % 按手册的通信定义路由分发事件
                if isfield(data, 'CdCode') && strcmp(data.CdCode, 'REGISTER')
                    % 1. 拦截到设备在线注册报文
                    notify(obj, 'RegisterReceived', DynamicEvent(data.Body));
                    % 自动向设备下发注册回执
                    obj.replyRegister();
                    
                    % 并且注册成功之后开启周期查询数据的定时器
                    obj.LastResponseTime = datetime('now');
                    start(obj.TimerObj);
                    
                elseif isfield(data, 'CmdCode')
                    cmd = data.CmdCode;     
                    switch cmd
                        case 'Boost'
                            if isfield(data.Body, 'Status')
                                % 这是 Action:"Query" 引起的含电压/电流反馈
                                % Body 中含有: Status/Voltage_V/Current_mA/OverVoltage等
                                notify(obj, 'StatusUpdated', DynamicEvent(data.Body));
                                
                            elseif isfield(data.Body, 'Result')
                                % 这是升压指令控制返回的一键结果(例如 Boosting, Stop_ManualStop)
                                disp("[内核控制台] 指令反馈结果：" + data.Body.Result);
                                notify(obj, 'ResultReceived', DynamicEvent(data.Body));
                            end
                            
                        case 'AlarmMessage'
                            if isfield(data.Body, 'Result')
                                disp("[内核控制台] 告警清除操作回执：" + data.Body.Result);
                            else
                                % 突发的被动设备告警(过压极停等)
                                notify(obj, 'AlarmReceived', DynamicEvent(data.Body));
                            end
                            
                        otherwise
                            disp("[内核控制台] 收到未处理的协议簇：" + cmd);
                    end
                end
                
            catch ME
                % 为防止报文意外中断导致的程序崩溃，使用 try catch 拦截不合法的报文
                warning("设备返回的数据协议并非合法JSON格式, 报错： %s", ME.message);
            end
        end
    end
end