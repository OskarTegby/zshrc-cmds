gtest() {
    # Trap Ctrl+C to clean up and return to prompt without killing the shell
    trap 'echo ""; echo "⚠️  Interrupted. Unstaging changes..."; git reset; return 130' INT

    echo "📦 Staging all changes..."
    git add -A

    echo "🔍 Running unit tests (utest)..."
    utest_output=$(utest)
    echo "$utest_output" > /tmp/utest_output
    if ! echo "$utest_output" | grep -q "All tests passed"; then
        echo "❌ Unit tests did not pass. Commit aborted."
        cat /tmp/utest_output
        echo "🚫 Commit aborted."
        git reset
        return 1
    else
        echo "✅ Unit tests passed!"
    fi

    echo "🔍 Running blackbox tests (rtest)..."
    if rtest_output=$(rtest); then
        echo "$rtest_output" > /tmp/rtest_output
        if echo "$rtest_output" | grep -q "Skipping tests"; then
            echo "⏭️  Skipped blackbox tests (no build changes)."
        else
            echo "✅ Blackbox tests passed!"
        fi
    else
        echo "$rtest_output" > /tmp/rtest_output
        echo "❌ Blackbox tests did not pass. Commit aborted."
        cat /tmp/rtest_output
        echo "🚫 Commit aborted."
        git reset
        return 1
    fi

    echo "🎉 All tests passed. Opening commit editor..."
    trap - INT

    # Forward all original git commit arguments (e.g. --amend, -m, etc.)
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

