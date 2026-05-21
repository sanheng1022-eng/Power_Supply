classdef SerialTransport < ITransport
    %SERIALTRANSPORT 真实物理串口通信类
    
    properties
        PortName string = "COM1"
        BaudRate double = 115200
    end
    
    properties(SetAccess=private)
        SerialObj
    end
    
    methods
        function obj = SerialTransport(port, baudrate)
            if nargin > 0, obj.PortName = port; end
            if nargin > 1, obj.BaudRate = baudrate; end
        end
        
        function connect(obj, port, baudrate)
            if nargin >= 2, obj.PortName = port; end
            if nargin >= 3, obj.BaudRate = baudrate; end
            
            try
                % 创建串口对象并设置终止符，考虑到通信是JSON，多半以\r\n或\n作为行尾结束符
                obj.SerialObj = serialport(obj.PortName, obj.BaudRate, "Timeout", 2);
                configureTerminator(obj.SerialObj, "LF"); 
                
                % 配置回调，异步接收数据 (按行读取)
                configureCallback(obj.SerialObj, "terminator", @obj.onDataAvailable);
                obj.IsConnected = true;
                disp("串口连接成功: " + obj.PortName);
            catch ME
                obj.IsConnected = false;
                error("串口连接失败: %s", ME.message);
            end
        end
        
        function disconnect(obj)
            if obj.IsConnected && ~isempty(obj.SerialObj)
                obj.SerialObj = []; % 清除对象即释放串口句柄
                obj.IsConnected = false;
                disp("串口已断开: " + obj.PortName);
            end
        end
        
        function sendString(obj, strData)
            if obj.IsConnected
                % 发送JSON字符串，通过串口线传出
                writeline(obj.SerialObj, strData);
            else
                warning("串口未连接，无法发送指令。");
            end
        end
    end
    
    methods(Access=private)
        function onDataAvailable(obj, ~, ~)
            % 从缓冲区读取一行数据
            str = readline(obj.SerialObj);
            str = strtrim(str); % 去除多余前后空格回车
            if ~isempty(str)
                % 向上层协议逻辑暴露数据
                notify(obj, 'DataReceived', DataEvent(str));
            end
        end
    end
end