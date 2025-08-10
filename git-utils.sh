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

