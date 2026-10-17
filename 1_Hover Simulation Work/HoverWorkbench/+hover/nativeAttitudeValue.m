function [value,config]=nativeAttitudeValue(config,name,newValue)
%NATIVEATTITUDEVALUE Read/write the actual CLI, with explicit estimator scaling.
arguments
    config (1,1) struct
    name (1,1) string {mustBeMember(name,["acc_lpf_hz","imu_dcm_kp","imu_dcm_ki"])}
    newValue = []
end
scale=1;
if startsWith(name,'imu_dcm_'), scale=10000; end
schema=bf.parseCliSettings(config.SchemaText);
item=schema(strcmp({schema.Name},name));
if isempty(item), error('hover:MissingNativeSetting','Firmware does not expose %s.',name); end
if nargin==3
    validateattributes(newValue,{'double'},{'scalar','real','finite','nonnegative'});
    raw=newValue*scale;
    if abs(raw-round(raw))>1e-7
        error('hover:NativeSettingResolution','%s requires increments of %g.',name,1/scale);
    end
    config=bf.setSetting(config,item(1),round(raw),0);
end
value=str2double(bf.settingValue(config.CLI,item(1),0))/scale;
end
