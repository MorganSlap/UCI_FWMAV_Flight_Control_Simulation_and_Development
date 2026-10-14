function app = betaflightConfigurator(config)
%BETAFLIGHTCONFIGURATOR Edit actual firmware settings for the simulation.
% app = betaflightConfigurator opens the hover preset unless bfConfig exists.
% app = betaflightConfigurator(bfConfig) resumes a saved configuration.
% The Apply button writes bfConfig to the base workspace. No connected
% flight controller is accessed and no firmware commands run in this GUI.
if nargin<1
    if evalin('base','exist(''bfConfig'',''var'')')
        config=evalin('base','bfConfig');
    else
        config=bf.hoverConfig();
    end
end
app=bf.Configurator(config);
end
