#!/usr/bin/env bash
source "$(dirname "$0")/_source.sh"

_DIRS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
    --help | -h)
        echo "Usage: $(basename "$0") TEST_DIR1 [TEST_DIR2]..."
        echo ""
        echo "Sequentially run and check results of tests defined in directories passed as arguments,"
        echo "print summary."
        echo ""
        echo "Specifically, for each provided argument:"
        echo "1. call 'test_run.sh TEST_DIR' to run the test (see 'test_run.sh --help')"
        echo "2. call 'test_check.sh --id TEST_ID --dir TEST_DIR' to check the results (see 'test_check.sh --help')"
        exit 0
        ;;
    *)
        _DIRS+=("$1")
        shift
        ;;
    esac
done

_logv 1 "YC CLI profile: ${VAR_CLI_PROFILE:-"current aka <$(yc_ config profile list | grep ' ACTIVE')>"}"
_logv 1 ""

_log -f <<EOF
Execution:
|--------------------
| folder: ${VAR_FOLDER_ID:-$(yc_ config get folder-id)}
| skip results check: $VAR_SKIP_TEST_CHECK
|
| data bucket: $VAR_DATA_BUCKET
| extra test labels: $VAR_TEST_EXTRA_LABELS
| extra test description: $VAR_TEST_EXTRA_DESCRIPTION
|
| output local dir: $VAR_OUTPUT_DIR
|--------------------
EOF
_log ""

if [[ -z "${VAR_FOLDER_ID:-$(yc_ config get folder-id)}" ]]; then
    _log "Folder ID must be specified either via YC_LT_FOLDER_ID or via CLI profile."
    exit 1
fi

_log "Got dirs for tests: ${_DIRS[*]}"

declare -i _tests_total="${#_DIRS[@]}"
declare -i _tests_failed=0
declare _tests_failure_reports=()

_log_push_stage "" ""
for _test_dir in "${_DIRS[@]}"; do
    _out_dir="$VAR_OUTPUT_DIR/$(rand_str)"

    _log_stage "[$_test_dir]" "[/]"
    _log "Running..."

    _run_args=("$_test_dir")
    _run_args+=(--errors-log "$_out_dir/run-error.txt")
    _run_args+=(--output "$_out_dir/run-out.json")
    if ! run_script "$_SCRIPT_DIR/test_run.sh" "${_run_args[@]}"; then
        _msg="FAILED: $(cat "$_out_dir/run-error.txt")"
        _tests_failure_reports+=("$(_log "$_msg" 2> >(tee /dev/stderr))")
        _tests_failed=$((_tests_failed + 1))
        continue
    fi

    _test_id=$(jq -r '.id' <"$_out_dir/run-out.json")
    _test_status=$(jq -r '.status' <"$_out_dir/run-out.json")
    _test_url=$(jq -r '.url' <"$_out_dir/run-out.json")

    mv "$_out_dir" "$VAR_OUTPUT_DIR/$_test_id"
    _out_dir="$VAR_OUTPUT_DIR/$_test_id"

    _log "Completed with status: $_test_status"

    yc_test_download_text_results "$_test_id" "$_out_dir"

    _log_stage "[CHECK_RESULTS]"
    if [[ "${VAR_SKIP_TEST_CHECK:-0}" == 0 ]]; then
        _resfile="$_out_dir/check_result.txt"

        _log "Performing checks..."
        if run_script "$_SCRIPT_DIR/test_check.sh" --id "$_test_id" --dir "$_test_dir" -o "$_out_dir" >"$_resfile"; then
            _logv 1 -f <"$_resfile"
            _log "ALL CHECKS PASSED"
        else
            _log -f <"$_resfile"
            _msg="FAILED: checks did not pass. Result in $_resfile"
            _tests_failure_reports+=("$(_log "$_msg" 2> >(tee /dev/stderr))")
            _tests_failed=$((_tests_failed + 1))
        fi
    else
        _log "skipped due to YC_LT_SKIP_TEST_CHECK"
    fi

    _log ""
done

_log_pop_stage 100

_summary_header="[ OK - $((_tests_total - _tests_failed)) | FAILED - $_tests_failed ]"
_log "==================== $_summary_header ===================="
_log ""
if ((_tests_failed != 0)); then
    _log "$_tests_failed out of $_tests_total tests have failed:"
    for _msg in "${_tests_failure_reports[@]}"; do
        _log "$_msg"
    done
fi
_log ""
_log "==================== $_summary_header ===================="

echo "$_tests_failed"
exit "$_tests_failed"
