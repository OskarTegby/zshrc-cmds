rtest() {
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

  clear
  info "🧪 Running tests in parallel (-j $JOBS)..."
  CTEST_OUTPUT_ON_FAILURE=1 ctest \
    --test-dir "$CMAKE_DIR" \
    -j "$JOBS" \
    --output-on-failure \
    --no-tests=error \
    "${CTEST_EXTRA_ARGS[@]}"
  local s=$?
  [[ $s -eq 0 ]] || { echo "❌ Tests failed."; return 1; }

  touch "$TIMESTAMP_FILE"
  info "✅ Tests passed — timestamp updated."
}

utest() {
  local log="/tmp/utest.log"

  pushd "$CHAMPSIM_DIR" >/dev/null || { echo "❌ Cannot cd to $CHAMPSIM_DIR"; return 2; }

  make -j"$(nproc)" test >"$log" 2>&1
  local rc=$?

  popd >/dev/null || true

  if (( rc != 0 )); then
    echo "❌ Unit tests failed to build/run (rc=$rc)"
    cat "$log"
    return "$rc"
  fi

  echo "✅ Unit tests passed"
  return 0
}

smk() {
  echo "🔨 Building ChampSim…"
  cd $CHAMPSIM_DIR || { echo "❌ Repo not found"; return 1; }

  # Check for -c or -clean and remove them from arguments
  local clean_first=false
  local args=()
  for arg in "$@"; do
    case "$arg" in
      -c|-clean) clean_first=true ;;
      *) args+=("$arg") ;;
    esac
  done

  if $clean_first; then
    echo "🧹 Cleaning build first…"
    make clean || { echo "❌ make clean failed"; return 1; }
  fi

  make -j"$(nproc)" "${args[@]}"
}

dbmk() {
  echo "🐞 Building ChampSim (debug)…"
  cd $CHAMPSIM_DIR || { echo "❌ Repo not found"; return 1; }

  local clean_first=false
  local args=()
  for arg in "$@"; do
    case "$arg" in
      -c|-clean) clean_first=true ;;
      *) args+=("$arg") ;;
    esac
  done

  if $clean_first; then
    echo "🧹 Cleaning build first…"
    make clean || { echo "❌ make clean failed"; return 1; }
  fi

  make BUILD_TYPE=debug "${args[@]}"
}

gdbcs() {
  : "${CHAMPSIM_DIR:?Set CHAMPSIM_DIR to ChampSim root (e.g., export CHAMPSIM_DIR=~/repos/code/ChampSim-dev)}"
  cd "$CHAMPSIM_DIR" || { echo "❌ Can't cd into: $CHAMPSIM_DIR"; return 1; }

  local bin="./bin/champsim"
  if [[ ! -x "$bin" ]]; then
    echo "⚠️ $bin not found or not executable."
    echo "   Build first (e.g.,: make BUILD_TYPE=debug)."
    return 1
  fi

  # Default args, unless you pass your own
  local -a args=(--warmup_instructions 50000000
                 --simulation_instructions 100000000
                 trace-files/QMM/srv_128.champsimtrace.xz)

  if (( $# )); then
    args=("$@")
  fi

  gdb --args "$bin" "${args[@]}"
}

ptest() {
    cd $CHAMPSIM_DIR
    python test_rip_data.py
    python test_compute_stats.py
}

atest() {
    cd $CHAMPSIM_DIR
    make test
    cd -

    cd $CHAMPSIM_DIR/cmake_build
    ctest
    cd -
}

pytest() {
    cd $CHAMPSIM_DIR/scripts/pyplots
    python check_scripts.py
    cd -
}
