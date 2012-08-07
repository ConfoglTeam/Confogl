#!/bin/bash

clonehg () { hg clone $1 $2; }
clonegit () { git clone $1 $2; }

clonegit git://github.com/CanadaRox/sourcemod-plugins.git crx-git
clonegit git://github.com/ConfoglTeam/LGOFNOC.git lgofnoc
clonegit git://github.com/ConfoglTeam/l4d2util.git l4d2util
clonegit git://github.com/ConfoglTeam/l4d2_direct.git l4d2_direct
clonegit git://github.com/thevintik/sm_plugins.git vintik-plugins

clonehg https://bitbucket.org/CanadaRox/random-sourcemod-stuff crx-stuff
clonehg https://bitbucket.org/ProdigySim/misc-sourcemod-plugins psim-stuff
clonehg https://bitbucket.org/DonSanchez/random-sourcemod-stuff don-stuff
