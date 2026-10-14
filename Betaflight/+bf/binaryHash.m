function value=binaryHash()
%BINARYHASH SHA-256 identity of the locally executed firmware.
path=bf.paths().Binary;
fid=fopen(path,'r');
if fid<0, error('bf:MissingBinary','Firmware executable is missing: %s',path); end
cleanup=onCleanup(@()fclose(fid));
digest=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    bytes=fread(fid,1024*1024,'*uint8');
    if ~isempty(bytes), digest.update(typecast(bytes,'int8')); end
end
value=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end
