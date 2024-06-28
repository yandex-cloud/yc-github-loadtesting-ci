#!/usr/bin/env bash
source "$(dirname "$0")/_source.sh"

function _help() {
    cat <<EOF
Usage: $(basename "$0") [FLAGS] TEST_DIR1 [TEST_DIR2]...

Sequentially run and check results of tests defined in directories passed as arguments,
print summary.

Parameters:
  --errors-log FILE - file to write errors to
  --output FILE - file to write test run result in form of [{id: _, status: _, url: _}, ...]
  --out-report-execution - print execution report to file
  --out-report-checks - print checks report to file

Specifically, for each provided argument:
1. call 'test_run.sh TEST_DIR' to run the test (see 'test_run.sh --help')
2. call 'test_check.sh --id TEST_ID --dir TEST_DIR' to check the results (see 'test_check.sh --help')
EOF
}

_DIRS=()
_EXEC_REPORT_FILE=
_CHECKS_REPORT_FILE=
while [[ $# -gt 0 ]]; do
    case "$1" in
    --help | -h) _help && exit 0 ;;
    --errors-log | -e) _ERROR_FILE=$2 && shift 2 ;;
    --output | -o) _OUT_FILE=$2 && shift 2 ;;
    --out-report-execution) _EXEC_REPORT_FILE=$2 && shift 2 ;;
    --out-report-checks) _CHECKS_REPORT_FILE=$2 && shift 2 ;;
    *) _DIRS+=("$1") && shift 1 ;;
    esac
done

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

_log "Got dirs for tests: ${_DIRS[*]}"

_ERROR_FILE=${_ERROR_FILE:-"${VAR_OUTPUT_DIR}/run-error.log"}
mkdir -p "$(dirname "$_ERROR_FILE")" && touch "$_ERROR_FILE"

_OUT_FILE=${_OUT_FILE:-"${VAR_OUTPUT_DIR}/run-result.json"}
mkdir -p "$(dirname "$_OUT_FILE")" && touch "$_OUT_FILE"

declare -i _tests_total="${#_DIRS[@]}"
declare -i _tests_failed=0

_tests_out_files=()
_tests_error_files=()
_tests_failure_reports=()

_args_make_execution_report=()
_args_make_checks_report=()

_log_push_stage "" ""

declare -i _i=-1
for _test_dir in "${_DIRS[@]}"; do
    _i+=1

    _out_dir="$VAR_OUTPUT_DIR/$((RANDOM))"
    _out_info_file="$_out_dir/run-info.json"
    _out_error_file="$_out_dir/run-error.log"
    _out_check_result="$_out_dir/check_result.log"
    mkdir -p "$_out_dir" || true
    touch "$_out_info_file" "$_out_error_file" "$_out_check_result"

    _tests_out_files+=("$_out_info_file")
    _tests_error_files+=("$_out_error_file")

    _args_make_execution_report+=(-t "$_test_dir" "" "$_out_error_file")
    _args_make_checks_report+=(-t "$_test_dir" "" 0 "$_out_check_result")

    _log_stage "[$_test_dir]" "[/]"
    _log "Running..."

    _run_args=("$_test_dir")
    _run_args+=(--errors-log "$_out_error_file")
    _run_args+=(--output "$_out_info_file")
    if ! run_script "$_SCRIPT_DIR/test_run.sh" "${_run_args[@]}"; then
        _err="FAILED RUN $_test_dir: $(tail -n 50 "$_out_error_file")"
        _log "$_err"

        _tests_failed+=1
        _tests_failure_reports+=("$_err")
        continue
    fi

    _test_id=$(jq -r '.id' <"$_out_info_file")
    _test_status=$(jq -r '.status' <"$_out_info_file")
    _test_url=$(jq -r '.url' <"$_out_info_file")

    _args_make_execution_report[((2 + _i * 4))]=$_test_id
    _args_make_checks_report[((2 + _i * 5))]=$_test_id

    ln -s "$_out_dir" "$VAR_OUTPUT_DIR/$_test_id"

    _log "Completed with status: $_test_status"

    yc_test_download_text_results "$_test_id" "$_out_dir"

    _log_stage "[CHECK_RESULTS]"
    if [[ "${VAR_SKIP_TEST_CHECK:-0}" == 0 ]]; then
        _resfile="$_out_check_result"

        _log "Performing checks..."
        if run_script "$_SCRIPT_DIR/test_check.sh" --id "$_test_id" --dir "$_test_dir" -o "$_out_dir" >"$_resfile"; then
            _logv 1 -f <"$_resfile"
            _log "ALL CHECKS PASSED"

            _args_make_checks_report[((3 + _i * 5))]="1"
        else
            _err="FAILED CHECK $_test_dir: $(cat "$_resfile")"
            _log "$_err"

            _tests_failed+=1
            _tests_failure_reports+=("$_err")
        fi
    else
        _log "skipped due to YC_LT_SKIP_TEST_CHECK"
    fi

    _log ""
done

_log_pop_stage 100

cat "${_tests_out_files[@]}" | jq --slurp >"$_OUT_FILE"
cat "${_tests_error_files[@]}" >"$_ERROR_FILE"

if [[ -n "$_EXEC_REPORT_FILE" ]]; then
    if ! run_script "$_SCRIPT_DIR/test_make_execution_report.sh" "${_args_make_execution_report[@]}" >"$_EXEC_REPORT_FILE"; then
        _log "Failed to make execution report"
    else
        _log "Execution report: $_EXEC_REPORT_FILE"
    fi
fi

if [[ -n "$_CHECKS_REPORT_FILE" ]]; then
    if ! run_script "$_SCRIPT_DIR/test_make_check_report.sh" "${_args_make_checks_report[@]}" >"$_CHECKS_REPORT_FILE"; then
        _log "Failed to make checks report"
    else
        _log "Checks report: $_CHECKS_REPORT_FILE"
    fi
fi

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
