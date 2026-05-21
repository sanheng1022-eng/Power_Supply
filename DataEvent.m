classdef DataEvent < event.EventData
    %DATAEVENT 自定义事件数据类，用于携带串口或者虚拟串口读到的字符串数据
    properties
        Data string
    end
    methods
        function obj = DataEvent(data)
            obj.Data = data;
        end
    end
end