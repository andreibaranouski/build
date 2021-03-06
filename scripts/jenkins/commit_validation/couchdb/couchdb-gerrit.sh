#!/bin/bash
#
#          run by jenkins job:  couchdb-gerrit-master
#                               couchdb-gerrit-251
#
#          use "--legacy" parameter for couchdb-gerrit-251
#
#
#          triggered on Patchset Creation of repo: couchdb

source ~jenkins/.bash_profile
set -e
ulimit -a

cat <<EOF
============================================
===                `date "+%H:%M:%S"`              ===
============================================
EOF
env | grep -iv password | grep -iv passwd | sort

cat <<EOF
============================================
===               clean                  ===
============================================
EOF
sudo killall -9 beam.smp epmd memcached python >/dev/null || true
make clean-xfd-hard

cat <<EOF
============================================
===            update CouchDB            ===
============================================
EOF

pushd couchdb 2>&1 > /dev/null
git fetch ssh://review.couchbase.org:29418/couchdb $GERRIT_REFSPEC && git checkout FETCH_HEAD
popd              2>&1 > /dev/null

cat <<EOF
============================================
===               Build                  ===
============================================
EOF

# Copy couchdb.plt from ${WORKSPACE} (where it was copied from Jenkins master)
# to ${WORKSPACE}/build/couchdb to gain build time

mkdir -p ${WORKSPACE}/build/couchdb

if [ -f ${WORKSPACE}/couchdb.plt ]
then
  cp ${WORKSPACE}/couchdb.plt ${WORKSPACE}/build/couchdb/
fi

make -j4 all install || (make -j1 && false)

# Copy couchdb.plt from ${WORKSPACE}/build/couchdb back to ${WORKSPACE} so it
# can be stored back on Jenkins master

if [ -f ${WORKSPACE}/build/couchdb/couchdb.plt ]
then
  cp ${WORKSPACE}/build/couchdb/couchdb.plt ${WORKSPACE}/
fi

cat <<EOF
============================================
===          Run unit tests              ===
============================================
EOF

if [ -d build/couchdb ]
then
   pushd build/couchdb 2>&1 > /dev/null
else
   pushd couchdb 2>&1 > /dev/null
fi

PATH=$PATH:${WORKSPACE}/couchstore make check

popd 2>&1 > /dev/null

cat <<EOF
============================================
===         Run end to end tests         ===
============================================
EOF
pushd testrunner 2>&1 > /dev/null
make simple-test
popd 2>&1 > /dev/null


cat <<EOF
============================================
===                `date "+%H:%M:%S"`              ===
============================================
EOF
sudo killall -9 beam.smp epmd memcached python >/dev/null || true

## Cleanup .repo directory

if [ -d ${WORKSPACE}/.repo ]
then
  rm -rf ${WORKSPACE}/.repo
fi
