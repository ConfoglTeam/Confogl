#!/bin/bash

# If you don't want to re-clone to this directory, just make some symlinks.


SOURCEMOD="../../sourcemod"
# crx-git: https://github.com/CanadaRox/sourcemod-plugins
CRXGIT="crx-git"
# crx-stuff: https://bitbucket.org/CanadaRox/random-sourcemod-stuff
CRXSTUFF="crx-stuff"
# psim-stuff: https://bitbucket.org/ProdigySim/misc-sourcemod-plugins
PSIMSTUFF="psim-stuff"
# lgofnoc: https://github.com/ConfoglTeam/LGOFNOC
LGOFNOC="lgofnoc"
# don-stuff: https://bitbucket.org/DonSanchez/random-sourcemod-stuff/
DONSTUFF="don-stuff"
# l4d2util: https://github.com/Jahze/l4d2util
L4D2UTIL="l4d2util"
# l4d2_direct: https://github.com/ProdigySim/l4d2_direct
L4D2DIRECT="l4d2_direct"

update_git() { git --git-dir=$1/.git pull; }
update_hg() { hg --cwd $1 pull -u; }

update_git $CRXGIT
update_hg $CRXSTUFF
update_hg $PSIMSTUFF
update_git $LGOFNOC
update_hg $DONSTUFF
update_git $L4D2UTIL
update_git $L4D2DIRECT

make SOURCEMOD=$SOURCEMOD CRXGIT=$CRXGIT CRXSTUFF=$CRXSTUFF PSIMSTUFF=$PSIMSTUFF LGOFNOC=$LGOFNOC DONSTUFF=$DONSTUFF L4D2UTIL=$L4D2UTIL L4D2DIRECT=$L4D2DIRECT
