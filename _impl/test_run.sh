#!/usr/bin/env bash
source "$(dirname "$0")/_source.sh"

# ---------------------------------------------------------------------------- #
#                            Arguments and constants                           #
# ---------------------------------------------------------------------------- #

while [[ $# -gt 0 ]]; do
    case "$1" in
    --help | -h)
        echo "Usage: $(basename "$0") [--errors-log FILE] [--output FILE] TEST_DIR"
        echo ""
        echo "Run test with configurations defined in TEST_DIR/$VAR_TEST_CONFIG_MASK"
        echo "Additional test parameters may be defined in TEST_DIR/meta.json"
        echo ""
        echo "Prints test id to stdout if a test has finished."
        echo ""
        echo "Parameters:"
        echo "  --errors-log FILE - file to write errors to"
        echo "  --output FILE - file to write test run result in form of {id: _, status: _, url: _}"
        exit 0
        ;;
    --errors-log | -e) _ERROR_FILE=$2 && shift 2 ;;
    --output | -o) _OUT_FILE=$2 && shift 2 ;;
    *) _TEST_DIR=$1 && shift 1 ;;
    esac
done

_log_push_stage "[ENTER]"

assert_not_empty _TEST_DIR

_ERROR_FILE=${_ERROR_FILE:-"${VAR_OUTPUT_DIR}/run-error.log"}
mkdir -p "$(dirname "$_ERROR_FILE")" || true
touch "$_ERROR_FILE"

_OUT_FILE=${_OUT_FILE:-"${VAR_OUTPUT_DIR}/run-result.json"}
mkdir -p "$(dirname "$_OUT_FILE")" || true
touch "$_OUT_FILE"

_TEMP_BUCKET_DIR="test-runs/$(rand_str)"
declare -r _TEMP_BUCKET_DIR

function _tee_err {
    tee -a "$_ERROR_FILE" >&2
}

# ---------------------------------------------------------------------------- #
#                   sanity check, before anything is created                   #
# ---------------------------------------------------------------------------- #

_logv 1 "Sanity check..."

if [[ ! -d "$_TEST_DIR" ]]; then
    _log 2> >(_tee_err) "ERROR!!! No such directory: $_TEST_DIR"
    exit 1
fi

_logv 2 "Check arguments composer with dummy params..."
run_script "$_SCRIPT_DIR/_compose_test_create_args.sh" \
    --meta "$_TEST_DIR/meta.json" \
    --artifacts-bucket '' \
    -c 12345 \
    -c 54321 \
    -d local1 inbucket1 bucket1 \
    -d local2 inbucket2 bucket2 \
    >/dev/null

# ---------------------------------------------------------------------------- #
#                       prepare test configuration files                       #
# ---------------------------------------------------------------------------- #

_log_stage "[CONFIG_FILES][LOOKUP]"
_logv 1 "Looking..."

_config_ids=()

# ------------------------- list configuration files ------------------------- #

_config_files=()
while IFS= read -d '' -r _file; do _config_files+=("$_file"); done < \
    <(find "$_TEST_DIR" -type f -name "$VAR_TEST_CONFIG_MASK" -maxdepth 1 -print0)

