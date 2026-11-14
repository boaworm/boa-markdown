#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WARMUP="${WARMUP:-3}"
ITERATIONS="${ITERATIONS:-10}"

echo "═══════════════════════════════════════════════════════════"
echo "  BoaMarkdown Full Benchmark Suite"
echo "═══════════════════════════════════════════════════════════"
echo "  Warmup: $WARMUP  Iterations: $ITERATIONS"
echo ""

run_ql_bench() {
    echo ""
    echo "── QuickLook system benchmark"
    bash "$SCRIPT_DIR/ql-bench/ql-bench.sh" --warmup "$WARMUP" --iterations "$ITERATIONS"
}

print_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  All benchmarks complete. Results in: $SCRIPT_DIR/results/"
    echo "═══════════════════════════════════════════════════════════"
    echo "  Files:"
    ls -lh "$SCRIPT_DIR/results/"*-latest.json 2>/dev/null | awk '{print "    " $NF}'
    echo ""
    echo "  To compare with a previous run:"
    echo "    python3 $SCRIPT_DIR/compare.py <before.json> <after.json>"
}

run_ql_bench
print_summary
