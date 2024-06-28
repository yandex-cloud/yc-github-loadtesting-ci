#!/usr/bin/env bash

rc=0

_DEFAULT_CHECK_DIR=${YC_LT_AUTOMATION_SCRIPTS_DIR:-automation}
if [[ -f "$_DEFAULT_CHECK_DIR/default_check_summary.sh" ]]; then
    /usr/bin/env bash "$_DEFAULT_CHECK_DIR/default_check_summary.sh" "$1"
    rc=$?
fi

echo '- test status is AUTOSTOPPED'
if ! jq -re '"AUTOSTOPPED" == (.summary.status)' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

echo '- no error reported'
if ! jq -re '"" == (.summary.error // "")' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

echo '- degradation reached'
if ! jq -re '0 != (.summary.imbalance_point.rps // 0 | tonumber)' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

echo '- handled 3000 rps'
if ! jq -re '3000 < (.summary.imbalance_point.rps // 0 | tonumber)' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

exit $rc
