#!/usr/bin/env bash
# ============================================================
# CS486 G05 — Campus Space Management System
# Task 13: Concurrency Tests — run_all.sh (orchestrator)
#
# Runs the comparison suite in this order:
#   1. baseline/  pairs  (RAW SQL, no concurrency control) — expected:
#      invariant violations / raw engine errors, printed as observed.
#   2. controlled/ pairs (Task 12 entry points) — asserted exact codes.
#   3. suite audit (audit_invariant.sql).
#   4. fixture teardown (99_cleanup.sql).
# ============================================================
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

TS="$(date +%Y%m%d-%H%M%S)"
mkdir -p results
rm -rf results/*

SQLCMD=(sqlcmd -C -I -S "${SQLCMD_SERVER:-localhost}" -d "${SQLCMD_DB:-CampusSpaceDB}")
if [ -n "${SQLCMD_USER:-}" ]; then SQLCMD+=(-U "$SQLCMD_USER"); fi
if [ -n "${SQLCMD_PASSWORD:-}" ]; then SQLCMD+=(-P "$SQLCMD_PASSWORD"); fi

overall=0

run_setup() {
    "${SQLCMD[@]}" -b -i 99_cleanup.sql > /dev/null 2>&1 || true
    "${SQLCMD[@]}" -b -i 00_setup.sql > /dev/null 2>&1
}

run1() { # run one script synchronously
    local f="$1"
    run_setup
    "${SQLCMD[@]}" -b -i "$f" -o "results/${TS}-$(basename "$f").log" 2>&1 || { echo "RUN-ERROR: $f"; overall=1; }
}

run2_baseline() { # run baseline pair (raw engine exceptions expected)
    local a="$1" b="$2"
    run_setup
    "${SQLCMD[@]}" -i "$a" -o "results/${TS}-$(basename "$a").log" 2>&1 &
    local pidA=$!
    "${SQLCMD[@]}" -i "$b" -o "results/${TS}-$(basename "$b").log" 2>&1 &
    local pidB=$!
    wait $pidA $pidB || true
}

run2_controlled() { # run controlled pair (must pass cleanly)
    local a="$1" b="$2"
    run_setup
    "${SQLCMD[@]}" -b -i "$a" -o "results/${TS}-$(basename "$a").log" 2>&1 &
    local pidA=$!
    "${SQLCMD[@]}" -b -i "$b" -o "results/${TS}-$(basename "$b").log" 2>&1 &
    local pidB=$!
    wait $pidA $pidB || { echo "RUN-ERROR: pair $a / $b"; overall=1; }
}

echo "== T13 run $TS: BASELINE pairs (no concurrency control) =="
run2_baseline baseline/b01_instant_instant_a.sql baseline/b01_instant_instant_b.sql
run2_baseline baseline/b02_instant_vs_staff_a.sql baseline/b02_instant_vs_staff_b.sql
run2_baseline baseline/b03_escalation_a.sql      baseline/b03_escalation_b.sql
run2_baseline baseline/b05_blocking_a.sql        baseline/b05_blocking_b.sql
run2_baseline baseline/b09_ticket_vs_submit_a.sql baseline/b09_ticket_vs_submit_b.sql
run2_baseline baseline/b10_staff_vs_staff_a.sql  baseline/b10_staff_vs_staff_b.sql

echo "== T13 run: CONTROLLED (Task 12 entry points) =="
run2_controlled controlled/c01_instant_a.sql controlled/c01_instant_b.sql
run2_controlled controlled/c02_instant_staff_a.sql controlled/c02_instant_staff_b.sql
run2_controlled controlled/c03_escalation_a.sql controlled/c03_escalation_b.sql
run2_controlled controlled/c03b_submit_wins_a.sql controlled/c03b_submit_wins_b.sql
run2_controlled controlled/c05_timeout_a.sql controlled/c05_timeout_b.sql
run2_controlled controlled/c09_ticket_submit_a.sql controlled/c09_ticket_submit_b.sql
run2_controlled controlled/c10_staff_staff_a.sql controlled/c10_staff_staff_b.sql
run1 controlled/c11_soft_gate.sql
run1 controlled/c12_fallback_vs_instant.sql
run1 controlled/c13_ack_repair.sql

echo "== T13 run: suite audit =="
run1 audit_invariant.sql

echo "== T13 run: teardown =="
"${SQLCMD[@]}" -b -i 99_cleanup.sql > /dev/null 2>&1

# Summary & Log Aggregation
fails=0
for f in results/${TS}-*.log; do
    if [ -f "$f" ] && grep -q 'FAIL' "$f"; then
        echo "FAIL present in: $(basename "$f")"
        fails=$((fails+1))
    fi
done

SUMMARY_FILE="results/SUMMARY.log"
{
    echo "============================================================"
    echo " CS486 G05 Task 13 — AGGREGATED TEST SUITE RUN LOG ($TS)"
    echo "============================================================"
    for f in results/${TS}-*.log; do
        if [ -f "$f" ] && [ "$f" != "$SUMMARY_FILE" ]; then
            echo ""
            echo "------------------------------------------------------------"
            echo " SESSION LOG: $(basename "$f")"
            echo "------------------------------------------------------------"
            cat "$f"
        fi
    done
} > "$SUMMARY_FILE"

# Keep only the aggregated master SUMMARY.log
rm -f results/${TS}-*.log

if [ "$fails" -eq 0 ] && [ "$overall" -eq 0 ]; then
    echo "T13-SUITE: PASS (all scenario + audit logs clean)."
    echo "Aggregated summary log created at: $SUMMARY_FILE"
    exit 0
else
    echo "T13-SUITE: FAIL — $fails log(s) with FAIL lines, runner errors: $overall"
    echo "Aggregated summary log created at: $SUMMARY_FILE"
    exit 1
fi