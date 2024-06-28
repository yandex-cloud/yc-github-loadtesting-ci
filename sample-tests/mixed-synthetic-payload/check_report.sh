#!/usr/bin/env bash

rc=0

_DEFAULT_CHECK_DIR=${YC_LT_AUTOMATION_SCRIPTS_DIR:-automation}
if [[ -f "$_DEFAULT_CHECK_DIR/default_check_report.sh" ]]; then
    /usr/bin/env bash "$_DEFAULT_CHECK_DIR/default_check_report.sh" "$1"
    rc=$?
fi

echo '- response time 50th percentile less than 5s'
if ! jq -re '5000 > (.overall.quantiles.q50 | tonumber)' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

echo '- has some successful requests to /'
if ! jq -re '0 < (.cases."root".http_codes."200" // 0 | tonumber)' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

echo '- has some successful requests to /foo'
if ! jq -re '0 < (.cases."foo".http_codes."200" // 0 | tonumber)' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

echo '- has some successful requests to /bar'
if ! jq -re '0 < (.cases."bar".http_codes."200" // 0 | tonumber)' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

exit $rc
