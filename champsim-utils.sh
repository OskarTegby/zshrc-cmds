rtest() {
    clear
    echo "🔨 Building ChampSim executable..."
    if pushd ~/repos/code/ChampSim-dev > /dev/null; then
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

    echo "🧪 Running tests..."
    if pushd ~/repos/code/ChampSim-dev/cmake_build > /dev/null; then
        if ! ctest --output-on-failure --stop-on-failure; then
            popd > /dev/null
            return 1
        fi
        popd > /dev/null
    else
        echo "❌ Could not enter cmake_build directory"
        return 1
    fi
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
