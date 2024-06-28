#!/usr/bin/env bash

if [[ -n $_LOG_STAGE_STR ]]; then
    export _LOG_STAGE=()
    IFS=$'\n' read -d '' -ra _LOG_STAGE <<<"$_LOG_STAGE_STR" || true
else
    export _LOG_STAGE_STR=''
    export _LOG_STAGE=()
fi

function _log_push_stage {
    local _st
    for _st in "$@"; do
        _LOG_STAGE+=("$_st")
        _LOG_STAGE_STR=$(
            IFS=$'\n'
            echo "${_LOG_STAGE[*]}"
        )
    done
}

function _log_pop_stage {
    local _i
    for _i in $(seq 1 "${1:-1}"); do
        if [[ ${#_LOG_STAGE[@]} -gt 0 ]]; then
            _N=${#_LOG_STAGE[@]}
            _LOG_STAGE=("${_LOG_STAGE[@]::${_N}-1}")
        else
            break
        fi
    done
    _LOG_STAGE_STR=$(
        IFS=$'\n'
        echo "${_LOG_STAGE[*]}"
    )
}

function _log_stage {
    _log_pop_stage "$#"
    _log_push_stage "$@"
}

function _log {
    if [[ "$1" == '-f' ]]; then
        shift
        (
            IFS=
            echo >&2 "${_LOG_STAGE[*]}:" && cat >&2 "$@"
        )
    else
        (
            IFS=
            echo >&2 "${_LOG_STAGE[*]}:" "$@"
        )
    fi
}

function _logv {
    if [[ $VAR_VERBOSE -ge "$1" ]]; then
        shift
        _log "$@"
    fi
}

function assert_installed {
    local err=0
    for _cmd in "$@"; do
        if ! command -v "$_cmd" 1>/dev/null 2>&1; then
            _log "ERROR!!! Assertion failed: $_cmd is not installed"
            err=1
        fi
    done
    if [[ $err -ne 0 ]]; then
        exit 1
    fi
}

function assert_yc_configured {
    local err=0
    if [[ -z "${VAR_FOLDER_ID:-$(yc_ config get folder-id)}" ]]; then
        _log "Folder ID must be specified either via YC_LT_FOLDER_ID or via CLI profile."
        err=1
    fi
    if [[ -z "${VAR_TOKEN:-$(yc_get_token)}" ]]; then
        _log "Failed to authenticate in yc cli. Please specify authentication method (CLI profile: YC_LT_CLI_PROFILE or token: YC_LT_TOKEN)"
        err=1
    fi

    if [[ $err -ne 0 ]]; then
        exit 1
    fi
}

function assert_not_empty {
    if [[ -z "${!1}" ]]; then
        _log "ERROR!!! Assertion failed: ${2:-"variable $1 is empty or not defined"}"
        exit 1
    fi
    return 0
}

function rand_str {
    (
        set +o pipefail
        LC_ALL=C tr -d -c '0-9a-f' </dev/urandom 2>/dev/null | head -c 6
    )
}

function run_script {
    /usr/bin/env bash -- "$@"
}

function yc_ {
    local _no_browser=()
    local _profile=()
    local _folder_id=()
    local _token=()
    local _format=(--format json)

    if [[ "$VAR_CLI_INTERACTIVE" == "0" ]]; then _no_browser+=(--no-browser); fi
    if [[ -n "$VAR_CLI_PROFILE" ]]; then _profile=(--profile "$VAR_CLI_PROFILE"); fi
    if [[ -n "$VAR_FOLDER_ID" ]]; then _folder_id=(--folder-id "$VAR_FOLDER_ID"); fi
    if [[ -n "$VAR_TOKEN" ]]; then _token=(--token "$VAR_TOKEN"); fi

    local _opts=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --no-browser) _no_browser=(--no-browser) && shift 1 ;;
        --profile) _profile=(--profile "$2") && shift 2 ;;
        --folder-id) _folder_id=(--folder-id "$2") && shift 2 ;;
        --token) _token=(--token "$2") && shift 2 ;;
        --format) _format=(--format "$2") && shift 2 ;;
        *) _opts+=("$1") && shift 1 ;;
        esac
    done

    _opts+=("${_no_browser[@]}")
    _opts+=("${_profile[@]}")
    _opts+=("${_folder_id[@]}")
    _opts+=("${_format[@]}")
    _logv 2 "Calling yc ${_opts[*]}"

    yc "${_token[@]}" "${_opts[@]}"
    return $?
}

function yc_get_token {
    yc_ --format text iam create-token || true
    return 0
}

function yc_lt {
    yc_ loadtesting "$@"
    return $?
}

function yc_s3_upload {
    assert_installed curl

    local -r file=$1
    local -r bucket_path=$2
    local -r bucket=${3:-"$VAR_DATA_BUCKET"}

    assert_not_empty file
    assert_not_empty bucket
    assert_not_empty bucket_path

    local -r token=${VAR_TOKEN:-$(yc_get_token)}
    local -r auth_h="X-YaCloud-SubjectToken: $token"
    curl -L -H "$auth_h" --upload-file - "$VAR_OBJECT_STORAGE_URL/$bucket/$bucket_path" \
        2>/dev/null \
        <"$file"

    return $?
}

function yc_s3_delete {
    assert_installed curl

    local -r bucket_path=$1
    local -r bucket=${2:-"$VAR_DATA_BUCKET"}

    assert_not_empty bucket
    assert_not_empty bucket_path

    local -r token=${VAR_TOKEN:-$(yc_get_token)}
    local -r auth_h="X-YaCloud-SubjectToken: $token"
    curl -L -H "$auth_h" -X DELETE "$VAR_OBJECT_STORAGE_URL/$bucket/$bucket_path" \
        2>/dev/null

    return $?
}

function yc_test_url {
    local -r test_id=$1
    local -r folder_id=${VAR_FOLDER_ID:-$(yc_ config get folder-id)}
    echo "$VAR_WEB_CONSOLE_URL/folders/$folder_id/load-testing/tests/$test_id"
}

function yc_test_download_json_results {
    local _id=$1
    local _dir=${2:-"$VAR_OUTPUT_DIR"}
    if [[ -n $_dir ]]; then mkdir -p "$_dir"; fi

    if ! yc_lt test get "$_id" >"$_dir/summary.json"; then
        return $?
    fi
    if ! yc_lt test get-report-table "$_id" >"$_dir/report.json"; then
        return $?
    fi
}

function yc_test_download_text_results {
    local _id=$1
    local _dir=${2:-"$VAR_OUTPUT_DIR"}
    if [[ -n $_dir ]]; then mkdir -p "$_dir"; fi

    if ! yc_lt --format text test get "$_id" >"$_dir/summary.txt"; then
        return $?
    fi
    if ! yc_lt --format text test get-report-table "$_id" >"$_dir/report.txt"; then
        return $?
    fi
}

function check_json_val {
    local -r description=${1:-"$2 $3"}
    local -r filter=$2
    local -r condition=$3
    local -r file=${4:-$_CHECK_JSON_FILE}
    echo "- $description"
    echo "-- $(jq -r "$filter" "$file" 2>/dev/null) $condition"
    if jq -re "($filter) $condition" "$file" >/dev/null; then
        echo "-- OK"
        return 0
    else
        echo "-- filter: $filter"
        echo "-- FAIL"
        return 1
    fi
}
