#Confogl project makefile
# by ProdigySim

# export SOURCEMOD=/path/to/sm
# Source code/includes locations-- based on repos
SOURCEMOD ?= ../../sourcemod
# crx-git: https://github.com/CanadaRox/sourcemod-plugins
CRXGIT ?= crx-git
# crx-stuff: https://bitbucket.org/CanadaRox/random-sourcemod-stuff
CRXSTUFF ?= crx-stuff
# psim-stuff: https://bitbucket.org/ProdigySim/misc-sourcemod-plugins
PSIMSTUFF ?= psim-stuff
# lgofnoc: https://github.com/ConfoglTeam/LGOFNOC
LGOFNOC ?= lgofnoc
# don-stuff: https://bitbucket.org/DonSanchez/random-sourcemod-stuff/
DONSTUFF ?= don-stuff
# vintik-plugins: https://github.com/thevintik/sm_plugins
VINTIK ?= vintik-plugins
# l4d2util: https://github.com/ConfoglTeam/l4d2util
L4D2UTIL ?= l4d2util
# l4d2_direct: https://github.com/ConfoglTeam/l4d2_direct
L4D2DIRECT ?= l4d2_direct


## Plugins to build.
## Separated by source repo: 
## 1. psim-stuff 2. crx-git 3. crx-stuff 4. don-stuff 5. confogl/src

OPT_TARGETS = \
	bossspawningfix.smx l4d2_consistenthordes.smx l4d2_getupfix.smx l4d2_noelevatorspit.smx l4d2_si_ffblock.smx \
	l4d2_weaponrules.smx l4d_inaudible_ghosts.smx l4dhots.smx lerptracker.smx \
\
	l4d2_blind_infected.smx l4d_weapon_limits.smx \
\
	l4d2_nobhaps.smx l4d2_scoremod.smx l4d2_finaledistfixer.smx l4d_hittable_fix.smx \
\
	l4d2_nospitterduringtank.smx l4d_thirdpersonshoulderblock.smx \
\
	NoMercyElevatorFix.smx l4d2_versuswaterbrake.smx

TARGETS = l4dready.smx lgofnoc.smx match_vote.smx


PSIM_DIRS = bossspawningfix elevatorspitnullification l4d2_consistenthordes l4d2_getupfix l4d2_si_ffblock l4d2_weaponrules \
	l4d_inaudible_ghosts l4dhots lerptrack

CRXGIT_DIRS = weapon_limits blind_infected_l4d2 

VINTIK_DIRS = match_vote

DONSTUFF_DIRS = l4d2_nospitterduringtank l4d_thirdpersonshoulderblock

SM = $(realpath $(SOURCEMOD))
SPCOMP = $(SM)/scripting/spcomp
INCLUDE_DIRS = include $(LGOFNOC) $(SM)/scripting/include $(L4D2DIRECT)/scripting/include $(L4D2UTIL)/scripting/include $(PSIMSTUFF)
SOURCE_DIRS = $(addprefix $(CRXGIT)/,$(CRXGIT_DIRS)) $(addprefix $(PSIMSTUFF)/,$(PSIM_DIRS)) $(CRXSTUFF) \
	$(addprefix $(DONSTUFF)/,$(DONSTUFF_DIRS)) $(addprefix $(VINTIK)/,$(VINTIK_DIRS)) $(L4D2UTIL)/scripting
FLAGS = -v0
OUTDIR = bin
OUTDIR_OPT = $(OUTDIR)/optional
INCLUDES = $(addprefix -i,$(INCLUDE_DIRS))

# Check OUTDIR for .smx files
vpath %.smx $(OUTDIR) $(OUTDIR_OPT)
# Check SOURCE_DIRS for .sp files
vpath %.sp $(SOURCE_DIRS)
# Check INCLUDE_DIRS for .inc dependencies
vpath %.inc $(INCLUDE_DIRS) $(SOURCE_DIRS)


.PHONY: clean plugins-prep
.SUFFIXES:
.SUFFIXES: .sp .smx

.sp.smx: $<
	$(SPCOMP) $(INCLUDES) $(FLAGS) $< -o$(OUTDIR_OPT)/$@

default: all
all: plugins

plugins: plugins-prep $(TARGETS) $(OPT_TARGETS)

lgofnoc.smx:
	cd $(LGOFNOC); $(MAKE) SOURCEMOD=$(SM)
	mv $(LGOFNOC)/lgofnoc.smx $(OUTDIR)/

# These plugins don't go in optional so can't use our default rule
l4dready.smx: l4dready.sp
	$(SPCOMP) $(INCLUDES) $(FLAGS) $< -o$(OUTDIR)/$@
match_vote.smx: match_vote.sp
	$(SPCOMP) $(INCLUDES) $(FLAGS) $< -o$(OUTDIR)/$@

plugins-prep:
	mkdir -p $(OUTDIR_OPT)

install:
	mkdir -p ../addons/sourcemod/plugins
	cp -R bin/* ../addons/sourcemod/plugins/
	cp $(L4D2DIRECT)/gamedata/l4d2_direct.txt ../addons/sourcemod/gamedata/

clean:
	-@rm -f $(TARGETS) >/dev/null 2>&1
	-@rm -rf $(OUTDIR)
	-@cd $(LGOFNOC) >/dev/null 2>&1 && $(MAKE) OUTDIR=$(OUTDIR) clean


#PSIM-STUFF


