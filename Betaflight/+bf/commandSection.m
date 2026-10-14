function [text,config] = commandSection(config,prefixes,replacement)
%COMMANDSECTION Read or replace a family of non-set CLI commands.
% Examples: {'aux'}, {'mixer','mmix'}, or {'map','rxrange','rxfail'}.
arguments
    config (1,1) struct
    prefixes cell
    replacement {mustBeText} = ''
end
bf.validateConfig(config);
lines=splitlines(string(config.CLI));
expression=['^(' strjoin(prefixes,'|') ')(\s|$)'];
matches=~cellfun('isempty',regexp(cellstr(strtrim(lines)),expression,'once'));
text=char(join(lines(matches),newline));
if nargin<3, return; end
newLines=splitlines(join(string(replacement),newline));
nonComment=strlength(strtrim(newLines))>0 & ~startsWith(strtrim(newLines),'#');
recognized=~cellfun('isempty',regexp(cellstr(strtrim(newLines)),expression,'once'));
if any(nonComment & ~recognized)
    error('bf:InvalidCommand','This section accepts only: %s. Use the complete CLI tab for other commands.',strjoin(prefixes,', '));
end
location=find(matches,1,'first');
if isempty(location)
    location=find(~cellfun('isempty',regexp(cellstr(strtrim(lines)),'^(save|exit)(\s|$)','once')),1,'first');
    if isempty(location), location=numel(lines)+1; end
end
before=lines(1:location-1); after=lines(location:end);
after=after(~matches(location:end));
config.CLI=char(join([before;newLines;after],newline));
end
