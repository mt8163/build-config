#!/bin/bash
echo "--- Setup"
export USE_CCACHE="1"
export PYTHONDONTWRITEBYTECODE=true
export BUILD_ENFORCE_SELINUX=1
export BUILD_NO=
mkdir ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
PATH=~/bin:$PATH
chmod a+x ~/bin/repo

unset BUILD_NUMBER
#TODO(zif): convert this to a runtime check, grep "sse4_2.*popcnt" /proc/cpuinfo
export CPU_SSE42=false
# Following env is set from build
# VERSION
# DEVICE
# TYPE
# RELEASE_TYPE
# EXP_PICK_CHANGES



if [ -z "$BUILD_UUID" ]; then
  export BUILD_UUID=$(uuidgen)
fi

if [ -z "$TYPE" ]; then
  export TYPE=userdebug
fi
export BUILD_NUMBER=$( (date +%s%N ; echo $BUILD_UUID; hostname) | openssl sha1 | sed -e 's/.*=//g; s/ //g' | cut -c1-10 )

echo "--- Syncing"
mkdir -p $HOME/android/${VERSION} 
cd $HOME/android/${VERSION}
rm -rf .repo/local_manifests/*
if [ -f /lineage/setup.sh ]; then
    source /lineage/setup.sh
fi
yes | repo init -u https://github.com/mt8163/android.git -b ${VERSION}
git clone https://github.com/mt8163/local_manifests.git -b ${VERSION} .repo/local_manifests
echo "Syncing"
repo sync -j32
. build/envsetup.sh

echo "--- clobber"
rm -rf out

echo "--- lunch"
set +e
lunch lineage_${DEVICE}-${TYPE}
cmka bacon
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
mka otatools-package target-files-package dist > /tmp/android-build.log

echo "--- Uploading"
