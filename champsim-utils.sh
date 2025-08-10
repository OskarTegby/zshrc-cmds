rtest() {
  clear
  local CHAMPSIM_DIR=~/repos/code/ChampSim-dev
  local CMAKE_DIR="$CHAMPSIM_DIR/cmake_build"
  local EXECUTABLE="$CHAMPSIM_DIR/bin/champsim"
  local TIMESTAMP_FILE="$CHAMPSIM_DIR/.last_test_run"

  # jobs arg (optional)
  local JOBS
  if (( $# > 0 )) && [[ "$1" != "--" ]]; then JOBS="$1"; shift; else
    JOBS="$(command -v nproc >/dev/null && nproc || sysctl -n hw.ncpu)"
  fi
  local CTEST_EXTRA_ARGS=()
  if (( $# > 0 )) && [[ "$1" == "--" ]]; then shift; CTEST_EXTRA_ARGS=("$@"); fi

  # helper to conditionally print
  info() { [[ -n "${RTEST_QUIET:-}" ]] || echo "$@"; }

  if [[ -z "${RTEST_SKIP_BUILD:-}" ]]; then
    info "🔨 Building ChampSim executable..."
    if pushd "$CHAMPSIM_DIR" >/dev/null; then
      BUILD_OUTPUT=$(make 2>&1); BUILD_STATUS=$?
      if [[ $BUILD_STATUS -ne 0 ]]; then
        echo "❌ Build failed — showing output:"; echo "$BUILD_OUTPUT"
        popd >/dev/null; return 1
      fi
      popd >/dev/null
    else
      echo "❌ Could not enter ChampSim-dev directory"; return 1
    fi
  fi

  if [[ -f "$EXECUTABLE" && -f "$TIMESTAMP_FILE" && "$EXECUTABLE" -ot "$TIMESTAMP_FILE" ]]; then
    info "🛑 Skipping tests — executable hasn't changed since last successful run."
    return 0
  fi

  info "🧪 Running tests in parallel (-j $JOBS)..."
  if pushd "$CMAKE_DIR" >/dev/null; then
    CTEST_OUTPUT_ON_FAILURE=1 ctest -j "$JOBS" --output-on-failure --no-tests=error "${CTEST_EXTRA_ARGS[@]}"
    local s=$?; popd >/dev/null
    [[ $s -eq 0 ]] || { echo "❌ Tests failed."; return 1; }
  else
    echo "❌ Could not enter cmake_build directory"; return 1
  fi

  touch "$TIMESTAMP_FILE"
  info "✅ Tests passed — timestamp updated."
}

utest() {
    cd ~/repos/code/ChampSim-dev
    make test
    cd -
}

ptest() {
    cd ~/repos/code/ChampSim-dev
    python test_rip_data.py
    python test_compute_stats.py
}

atest() {
    cd ~/repos/code/ChampSim-dev
    make test
    cd -

    cd ~/repos/code/ChampSim-dev/cmake_build
    ctest
    cd -
}

pytest() {
    cd ~/repos/code/ChampSim-dev/scripts/pyplots
    python check_scripts.py
    cd -
}
