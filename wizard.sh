#!/usr/bin/bash

# globals
nanorc="./hello.sh" 
#nanorc="$HOME/.nanorc"

# checks if .nanorc already exists
if [ -f "$nanorc" ]; then
    if (whiptail --title "Overwrite" --yesno "Nanorc already exists. Overwrite?" 10 78); then
        :
    else
        exit
    fi
fi

OPTIONS=$(whiptail --title "Nanorc Installation" --checklist --separate-output "Select features" 10 78 4 \
"Line Numbers" "Displays line numbers to the left" OFF \
"Soft Wrap" "Soft wrap overflowing text" OFF \
"No New Lines" "Prevents automatic new line at EOF" OFF \
"Add Syntax Highlighting" "Include syntax definitions" OFF 3>&1 1>&2 2>&3)

mapfile -t nano_options <<< "$OPTIONS"

# Detects whether any options were made
echo "${#OPTIONS[@]}"

# Adds auto-generated notification at the beginning of the file
printf "# This file is generated wth "$0"\n\n" > "$nanorc"


for option in "${nano_options[@]}"; do
    case "$option" in
        "Line Numbers")
            echo """# Displays line numbers to the left
set linenumbers
""" >> "$nanorc"
            ;;

        "Soft Wrap")
            echo """# Move overflowing text to the next line. Does not alter the file.
set softwrap
""" >> "$nanorc"
            ;;

        "No New Lines")
            echo """# Prevents automatic new line at end of file
set nonewlines
""" >> "$nanorc"
            ;;

        "Add Syntax Highlighting")
            echo """# Include syntax definitions
include "~/.nano/apacheconf.nanorc"
include "~/.nano/arduino.nanorc"
include "~/.nano/asciidoc.nanorc"
include "~/.nano/asm.nanorc"
include "~/.nano/awk.nanorc"
include "~/.nano/c.nanorc"
include "~/.nano/clojure.nanorc"
include "~/.nano/cmake.nanorc"
include "~/.nano/coffeescript.nanorc"
include "~/.nano/colortest.nanorc"
include "~/.nano/conf.nanorc"
include "~/.nano/csharp.nanorc"
include "~/.nano/css.nanorc"
include "~/.nano/cython.nanorc"
include "~/.nano/dot.nanorc"
include "~/.nano/dotenv.nanorc"
include "~/.nano/email.nanorc"
include "~/.nano/Dockerfile.nanorc"
include "~/.nano/etc-hosts.nanorc"
include "~/.nano/fish.nanorc"
include "~/.nano/fortran.nanorc"
include "~/.nano/gentoo.nanorc"
include "~/.nano/git.nanorc"
include "~/.nano/gitcommit.nanorc"
include "~/.nano/glsl.nanorc"
include "~/.nano/go.nanorc"
include "~/.nano/gradle.nanorc"
include "~/.nano/groff.nanorc"
include "~/.nano/haml.nanorc"
include "~/.nano/haskell.nanorc"
include "~/.nano/html.nanorc"
include "~/.nano/html.j2.nanorc"
include "~/.nano/ical.nanorc"
include "~/.nano/ini.nanorc"
include "~/.nano/inputrc.nanorc"
include "~/.nano/jade.nanorc"
include "~/.nano/java.nanorc"
include "~/.nano/javascript.nanorc"
include "~/.nano/js.nanorc"
include "~/.nano/json.nanorc"
include "~/.nano/keymap.nanorc"
include "~/.nano/kickstart.nanorc"
include "~/.nano/kotlin.nanorc"
include "~/.nano/ledger.nanorc"
include "~/.nano/lisp.nanorc"
include "~/.nano/lua.nanorc"
include "~/.nano/makefile.nanorc"
include "~/.nano/man.nanorc"
include "~/.nano/markdown.nanorc"
include "~/.nano/mpdconf.nanorc"
include "~/.nano/mutt.nanorc"
include "~/.nano/nanorc.nanorc"
include "~/.nano/nginx.nanorc"
include "~/.nano/nmap.nanorc"
include "~/.nano/ocaml.nanorc"
include "~/.nano/patch.nanorc"
include "~/.nano/peg.nanorc"
include "~/.nano/perl.nanorc"
include "~/.nano/perl6.nanorc"
include "~/.nano/php.nanorc"
include "~/.nano/pkg-config.nanorc"
include "~/.nano/pkgbuild.nanorc"
include "~/.nano/po.nanorc"
include "~/.nano/pov.nanorc"
include "~/.nano/privoxy.nanorc"
include "~/.nano/puppet.nanorc"
include "~/.nano/pug.nanorc"
include "~/.nano/python.nanorc"
include "~/.nano/reST.nanorc"
include "~/.nano/rpmspec.nanorc"
include "~/.nano/ruby.nanorc"
include "~/.nano/rust.nanorc"
include "~/.nano/scala.nanorc"
include "~/.nano/sed.nanorc"
include "~/.nano/sh.nanorc"
include "~/.nano/sls.nanorc"
include "~/.nano/sql.nanorc"
include "~/.nano/svn.nanorc"
include "~/.nano/swift.nanorc"
include "~/.nano/systemd.nanorc"
include "~/.nano/tcl.nanorc"
include "~/.nano/tex.nanorc"
include "~/.nano/vala.nanorc"
include "~/.nano/verilog.nanorc"
include "~/.nano/vi.nanorc"
include "~/.nano/xml.nanorc"
include "~/.nano/xresources.nanorc"
include "~/.nano/yaml.nanorc"
include "~/.nano/yum.nanorc"
include "~/.nano/zsh.nanorc"
""" >> "$nanorc"
        ;;
    esac
done