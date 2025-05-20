rtest() {
    cd ~/repos/code/ChampSim-dev/cmake_build
    ctest
    cd -
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

