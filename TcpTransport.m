classdef TcpTransport < ITransport
    %TCPTRANSPORT 真实物理网络(TCP/IP)通信类
    % 替代原来的 SerialTransport
    
    properties
        IpAddress string = "192.168.1.100" % 默认IP，请根据实际设备修改
        Port double = 8080                 % 默认端口，请根据实际设备修改
        
        % 【新增】将结束符暴露为属性，因为这是工业通信最容易失败的地方！
        % 常见选项: "LF"(\n), "CR"(\r), "CRLF"(\r\n)
        TermChar string = "LF" 
    end
    
    properties(SetAccess=private)
        TcpObj
    end
    
    methods
        function obj = TcpTransport(ip, port)
            if nargin > 0, obj.IpAddress = ip; end
            if nargin > 1, obj.Port = port; end
        end
        
        function connect(obj, ip, port)
            if nargin >= 2, obj.IpAddress = ip; end
            if nargin >= 3, obj.Port = port; end
            
            % 【修复1】：防止重复连接产生的僵尸句柄或端口占用冲突
            if obj.IsConnected || ~isempty(obj.TcpObj)
                obj.disconnect(); 
            end
            
            try
                % 创建 TCP 客户端对象并设置超时时间
                obj.TcpObj = tcpclient(obj.IpAddress, obj.Port, "Timeout", 2);
                
                % 【修复2】：显式设置 Terminator，它不仅决定读取什么时候触发，还决定 writeline 发送什么后缀！
                configureTerminator(obj.TcpObj, obj.TermChar); 
                
                % 配置回调，异步接收数据 (按行读取)
                configureCallback(obj.TcpObj, "terminator", @obj.onDataAvailable);
                
                obj.IsConnected = true;
                disp("✅ 网络连接成功: " + obj.IpAddress + ":" + obj.Port);
            catch ME
                obj.IsConnected = false;
                error('TcpTransport:ConnectFailed', '❌ 网络连接失败: %s\n请检查设备是否开机、网线是否插好、电脑IP是否在同网段！', ME.message);
            end
        end
        
        function disconnect(obj)
            if obj.IsConnected && ~isempty(obj.TcpObj)
                % 【修复3】：在断开前，必须先关闭回调，防止断开瞬间有数据进来导致报错
                try
                    configureCallback(obj.TcpObj, "off"); 
                catch
                end
                
                obj.TcpObj = []; % 清除对象即释放 TCP 连接
                obj.IsConnected = false;
                disp("⚠️ 网络已安全断开: " + obj.IpAddress);
            end
        end
        
        function sendString(obj, strData)
            if obj.IsConnected && ~isempty(obj.TcpObj)
                try
                    % 发送JSON字符串
                    % 【重要提示】：writeline 内部会自动在 strData 尾部追加配置好的 Terminator
                    writeline(obj.TcpObj, strData);
                    % disp("-> [PC发出]: " + strData); % 调试时可解开此注释
                catch ME
                    warning('TcpTransport:SendError', '发送数据失败: %s。可能是网络中途断开。', ME.message);
                    obj.disconnect(); % 发送失败通常意味着链路断开，立刻清理状态
                end
            else
                warning("网络未连接，无法发送指令。");
            end
        end
    end
    
    methods(Access=private)
        function onDataAvailable(obj, ~, ~)
            % 从 TCP 缓冲区读取一行数据
            if ~obj.IsConnected || isempty(obj.TcpObj)
                return; % 防止由于异步竞争，在 disconnect 后仍然触发回调
            end
            
            try
                % readline 会读取直到遇到 Terminator 的数据
                str = readline(obj.TcpObj);
                str = strtrim(str); % 去除多余前后空格回车
                
                if ~isempty(str)
                    % disp("<- [硬件回传]: " + str); % 调试时可解开此注释
                    % 向上层协议逻辑暴露数据
                    notify(obj, 'DataReceived', DataEvent(str));
                end
            catch ME
                warning('TcpTransport:ReadError', '读取网络数据失败: %s', ME.message);
            end
        end
    end
end