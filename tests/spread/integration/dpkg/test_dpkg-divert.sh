#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs

rootfs="$(install-slices dpkg_dpkg-divert)"

# Usage: dpkg-divert [<option>...] <command>

# Commands:
#   [--add] <file>           add a diversion.
#   --remove <file>          remove the diversion.
#   --list [<glob-pattern>]  show file diversions.
#   --listpackage <file>     show what package diverts the file.
#   --truename <file>        return the diverted file.

# Options:
#   --package <package>      name of the package whose copy of <file> will not
#                              be diverted.
#   --local                  all packages' versions are diverted.
#   --divert <divert-to>     the name used by other packages' versions.
#   --rename                 actually move the file aside (or back).
#   --no-rename              do not move the file aside (or back) (default).
#   --admindir <directory>   set the directory with the diversions file.
#   --instdir <directory>    set the root directory, but not the admin dir.
#   --root <directory>       set the directory of the root filesystem.
#   --test                   don't do anything, just demonstrate.
#   --quiet                  quiet operation, minimal output.
#   --help                   show this help message.
#   --version                show the version.

# When adding, default is --local and --divert <original>.distrib.
# When removing, --package or --local and --divert must match if specified.
# Package preinst/postrm scripts should always specify --package and --divert.



# dpkg-divert(1)                    dpkg suite                   dpkg-divert(1)

# NAME
#        dpkg-divert - override a package's version of a file

# SYNOPSIS
#        dpkg-divert [option...]  command

# DESCRIPTION
#        dpkg-divert is the utility used to set up and update the list of
#        diversions.

#        File diversions are a way of forcing dpkg(1) not to install a file
#        into its location, but to a diverted location.  Diversions can be used
#        through the package maintainer scripts to move a file away when it
#        causes a conflict.  System administrators can also use it to override
#        some package's configuration file, or whenever some files (which
#        aren't marked as “conffiles”) need to be preserved by dpkg, when
#        installing a newer version of a package which contains those files.

# COMMANDS
#        [--add] file
#            Add  a diversion for file.  The file is currently not renamed, see
#            --rename.

#        --remove file
#            Remove a diversion for file.  The file is currently  not  renamed,
#            see --rename.

#        --list [glob-pattern]
#            List all diversions, or ones matching glob-pattern.

#        --listpackage file
#            Print  the  name  of  the  package  that  diverts file (since dpkg
#            1.15.0).  Prints LOCAL if file is locally diverted and nothing  if
#            file is not diverted.

#        --truename file
#            Print the real name for a diverted file.

# OPTIONS
#        --admindir directory
#            Set  the  administrative  directory  to  directory.   Defaults  to
#            «/var/lib/dpkg» if DPKG_ADMINDIR has not been set.

#        --instdir directory
#            Set the installation directory,  which  refers  to  the  directory
#            where packages get installed (since dpkg 1.19.2).  Defaults to «/»
#            if DPKG_ROOT has not been set.

#        --root directory
#            Set  the  root directory to directory, which sets the installation
#            directory to  «directory»  and  the  administrative  directory  to
#            «directory/var/lib/dpkg»  (since dpkg 1.19.2) if DPKG_ROOT has not
#            been set.

#        --divert divert-to
#            divert-to is the location where the versions of file, as  provided
#            by other packages, will be diverted.

#        --local
#            Specifies  that  all packages' versions of this file are diverted.
#            This means, that there are no exceptions, and whatever package  is
#            installed,  the file is diverted.  This can be used by an admin to
#            install a locally modified version.

#        --package package
#            package is the name of a package whose copy of file  will  not  be
#            diverted.   i.e.  file  will  be  diverted for all packages except
#            package.

#        --quiet
#            Quiet mode, i.e. no verbose output.

#        --rename
#            Actually move the file aside (or back).   dpkg-divert  will  abort
#            operation  in  case  the destination file already exists.  This is
#            the  common  behavior  used  for  diversions  of  files  from  the
#            non-Essential package set (see --no-rename for more details).

#        --no-rename
#            Specifies  that  the  file  should  not be renamed while adding or
#            removing the diversion into  the  database  (since  dpkg  1.19.1).
#            This  is  intended  for  diversions  of  files  from the Essential
#            package set, where the temporary  disappearance  of  the  original
#            file  is  not  acceptable,  as  it  can  render  the  system  non-
#            functional.  This is the default behavior, but that will change in
#            the dpkg 1.20.x cycle.

#        --test
#            Test  mode,  i.e.  don't  actually  perform  any   changes,   just
#            demonstrate.

#        -?, --help
#            Show the usage message and exit.

#        --version
#            Show the version and exit.

# EXIT STATUS
#        0   The requested action was successfully performed.

#        2   Fatal or unrecoverable error due to invalid command-line usage, or
#            interactions  with  the  system, such as accesses to the database,
#            memory allocations, etc.

