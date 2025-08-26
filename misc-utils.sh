move() {
    local file="${1:-/tmp/test}"
    if [[ -e "$file" ]]; then
        mv "$file" .
    else
        echo "File not found: $file"
    fi
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
  local csv_flag="$2"
  local csv_file="$3"

  python3 -c "
import subprocess, re, sys
from pathlib import Path

pattern = re.compile(r'$search_str\s*([-+]?[0-9]*\.?[0-9]+)')
files = list(Path('.').glob('*.out'))

if not files:
    print('No .out files found.', file=sys.stderr)
    sys.exit(1)

results = []

for file in files:
    text = file.read_text()
    match = pattern.search(text)
    if match:
        ipc_value = float(match.group(1))
        results.append( (file.name, ipc_value) )
    else:
        print(f'Warning: No IPC found in {file.name}', file=sys.stderr)

if '$csv_flag' == '--csv':
    header = 'file,ipc'
    rows = [f\"{fname},{ipc}\" for fname, ipc in results]
    csv_content = '\\n'.join([header] + rows)
    if '$csv_file':
        with open('$csv_file', 'w') as f:
            f.write(csv_content + '\\n')
    else:
        print(csv_content)
else:
    values = [ipc for _, ipc in results]
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

missgeo() {
  local line_match=""
  local field=""
  local out_file="results.csv"
  local just_print=0

  # Parse arguments
  for arg in "$@"; do
    case "$arg" in
      --print)
        just_print=1
        ;;
      *)
        if [[ -z "$line_match" ]]; then
          line_match="$arg"
        elif [[ -z "$field" ]]; then
          field="$arg"
        else
          out_file="$arg"
        fi
        ;;
    esac
  done

  if [[ -z "$line_match" || -z "$field" ]]; then
    echo "Usage: llcspecificgeo <LINE_MATCH> <FIELD> [output_file] [--print]"
    echo "Example: llcspecificgeo 'LLC TOTAL' 'MISS:' --print"
    return 1
  fi

  if [[ "$just_print" -eq 0 ]]; then
    echo "directory,geo_mean,warning" > "$out_file"
  fi

  find . -type f -name "*.out" | sed 's|/[^/]*$||' | sort -u | while read -r dir; do
    python3 -c "
import math, os, re

dir_path = '''$dir'''
line_match = '''$line_match'''
field = '''$field'''
pattern = re.compile(rf'{re.escape(field)}\s*([0-9]+)')

values = []
for file in os.listdir('$dir'):
    if file.endswith('.out'):
        with open(os.path.join('$dir', file)) as f:
            for line in f:
                if line_match in line:
                    match = pattern.search(line)
                    if match:
                        try:
                            values.append(float(match.group(1)))
                        except ValueError:
                            pass

#print(f'DEBUG: {os.path.basename(os.path.abspath(dir_path))} extracted values: {values}')
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

