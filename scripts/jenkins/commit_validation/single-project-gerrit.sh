#!/bin/bash
#
# Common script run by various Jenkins commit-validation builds.
#
# Checks out the changeset specified by (GERRIT_PROJECT,GERRIT_REFSPEC) from
# Gerrit server GERRIT_HOST:GERRIT_PORT, compiles and then runs unit tests
# for GERRIT_PROJECT (if applicable).
#
# Triggered on patchset creation in a project's repo.

if [ -z "$GERRIT_HOST" ]; then
    echo "Error: Required environment variable 'GERRIT_HOST' not set."
    exit 1
fi
if [ -z "$GERRIT_PORT" ]; then
    echo "Error: Required environment variable 'GERRIT_PORT' not set."
    exit 2
fi
if [ -z "$GERRIT_PROJECT" ]; then
    echo "Error: Required environment variable 'GERRIT_PROJECT' not set."
    exit 3
fi
if [ -z "$GERRIT_REFSPEC" ]; then
    echo "Error: Required environment variable 'GERRIT_REFSPEC' not set."
    exit 4
fi

# How many jobs to run in parallel by default?
PARALLELISM="${PARALLELISM:-8}"

source ~jenkins/.bash_profile
set -e

# CCACHE is good - use it if available.
export PATH=/usr/lib/ccache:$PATH

function echo_cmd {
    echo \# "$@"
    "$@"
}

cat <<EOF

============================================
===    environment                       ===
============================================
EOF
ulimit -a
echo ""
env | grep -iv password | grep -iv passwd | sort

cat <<EOF

============================================
===    clean                             ===
============================================
EOF
echo_cmd make clean-xfd-hard

cat <<EOF

============================================
===    update ${GERRIT_PROJECT}          ===
============================================
EOF
pushd ${GERRIT_PROJECT} 2>&1 > /dev/null
echo_cmd git fetch ssh://${GERRIT_HOST}:${GERRIT_PORT}/${GERRIT_PROJECT} $GERRIT_REFSPEC
echo_cmd git checkout FETCH_HEAD
popd 2>&1 > /dev/null

cat <<EOF

============================================
===               Build                  ===
============================================
EOF
echo_cmd make -j${PARALLELISM}

if [ -f build/${GERRIT_PROJECT}/Makefile ]
then
    cat <<EOF

============================================
===          Run unit tests              ===
============================================
EOF
    pushd build/${GERRIT_PROJECT} 2>&1 > /dev/null
    # -j${PARALLELISM} : Run tests in parallel.
    # -T Test   : Generate XML output file of test results.
    # "|| true" : Needed to ensure that xUnit scanner is run even if one or more
    #             tests fail.
    echo_cmd make test ARGS="-j${PARALLELISM} --output-on-failure --no-compress-output -T Test" || true
    popd 2>&1 > /dev/null
else
    cat <<EOF

============================================
===    No ${GERRIT_PROJECT} Makefile - skipping unit tests
============================================
EOF
fi
