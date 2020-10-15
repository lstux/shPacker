# shPacker
Linux packages using standard shell available tools
A shPack consists in 2 parts concatenated in a shpkg file :
* a tar (compressed) archive, which may be extracted to /
* a metadata section (list of conffiles, pre/postinstall, etc.) which may be evaluated by a shell

## TAR archive part
This archive may be compressed using gzip, bzip2 or xz and may be directly extracted to /. When using the package installer, it will first be extracted to a temporary directory, to check if configuration files already exist in /. If they already exist, they will be preserved and package configuration files will be renamed.

## Metadata part
It consists in a simple text file, starting with the following line :
    #### SHPKG METADATA BEGIN ####
and ending with
    #### SHPKG METADATA END ####
This file is simply concatenated to the TAR archive to create package.
The package installer will extract this data which will be evaluated in a shell.

### Required variables
    PKGNAME :
    PKGVERSION :
    PKGREVISION :
### Optional variables
    PKGUSER :
    PKGGROUP :
    CONFFILES :
### Pre/Postinstall Pre/Postupdate
it may be defined as variables containing a one-line script or as functions :

    PREINSTALL :
    POSTINSTALL :
    PREUPDATE :
    POSTUPDATE :
    preinstall() :
    postinstall() :
    preupdate() :
    postupdate() :
