function value = gitInfo(folder,kind)
%GITINFO Read version provenance; simulation also works outside a checkout.
arguments
    folder (1,:) char
    kind (1,:) char {mustBeMember(kind,{'branch','commit'})}
end
if strcmp(kind,'branch'), command='rev-parse --abbrev-ref HEAD';
else, command='rev-parse HEAD'; end
if contains(folder,'"'), value='unavailable'; return; end
[status,text]=system(sprintf('git -C "%s" %s',folder,command));
if status==0, value=strtrim(text); else, value='unavailable'; end
end
