# shPacker
Linux packages using standard shell available tools

A shPack consists in 2 parts concatenated in a shpkg file :
* a tar (compressed) archive, which may be extracted to /
* a metadata section (list of conffiles, pre/postinstall, etc.) which may be evaluated by a shell