if [[ ${#_config_files[@]} -eq 0 ]]; then
    _log 2> >(_tee_err) "ERROR!!! No config files found in $_TEST_DIR. Config file mask: $VAR_TEST_CONFIG_MASK"
    exit 1
fi

_logv 1 "Found: ${_config_files[*]}"

# ------------------------ upload configuration files ------------------------ #

_log_stage "[CONFIG_FILES][UPLOAD]"
_logv 1 "Uploading..."

for _file in "${_config_files[@]}"; do
    _config_id=$(yc_lt test-config create --from-yaml-file "$_file" | jq -r '.id')
    _logv 1 "Uploaded: $_file (id=$_config_id)"

    _config_ids+=("$_config_id")
done

# ---------------------------------------------------------------------------- #
#                         prepare local data files                             #
# ---------------------------------------------------------------------------- #

_local_data_fnames=()

function cleanup_temp_data_files {
    _log_stage "[DATA_FILES][CLEANUP]"
    _log "Cleaning up data files..."
    for _fname in "${_local_data_fnames[@]}"; do
        _temp_s3_file="$_TEMP_BUCKET_DIR/$_fname"
        if ! yc_s3_delete "$_temp_s3_file" "$VAR_DATA_BUCKET" >/dev/null; then
            _log "- failed to delete $_temp_s3_file"
        fi
    done
}
trap cleanup_temp_data_files EXIT

# --------------------------- list local data files -------------------------- #

_log_stage "[DATA_FILES][LOOKUP]"
_logv 1 "Looking..."

function is_data_file {
    _non_data_files=("${_config_files[@]}")
    _non_data_files+=("$_TEST_DIR/meta.json")
    _non_data_files+=("$_TEST_DIR/check_summary.sh")
    _non_data_files+=("$_TEST_DIR/check_report.sh")
    for _ndf in "${_non_data_files[@]}"; do
        if [[ $1 == "$_ndf" ]]; then
            return 1
        fi
    done
    return 0
}

_local_data_files=()
while IFS= read -d '' -r _file; do
    if is_data_file "$_file"; then
        _local_data_files+=("$_file")
    fi
done < <(find "$_TEST_DIR" -type f -print0)

_logv 1 "Found: ${_local_data_files[*]}"

# --------------------- upload local data files to bucket -------------------- #

if [[ ${#_local_data_files[@]} -gt 0 ]]; then
    _log_stage "[DATA_FILES][UPLOAD]"
    _logv 1 "Uploading... (should be deleted after test)"

    # TODO: replace with bucket url
    _logv 1 "Upload params: bucket=$VAR_DATA_BUCKET; common-prefix=$_TEMP_BUCKET_DIR/"

    for _file in "${_local_data_files[@]}"; do
        if [[ -z $VAR_DATA_BUCKET ]]; then
            _log "Failed: YC_LT_DATA_BUCKET is not specified."
            break
        fi

        _fname=${_file#"$_TEST_DIR/"}
        _temp_s3_file="$_TEMP_BUCKET_DIR/$_fname"
        if ! yc_s3_upload "$_file" "$_temp_s3_file" "$VAR_DATA_BUCKET" >/dev/null; then
            _log "Failed: $_fname"
            continue
        fi

        _logv 1 "Uploaded: $_fname"
        _local_data_fnames+=("$_fname")
    done
fi

# ---------------------------------------------------------------------------- #
#                           Compose create test arguments                      #
# ---------------------------------------------------------------------------- #

_log_stage "[EXEC][COMPOSE_ARGS]"
_logv 1 "Composing..."

_composer_args=()
_composer_args+=(--meta "$_TEST_DIR/meta.json")
_composer_args+=(--extra-agent-filter "${VAR_TEST_AGENT_FILTER:-}")
_composer_args+=(--extra-labels "${VAR_TEST_EXTRA_LABELS:-}")
_composer_args+=(--extra-description "${VAR_TEST_EXTRA_DESCRIPTION:-}")
for _id in "${_config_ids[@]}"; do
    _composer_args+=(-c "$_id")
done
for _fname in "${_local_data_fnames[@]}"; do
    _composer_args+=(-d "$_fname" "$_TEMP_BUCKET_DIR/$_fname" "$VAR_DATA_BUCKET")
done
if [[ -n $VAR_ARTIFACTS_BUCKET ]]; then
    _composer_args+=(--artifacts-bucket "${VAR_ARTIFACTS_BUCKET}")
fi

if ! _composer_output=$(run_script "$_SCRIPT_DIR/_compose_test_create_args.sh" "${_composer_args[@]}"); then
    _log "Failed: output=$_composer_output"
fi

_test_create_args=()
IFS=$'\t' read -d '' -ra _test_create_args <<<"$_composer_output" || true

_logv 1 "Composed: ${_test_create_args[*]}"

# ---------------------------------------------------------------------------- #
#                                 Run the test                                 #
# ---------------------------------------------------------------------------- #

_log_stage "[EXEC][REQUEST_START]"
_logv 1 "Starting..."

if ! _test=$(yc_lt test create "${_test_create_args[@]}" 2> >(_tee_err)); then

    _log -f <<EOF 2> >(_tee_err)
ERROR!!! Failed to start a test
Create output: $_test
EOF

    exit 1
fi

_test_id=$(jq -r '.id' <<<"$_test")
_test_report_url="$(yc_test_url "$_test_id")/test-report"

_logv 1 "Started: $_test_report_url"

# write id to stdout
echo "$_test_id"

# ---------------------------------------------------------------------------- #
#                                 Wait the test                                #
# ---------------------------------------------------------------------------- #

_log_stage "[EXEC][WAIT]"
_logv 1 "Waiting until finished..."
if ! _test=$(yc_lt test wait --idle-timeout 60s "$_test_id" 2> >(_tee_err)); then

    _log -f <<EOF 2> >(_tee_err)
ERROR!!! Failed to wait until the test has completed.
Wait output: $_test
EOF

    exit 1
fi

_logv 1 "Finished: $_test_report_url"

# ---------------------------------------------------------------------------- #
#                               Check test status                              #
# ---------------------------------------------------------------------------- #

_log_stage "[STATUS_CHECK]"
_logv 1 "Checking status..."

_test_status=$(jq -r '.summary.status' <<<"$_test")
_test_error=$(jq -r '.summary.error // ""' <<<"$_test")

_rc=0
if [[ "$_test_status" == "FAILED" ]]; then
    _log 2> >(_tee_err) "FAILED: the test finished with failed status"
    _rc=1
elif [[ "$_test_status" == "STOPPED" ]]; then
    _log 2> >(_tee_err) "FAILED: someone has stopped the test"
    _rc=1
fi

if [[ -n "$_test_error" ]]; then
    _log 2> >(_tee_err) "Reported error: $_test_error"
fi

_log_stage ""

# write results to stderr
_log "FINISHED: $_test_report_url"
_log "STATUS: $_test_status"
_log "ID: $_test_id"

# write results to out file
cat <<EOF >"$_OUT_FILE"
{
    "local_directory": "$_TEST_DIR",
    "id": "$_test_id",
    "status": "$_test_status",
    "url": "$_test_report_url"
}
EOF

exit ${_rc}
