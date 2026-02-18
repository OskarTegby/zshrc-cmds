export CHAMPSIM_DIR=~/repos/code/ChampSim-dev
export CHAMPSIM_REF=~/repos/code/ChampSim-ref
export SNIPER_DIR=~/repos/code/dpPred-cbPred
export SNIPER_REF=~/repos/code/snipersim
export SNIPER_ROOT=$SNIPER_DIR
export GRAPHITE_ROOT=$SNIPER_ROOT
export BENCHMARKS_ROOT="${SNIPER_ROOT}/benchmarks/"
export PARSEC_DIR=${SNIPER_ROOT}/benchmarks/parsec/parsec-2.1

export PIN_ROOT="${SNIPER_DIR}/pin_kit/"
export PIN_HOME="$PIN_ROOT"
export PATH="$PIN_ROOT/bin:$PATH"

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
#pyenv install 2.7.18
#pyenv local 2.7.18
