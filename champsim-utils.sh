rtest() {
    clear
    echo "🔨 Building ChampSim executable..."

    CHAMPSIM_DIR=~/repos/code/ChampSim-dev
    CMAKE_DIR="$CHAMPSIM_DIR/cmake_build"
    EXECUTABLE="$CHAMPSIM_DIR/bin/champsim"
    TIMESTAMP_FILE="$CHAMPSIM_DIR/.last_test_run"

    if pushd "$CHAMPSIM_DIR" > /dev/null; then
        BUILD_OUTPUT=$(make 2>&1)
        BUILD_STATUS=$?

        if [[ $BUILD_STATUS -ne 0 ]]; then
            echo "❌ Build failed — showing output:"
            echo "$BUILD_OUTPUT"
            popd > /dev/null
            return 1
        elif echo "$BUILD_OUTPUT" | grep -q "Nothing to be done"; then
            echo "🔄 ChampSim already up to date."
        else
            echo "✅ ChampSim built successfully."
        fi

        popd > /dev/null
    else
        echo "❌ Could not enter ChampSim-dev directory"
        return 1
    fi

    # Check if the executable has changed since last test
    if [[ -f "$EXECUTABLE" && -f "$TIMESTAMP_FILE" ]]; then
        if [[ "$EXECUTABLE" -ot "$TIMESTAMP_FILE" ]]; then
            echo "🛑 Skipping tests — executable hasn't changed since last successful run."
            return 0
        fi
    fi

    echo "🧪 Running tests..."
    if pushd "$CMAKE_DIR" > /dev/null; then
        if ! ctest --output-on-failure --stop-on-failure; then
            echo "❌ Tests failed."
            popd > /dev/null
            return 1
        fi
        popd > /dev/null
    else
        echo "❌ Could not enter cmake_build directory"
        return 1
    fi

    # Update timestamp after successful test run
    touch "$TIMESTAMP_FILE"
    echo "✅ Tests passed — timestamp updated."
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
