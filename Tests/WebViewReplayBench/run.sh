#!/bin/zsh
# Runs the offline bench for every built variant into results/<date>-<poc rev>-<twostreams rev>/.
#   run.sh [variant...]     default: poc twostreams
set -euo pipefail
HERE=${0:A:h}
VARIANTS=("$@"); (( $#VARIANTS )) || VARIANTS=(poc twostreams)
OUT=$HERE/results/$(date +%Y%m%d-%H%M)-$(cat $HERE/build/poc.rev)-$(cat $HERE/build/twostreams.rev)
mkdir -p $OUT

$HERE/build/bench-${VARIANTS[1]} gen $HERE/fixtures >/dev/null
{ sw_vers; sysctl -n machdep.cpu.brand_string; xcrun swiftc --version 2>&1 | head -1; } > $OUT/host.txt

for v in $VARIANTS; do
  bin=$HERE/build/bench-$v
  echo "== $v ($(cat $HERE/build/$v.rev))"
  $bin ingest > $OUT/ingest-$v.json
  $bin harvest > $OUT/harvest-$v.json
  # One size and shape per process, so each peak RSS is its own.
  parts=()
  for size in small medium large; do
    for shape in agent rrweb; do
      $bin mem $HERE/fixtures $size $shape > $OUT/.mem-$v-$size-$shape.json
      parts+=($OUT/.mem-$v-$size-$shape.json)
    done
  done
  python3 -c 'import json,sys; print(json.dumps([r for p in sys.argv[1:] for r in json.load(open(p))], indent=1))' $parts > $OUT/mem-$v.json
  rm -f $parts
done
echo $OUT
