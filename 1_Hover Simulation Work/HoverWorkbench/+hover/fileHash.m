function hash = fileHash(path)
%FILEHASH SHA-256 of a source file for archived run provenance.
arguments
    path (1,:) char
end
fid=fopen(path,'rb');
assert(fid>=0,'HoverWorkbench:ReadSource','Cannot read source file: %s',path);
cleanup=onCleanup(@()fclose(fid));
engine=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    engine.update(fread(fid,1024*1024,'*uint8'));
end
bytes=typecast(engine.digest(),'uint8');
hash=lower(reshape(dec2hex(bytes,2).',1,[]));
end
