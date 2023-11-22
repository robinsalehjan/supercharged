#!/bin/bash

clean_spm_caches() {
  echo 'Deleting SPM caches'
  rm -rf '~/Library/Caches/org.swift.swiftpm/*'
  echo 'Success!'
}

clean_xcode_builds() {
  echo 'Deleting DerivedData folder'
  rm -rf ~/Library/Developer/Xcode/DerivedData
  echo "Removing module cache"
  rm -rf "$(getconf DARWIN_USER_CACHE_DIR)/org.llvm.clang/ModuleCache"
  echo 'Success!'
}

clean_core_simulator() {
  echo 'Killing CoreSimulator zombie processes'
  pids=`ps axo pid,command | grep CoreSimulator | grep -v "grep CoreSimulator" | cut -c 1-5`

  if [ "$1" = "go" ]; then
    kill -9 $pids
  elif [ "$1" = "echo" ]; then
    echo $pids
  else
    pid_param=`echo $pids | tr -s ' ' ','`
    ps -p $pid_param -o pid,command
  fi

  echo 'Success!'
}

nuke_xcode() {
  killall Xcode > /dev/null
  clean_xcode_builds
  echo 'Removing developer tool caches'
  rm -rf ~/Library/Caches/com.apple.dt.Xcode
  clean_spm_caches
  clean_core_simulator
}

nuke_xcode