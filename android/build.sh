#!/bin/bash
echo "--- Setup"
export USE_CCACHE="1"
export PYTHONDONTWRITEBYTECODE=true
export BUILD_ENFORCE_SELINUX=1
export BUILD_NO=
unset BUILD_NUMBER
#TODO(zif): convert this to a runtime check, grep "sse4_2.*popcnt" /proc/cpuinfo
export CPU_SSE42=false
# Following env is set from build
# VERSION
# DEVICE
# TYPE
# RELEASE_TYPE
# EXP_PICK_CHANGES

# setup pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"


function use_python2 {
    pyenv global 2.7.16
}

function use_python3 {
    pyenv global 3.7.4
}

if [ -z "$BUILD_UUID" ]; then
  export BUILD_UUID=$(uuidgen)
fi

if [ -z "$TYPE" ]; then
  export TYPE=userdebug
fi

export BUILD_NUMBER=$( (date +%s%N ; echo $BUILD_UUID; hostname) | openssl sha1 | sed -e 's/.*=//g; s/ //g' | cut -c1-10 )

echo "--- Syncing"
use_python3

cd ~/android/${VERSION}
rm -rf .repo/local_manifests/*
if [ -f /lineage/setup.sh ]; then
    source /lineage/setup.sh
fi
yes | repo init -u https://github.com/mt8163/android.git -b ${VERSION}
git clone https://github.com/mt8163/local_manifests.git -b ${VERSION} .repo/local_manifests
echo "Resetting build tree"
repo forall -vc "git reset --hard" > /tmp/android-reset.log 2>&1
echo "Syncing"
repo sync -j32 -d --force-sync > /tmp/android-sync.log 2>&1
. build/envsetup.sh


echo "--- clobber"
use_python2
rm -rf out

echo "--- breakfast"
use_python3
set +e
breakfast lineage_${DEVICE}-${TYPE}
set -e

if [[ "$TARGET_PRODUCT" != lineage_* ]]; then
    echo "Breakfast failed, exiting"
    exit 1
fi

if [ "$RELEASE_TYPE" '==' "experimental" ]; then
  if [ -n "$EXP_PICK_CHANGES" ]; then
    repopick $EXP_PICK_CHANGES
  fi
fi
echo "--- Building"
use_python2
mka otatools-package target-files-package dist > /tmp/android-build.log

echo "--- Uploading"
