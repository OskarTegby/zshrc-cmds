# Build gate: build top-level ChampSim with Make; abort commit on failure.
build_or_fail() {
  local ROOT CORES
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "❌ Not a git repo"; return 1; }

  if command -v nproc >/dev/null 2>&1; then
    CORES="$(nproc)"
  else
    CORES="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
  fi

  echo "🔍 Building ChampSim via top-level Makefile…"
  local build_output
  if ! build_output=$( set -e; make 2>&1 >/dev/null); then
    echo "❌ ChampSim build failed — aborting commit."
    echo
    echo "💥 Compiler output:"
    echo "$build_output"
    return 1
  fi

  echo "✅ ChampSim build succeeded."
  return 0
}

gtest() {
  # silence job-control chatter ([5] PID, "done")
  if [[ -n "$ZSH_VERSION" ]]; then
    emulate -L zsh
    setopt localoptions nomonitor nonotify
  else
    local __oldset="$(set +o)"
    set +m
  fi

  local auto_staged=0

  # Decide staging policy BEFORE setting the trap so the var is visible there
  if git diff --cached --quiet; then
    echo "📦 No files staged — staging all changes..."
    git add -A
    auto_staged=1
  else
    echo "📦 Using existing staged changes — not staging anything else."
  fi

  # Trap Ctrl+C: only unstage if we auto-staged
  trap 'echo ""; echo "⚠️  Interrupted."; 
        if [[ '"$auto_staged"' -eq 1 ]]; then 
          echo "↩️  Unstaging auto-staged changes..."; git reset; 
        else 
          echo "↩️  Leaving your staged set untouched."; 
        fi; 
        return 130' INT

  if ! build_or_fail; then
    echo "❌ Build failed — aborting commit."
    [[ "$auto_staged" -eq 1 ]] && git reset
    if [[ -z "$ZSH_VERSION" ]]; then eval "$__oldset"; fi
    return 1
  fi

  echo "🚀 Running unit tests and blackbox tests in parallel…"

  : > /tmp/utest_output
  ( utest > /tmp/utest_output 2>&1; echo $? > /tmp/utest_rc ) & pid_utest=$!

  : > /tmp/rtest_output
  ( RTEST_SKIP_BUILD=1 RTEST_QUIET=1 rtest > /tmp/rtest_output 2>&1; echo $? > /tmp/rtest_rc ) & pid_rtest=$!

  wait $pid_utest; wait $pid_rtest
  u_rc=$(cat /tmp/utest_rc 2>/dev/null || echo 1)
  r_rc=$(cat /tmp/rtest_rc 2>/dev/null || echo 1)

  # restore bash options if we changed them
  if [[ -z "$ZSH_VERSION" ]]; then eval "$__oldset"; fi

  if [[ $u_rc -ne 0 ]]; then
    echo "❌ Unit tests failed. Commit aborted."
    cat /tmp/utest_output
    echo "🚫 Commit aborted."
    [[ $auto_staged -eq 1 ]] && git reset
    return 1
  fi

  if [[ $r_rc -ne 0 ]]; then
    echo "❌ Blackbox tests failed. Commit aborted."
    cat /tmp/rtest_output
    echo "🚫 Commit aborted."
    [[ $auto_staged -eq 1 ]] && git reset
    return 1
  fi

  echo "✅ Unit tests passed!"
  echo "✅ Blackbox tests passed!"
  echo "🎉 All tests passed. Opening commit editor..."
  trap - INT
  command git commit "$@"
}

function git() {

  # Only activate gtest inside the ChampSim repo
  local champ_root="$HOME/repos/code/ChampSim-dev"  # <-- change this if needed
    
  if [[ "$1" == "commit" ]]; then
    shift
    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    
    
    if [[ "$git_root" == "$champ_root" ]]; then
        if [[ "$1" == "--force" ]]; then
          shift
          command git commit "$@"
        else
          echo "🛡️  Intercepted 'git commit' — running gtest instead..."
          gtest "$@"
        fi
      else
        command git commit "$@"
      fi
  else
    command git "$@"
  fi
}

