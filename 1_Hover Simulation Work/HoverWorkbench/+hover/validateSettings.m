function notices = validateSettings(settings)
%VALIDATESETTINGS Reject invalid inputs before simulation; return useful notes.
% No expressions from GUI fields or saved profiles are evaluated.
arguments
    settings (1,1) struct
end
schema = hover.settingsSchema();
notices = strings(0,1);
for k = 1:numel(schema)
    item = schema(k);
    parts = strsplit(item.Key,'.');
    try
        value = getfield(settings,parts{:}); %#ok<GFLD>
    catch
        error('hover:MissingSetting','Missing setting "%s" (%s).',item.Key,item.Label);
    end
    switch item.Kind
        case 'number'
            require(isnumeric(value) && isreal(value) && isscalar(value) && ...
                isfinite(value),item,'must be a finite, real number.');
        case 'logical'
            require((islogical(value) || isnumeric(value)) && isreal(value) && ...
                isscalar(value) && ismember(value,[0 1]),item,'must be true or false (0 or 1).');
        case 'choice'
            require((ischar(value) && isrow(value)) || (isstring(value) && isscalar(value)), ...
                item,'must be a single text value.');
            require(ismember(string(value),string(item.Choices)),item, ...
                ['must be one of: ' strjoin(item.Choices,', ') '.']);
        case 'matrix'
            require(isnumeric(value) && isreal(value) && all(isfinite(value),'all'), ...
                item,'must contain finite, real numbers.');
            require(isequal(size(value),size(item.Default)),item, ...
                sprintf('must have size %d-by-%d.',size(item.Default,1),size(item.Default,2)));
    end
end

positive = {'m','S','wing_type','C11','g','rho','fs','t_sim','tau_wing', ...
    'tau_p','tau_q','tau_r','accel.range','accel.BW','gyro.range','gyro.BW','accel.sample_rate','gyro.sample_rate'};
for key = positive
    checkBound(key{1},0,Inf,false);
end
nonnegative = {'CDx','CDy','CDz','CDw','v_ref','w_ref','p_ref','q_ref','r_ref', ...
    'AxFactor','AyFactor','AzFactor','AomegaFactor', ...
    'accel.LPF_set','gyro.LPF_set','mahoney.Kp','mahoney.Ki', ...
    'accel.noise_density','gyro.noise_density','accel.vibration','gyro.vibration'};
for key = nonnegative
    checkBound(key{1},0,Inf,true);
end
checkBound('strength',0,100,true);
checkBound('max_pot',1000,2000,true);
checkBound('seed',0,2^32-1,true);
integers = {'seed','accel.resolution_bits','gyro.resolution_bits'};
for key = integers
    parts = strsplit(key{1},'.');
    value = getfield(settings,parts{:}); %#ok<GFLD>
    if fix(value) ~= value
        error('hover:InvalidSetting','%s must be an integer.',key{1});
    end
end
checkBound('accel.resolution_bits',1,32,true);
checkBound('gyro.resolution_bits',1,32,true);
tensor = settings.I;
if norm(tensor-tensor.','fro') > 1e-10*max(norm(tensor,'fro'),eps)
    error('hover:InvalidInertia','Inertia tensor I must be symmetric.');
end
[~,notPositiveDefinite] = chol((tensor+tensor.')/2);
if notPositiveDefinite
    error('hover:InvalidInertia','Inertia tensor I must be positive definite.');
end

if ~settings.noise_true
    notices(end+1) = "Noise is off. Configure the native estimator gains in Betaflight Configurator.";
end
if settings.k_tau == 0
    notices(end+1) = "Yaw effectiveness is zero; the model has no yaw control authority.";
end
trim = (settings.m*settings.g/4-settings.C21)/settings.C11;
if trim > settings.max_pot || trim < 1000
    notices(end+1) = sprintf('Calculated hover trim %.4g lies outside [1000, max_pot].',trim);
end
if settings.accel.LPF_set >= settings.fs/2 || settings.gyro.LPF_set >= settings.fs/2
    notices(end+1) = "A sensor LPF cutoff is at or above the sensor sampling Nyquist frequency.";
end
if settings.accel.LPF_set == 0 || settings.gyro.LPF_set == 0
    notices(end+1) = "A sensor LPF cutoff is zero; its alpha becomes zero and the filter holds its previous value.";
end
if rank(settings.MMA) < 4
    notices(end+1) = "Mixer matrix MMA is rank deficient.";
end
if abs(settings.X0(8)) > 80*pi/180
    notices(end+1) = "Initial pitch is close to the Euler-angle singularity at +/-90 degrees.";
end

    function checkBound(key,lower,upper,inclusiveLower)
        parts = strsplit(key,'.');
        value = getfield(settings,parts{:}); %#ok<GFLD>
        if inclusiveLower
            valid = value >= lower && value <= upper;
            constraint = sprintf('in [%g, %g]',lower,upper);
        else
            valid = value > lower && value <= upper;
            constraint = sprintf('greater than %g and at most %g',lower,upper);
        end
        if ~valid
            error('hover:InvalidSetting','%s must be %s.',key,constraint);
        end
    end
end

function require(condition,item,message)
if ~condition
    error('hover:InvalidSetting','%s (%s) %s',item.Label,item.Key,message);
end
end
