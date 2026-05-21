classdef DynamicEvent < event.EventData
    %DYNAMICEVENT 用于携带任意结构体(struct)格式的载荷的事件类型
    properties
        Payload struct
    end
    
    methods
        function obj = DynamicEvent(payload)
            obj.Payload = payload;
        end
    end
end