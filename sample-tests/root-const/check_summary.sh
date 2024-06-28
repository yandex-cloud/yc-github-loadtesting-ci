#!/usr/bin/env bash
#set +e
rc=0

_DEFAULT_CHECK_DIR=${YC_LT_AUTOMATION_SCRIPTS_DIR:-automation}
if [[ -f "$_DEFAULT_CHECK_DIR/default_check_summary.sh" ]]; then
    /usr/bin/env bash "$_DEFAULT_CHECK_DIR/default_check_summary.sh" "$1"
    rc=$?
fi

echo '- test status is DONE'
if ! jq -re '"DONE" == (.summary.status)' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

echo '- no error reported'
if ! jq -re '"" == (.summary.error // "")' <"$1" >/dev/null; then
    echo "-- FAIL"
    rc=1
fi

exit $rc
