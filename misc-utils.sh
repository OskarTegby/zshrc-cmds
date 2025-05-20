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
  local search_str="$1"
  python3 -c "
import math, subprocess, re

pattern = re.compile(r'$search_str\s*([-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?)')
lines = subprocess.getoutput(\"grep '$search_str' *.out\").splitlines()

values = []
for line in lines:
    match = pattern.search(line)
    if match:
        try:
            val = float(match.group(1))
            values.append(val)
        except ValueError:
            continue

zero_like = [v for v in values if v == 0]
nonzero = [v for v in values if v > 0]

if not nonzero:
    print('No non-zero values found.')
else:
    geo_mean = math.exp(sum(math.log(x) for x in nonzero) / len(nonzero))
    if zero_like:
        print(f'Warning: {len(zero_like)} zero(s) ignored in geometric mean computation.')
    print(geo_mean)
"
}
