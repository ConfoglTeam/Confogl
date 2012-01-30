#Confogl project makefile
# by ProdigySim

# export SOURCEMOD=/path/to/sm
SOURCEMOD ?= ../../sourcemod

SPCOMP = ${SOURCEMOD}/scripting/spcomp
INCLUDES = -iinclude
FLAGS = -v0
OUTDIR = bin
VPATH=${OUTDIR}

TARGETS = bossspawningfix.smx l4d2_noelevatorspit.smx l4d2_weaponrules.smx l4dhots.smx lerptracker.smx \
        l4d2_blind_infected.smx l4d2_nospitterduringtank.smx l4d_inaudible_ghosts.smx lgofnoc.smx \
        l4d2_consistenhordes.smx l4d2_scoremod.smx l4d_notank.smx l4d2_getupfix.smx \
        l4d2_si_ffblock.smx l4d2_nobhaps.smx l4d_thirdpersonshoulderblock.smx l4d_weapon_limits.smx \
        NoMercyElevatorFix.smx l4d2_versuswaterbrake.smx l4dready.smx

LGOFNOC_FILES = CvarSettings.sp MapInfo.sp  MatchMode.sp  configs.sp  customtags.inc  \
        functions.sp keyvalues_stocks.inc

LGOFNOC_INCLUDES = $(addprefix lgofnoc-includes/,${LGOFNOC_FILES})

.SUFFIXES:
.SUFFIXES: .sp .smx

.sp.smx: $<
	${SPCOMP} ${INCLUDES} ${FLAGS} $< -o${OUTDIR}/$@

all: plugins

plugins: plugins-prep ${TARGETS}

plugins-prep:
	-@mkdir -p ${OUTDIR}

clean:
	-@rm -f ${TARGETS} >/dev/null 2>&1
	-@rm -rf ${OUTDIR}

lgofnoc.smx: lgofnoc.sp ${LGOFNOC_INCLUDES}
	${SPCOMP} ${INCLUDES} ${FLAGS} -ilgofnoc-includes lgofnoc.sp -o${OUTDIR}/$@


l4d2_weaponrules.smx: include/weapons.inc
l4d2_blind_infected.smx: include/weapons.inc
l4d2_weaponlimits.smx: include/weapons.inc
l4d_weapon_limits.smx: include/weapons.inc
l4d2_getupfix.smx: include/survivors.inc
