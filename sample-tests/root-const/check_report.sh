#!/usr/bin/env bash

rc=0

_DEFAULT_CHECK_DIR=${YC_LT_AUTOMATION_SCRIPTS_DIR:-automation}
if [[ -f "$_DEFAULT_CHECK_DIR/default_check_report.sh" ]]; then
    /usr/bin/env bash "$_DEFAULT_CHECK_DIR/default_check_report.sh" "$1"
    rc=$?
fi

echo '- response time 50th percentile less than 200ms'
if ! jq -re '200 > (.overall.quantiles.q50 | tonumber)' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

exit $rc
