move() {
    local file="${1:-/tmp/test}"
    if [[ -e "$file" ]]; then
        mv "$file" .
    else
        echo "File not found: $file"
    fi
}

db() {
    make clean
    make BUILD_TYPE=debug
}

mc() {
    make clean
    make BUILD_TYPE=mem_check
}

geo() {
  local search_str="$1"
  python3 -c "
import math, subprocess

# Get raw output from grep + awk
raw = subprocess.getoutput(\"grep '$search_str' *.out | awk '{print \$NF}'\")
lines = raw.splitlines()

try:
    values = [int(x) for x in lines]
    zero_count = sum(1 for v in values if v == 0)
    nonzero = [v for v in values if v > 0]

    if not nonzero:
        print('No non-zero values found.')
    else:
        geo_mean = math.exp(sum(math.log(x) for x in nonzero) / len(nonzero))
        if zero_count > 0:
            print(f'Warning: {zero_count} zero(s) ignored in geometric mean computation.')
        print(geo_mean)
except Exception as e:
    print(f'Error: {e}')
"
}

toarr() {
  local search_str="$1"
  python3 -c "
import subprocess, re
pattern = re.compile(r'$search_str\s*(\d+)')
lines = subprocess.getoutput(\"grep '$search_str' *.out\").splitlines()
values = [int(m.group(1)) for line in lines if (m := pattern.search(line))]
print(values)
"
}

ngeo() {
  local search_str=""
  local out_file="geo_results.csv"
  local just_print=0

  # Parse arguments
  for arg in "$@"; do
    case "$arg" in
      --print)
        just_print=1
        ;;
      *)
        if [[ -z "$search_str" ]]; then
          search_str="$arg"
        else
          out_file="$arg"
        fi
        ;;
    esac
  done

  if [[ -z "$search_str" ]]; then
    echo "Usage: ngeo <search_string> [output_file] [--print]"
    return 1
  fi

  if [[ "$just_print" -eq 0 ]]; then
    echo "directory,geo_mean,warning" > "$out_file"
  fi

  find . -type f -name "*.out" | sed 's|/[^/]*$||' | sort -u | while read -r dir; do
    python3 -c "
import math, re, os

search_str = '$search_str'
pattern = re.compile(rf'{re.escape(search_str)}\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)')

values = []
for file in os.listdir('$dir'):
    if file.endswith('.out'):
        with open(os.path.join('$dir', file)) as f:
            for line in f:
                match = pattern.search(line)
                if match:
                    try:
                        val = float(match.group(1))
                        values.append(val)
                    except ValueError:
                        pass

zero_like = [v for v in values if v == 0]
nonzero = [v for v in values if v > 0]

if not nonzero:
    result = 'NaN'
else:
    result = math.exp(sum(math.log(x) for x in nonzero) / len(nonzero))

warn = f'{len(zero_like)} zero(s)' if zero_like else ''
print(f'{os.path.basename(os.path.abspath(\"$dir\"))},{result},{warn}')
" | {
      if [[ "$just_print" -eq 1 ]]; then
        cat
      else
        tee -a "$out_file" > /dev/null
      fi
    }
  done

  if [[ "$just_print" -eq 0 ]]; then
    echo "Results saved to $out_file"
  fi
}

