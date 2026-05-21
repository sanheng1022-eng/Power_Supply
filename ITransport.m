classdef ITransport < handle
    %ITRANSPORT 统一通信接口
    % 供真实串口(SerialTransport)和虚拟串口调试(MockTransport)实现
    
    events
        DataReceived % 当接收到完整数据包(JSON字符串)时触发，向附带DataEvent
    end
    
    properties(SetAccess=protected)
        IsConnected (1,1) logical = false % 连接状态
    end
    
    methods(Abstract)
        connect(obj, varargin)
        disconnect(obj)
        sendString(obj, strData)
    end
end