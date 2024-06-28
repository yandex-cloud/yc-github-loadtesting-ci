#!/usr/bin/env bash

rc=0

_DEFAULT_CHECK_DIR=${YC_LT_AUTOMATION_SCRIPTS_DIR:-automation}
if [[ -f "$_DEFAULT_CHECK_DIR/default_check_report.sh" ]]; then
    /usr/bin/env bash "$_DEFAULT_CHECK_DIR/default_check_report.sh" "$1"
    rc=$?
fi

echo '- response time 99th percentile less than 10s'
if ! jq -re '10000 > (.overall.quantiles.q99 | tonumber)' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

echo '- at least 1000 successful responses'
if ! jq -re '1000 <= (.overall.http_codes."200" // 0 | tonumber)' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

echo '- at least 75% of net responses are 0'
if ! jq -re '0.75 < ((.overall.net_codes."0" // 0 | tonumber) / ([.overall.net_codes[] | tonumber] | add))' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

echo '- at least 75% of http responses are 200'
if ! jq -re '0.75 < ((.overall.http_codes."200" // 0 | tonumber) / ([.overall.http_codes[] | tonumber] | add))' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

exit $rc