# ENVIRONMENT
#        DPKG_ROOT
#            If  set  and  the  --instdir  or  --root  options  have  not  been
#            specified, it will be used as the filesystem root directory (since
#            dpkg 1.19.2).

#        DPKG_ADMINDIR
#            If  set  and  the  --admindir  or  --root  options  have  not been
#            specified, it will be used as the dpkg data directory.

#        DPKG_MAINTSCRIPT_PACKAGE
#            If set and  the  --local  and  --package  options  have  not  been
#            specified, dpkg-divert will use it as the package name.

#        DPKG_DEBUG
#            Sets the debug mask (since dpkg 1.21.10) from an octal value.  The
#            currently accepted flags are described in the dpkg --debug option,
#            but not all these flags might have an effect on this program.

#        DPKG_COLORS
#            Sets  the  color mode (since dpkg 1.18.5).  The currently accepted
#            values are: auto (default), always and never.

#        DPKG_NLS
#            If set, it will be used  to  decide  whether  to  activate  Native
#            Language  Support,  also  known  as internationalization (or i18n)
#            support (since dpkg 1.22.7).  The accepted values  are:  0  and  1
#            (default).

# FILES
#        /var/lib/dpkg/diversions
#            File  which contains the current list of diversions of the system.
#            It is located in the dpkg  administration  directory,  along  with
#            other files important to dpkg, such as status or available.

#            Note:  dpkg-divert  preserves  the  old  copy  of  this file, with
#            extension -old, before replacing it with the new one.

# NOTES
#        When adding, default is --local and --divert  original.distrib.   When
#        removing, --package or --local and --divert must match if specified.

#        Directories can't be diverted with dpkg-divert.

#        Care  should  be  taken  when  diverting shared libraries, ldconfig(8)
#        creates a symbolic link based on the DT_SONAME field embedded  in  the
#        library.   Because  ldconfig  does not honor diverts (only dpkg does),
#        the symlink may end up pointing at the diverted library, if a diverted
#        library has the same SONAME as the undiverted one.

# EXAMPLES
#        To divert all copies of a  /usr/bin/example  to  /usr/bin/example.foo,
#        i.e.  directs all packages providing /usr/bin/example to install it as
#        /usr/bin/example.foo, performing the rename if required:

#         dpkg-divert --divert /usr/bin/example.foo --rename /usr/bin/example

#        To remove that diversion:

#         dpkg-divert --rename --remove /usr/bin/example

#        To  divert  any  package  trying  to   install   /usr/bin/example   to
#        /usr/bin/example.foo, except your own wibble package:

#         dpkg-divert --package wibble --divert /usr/bin/example.foo \
#            --rename /usr/bin/example

#        To remove that diversion:

#         dpkg-divert --package wibble --rename --remove /usr/bin/example

# SEE ALSO
#        dpkg(1).

# 1.22.18                           2025-03-20                   dpkg-divert(1)




# Check that dpkg-divert runs and shows help
help=$(chroot "$rootfs" dpkg-divert --help | head -n1 || true)
echo "$help" | grep -q "Usage: dpkg-divert"
version=$(chroot "$rootfs" dpkg-divert --version | head -n1 || true)
echo "$version" | grep -q "Debian dpkg-divert version"
chroot "$rootfs" dpkg-divert --help

# Create a dummy file to divert
mkdir -p "$rootfs/usr/bin"
echo -e '#!/bin/sh\necho "This is foo"' > "$rootfs/usr/bin/foo"
chmod +x "$rootfs/usr/bin/foo"

# Divert the file
chroot "$rootfs" dpkg-divert --add --rename --divert /usr/bin/foo.distrib /usr/bin/foo \
    | grep -q "Adding 'local diversion of /usr/bin/foo to /usr/bin/foo.distrib'"
test -f "$rootfs/usr/bin/foo.distrib"
test ! -f "$rootfs/usr/bin/foo"

# Check that the diversion is listed
diversion_list=$(chroot "$rootfs" dpkg-divert --list /usr/bin/foo || true)
echo "$diversion_list" | grep -q "local diversion of /usr/bin/foo to /usr/bin/foo.distrib"

# Check the truename command
truename=$(chroot "$rootfs" dpkg-divert --truename /usr/bin/foo || true)
echo "$truename" | grep -q "/usr/bin/foo.distrib"

# Check the listpackage command
listpackage=$(chroot "$rootfs" dpkg-divert --listpackage /usr/bin/foo || true)
echo "$listpackage" | grep -q "LOCAL"

# Remove the diversion
chroot "$rootfs" dpkg-divert --remove --rename /usr/bin/foo \
    | grep -q "Removing 'local diversion of /usr/bin/foo to /usr/bin/foo.distrib'"
test -f "$rootfs/usr/bin/foo"
test ! -f "$rootfs/usr/bin/foo.distrib"

# Check that the diversion is no longer listed
diversion_list=$(chroot "$rootfs" dpkg-divert --list /usr/bin/foo || true)
test -z "$diversion_list"
