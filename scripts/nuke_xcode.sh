#!/bin/zsh

set -e  # Exit on error

clean_spm_caches() {
  echo 'Deleting SPM caches'
  local spm_cache_dir="$HOME/Library/Caches/org.swift.swiftpm"
  if [ -d "$spm_cache_dir" ]; then
    rm -rf "$spm_cache_dir"/*
    echo 'SPM caches cleared!'
  else
    echo 'SPM cache directory not found'
  fi
}

clean_xcode_builds() {
  echo 'Deleting DerivedData folder'
  local derived_data_dir="$HOME/Library/Developer/Xcode/DerivedData"
  if [ -d "$derived_data_dir" ]; then
    rm -rf "$derived_data_dir"
    echo 'DerivedData cleared!'
  else
    echo 'DerivedData directory not found'
  fi

  echo "Removing module cache"
  local module_cache_dir="$(getconf DARWIN_USER_CACHE_DIR)/org.llvm.clang/ModuleCache"
  if [ -d "$module_cache_dir" ]; then
    rm -rf "$module_cache_dir"
    echo 'Module cache cleared!'
  else
    echo 'Module cache directory not found'
  fi
}

clean_core_simulator() {
  echo 'Killing CoreSimulator zombie processes'
  local pids
  pids=$(ps axo pid,command | grep CoreSimulator | grep -v "grep CoreSimulator" | awk '{print $1}')

  if [ -z "$pids" ]; then
    echo 'No CoreSimulator processes found'
    return 0
  fi

  if [ "$1" = "go" ]; then
    echo "Killing processes: $pids"
    echo "$pids" | xargs kill -9
  elif [ "$1" = "echo" ]; then
    echo "$pids"
  else
    echo "Found CoreSimulator processes:"
    ps -p $(echo "$pids" | tr '\n' ' ') -o pid,command 2>/dev/null || echo "Some processes may have already terminated"
  fi

  echo 'CoreSimulator cleanup complete!'
}

nuke_xcode() {
  echo 'Starting Xcode cleanup...'

  # Kill Xcode gracefully
  if pgrep -x "Xcode" > /dev/null; then
    echo 'Closing Xcode...'
    killall Xcode 2>/dev/null || true
    sleep 2
  fi

  clean_xcode_builds

  echo 'Removing developer tool caches'
  local xcode_cache_dir="$HOME/Library/Caches/com.apple.dt.Xcode"
  if [ -d "$xcode_cache_dir" ]; then
    rm -rf "$xcode_cache_dir"
    echo 'Xcode caches cleared!'
  else
    echo 'Xcode cache directory not found'
  fi

  clean_spm_caches
  clean_core_simulator

  echo 'Xcode cleanup completed successfully!'
}

nuke_xcode
