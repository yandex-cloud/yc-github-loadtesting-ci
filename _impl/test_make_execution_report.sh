#!/usr/bin/env bash
source "$(dirname "$0")/_source.sh"

function _help() {
    cat <<EOF
Prints tests execution report in markdown format.

Usage:
  $(basename "$0") [-t DIR ID ERROR_FILE]...

Parameters:
  -t DIR ID ERROR_FILE - parameters specifying test execution. can be repeated multiple times.
EOF
}

function _md_collapsed() {
    local _summary=${1:-}
    local _content=${2:-}
    if [[ -z "$_content" || -z "$_summary" ]]; then
        return 0
    fi

    cat <<EOF

<details><summary>$_summary</summary>
$_content
</details>

EOF
}

function _md_code_block() {
    cat <<EOF

\`\`\`
$1
\`\`\`

EOF
}

function _details_fn() {
    cat <<EOF

#### **--> $_dir**

Test: $_id_link

$(_md_collapsed "Error..." "$(_md_code_block "$_error")")

$(_md_collapsed "Information..." "$(_md_code_block "$_info")")

$(_md_collapsed "Metrics..." "$(_md_code_block "$_report")")

---

EOF
}

function _summary_fn() {
    echo "| $_dir | $_id_link | $_status |"
}

# ---------------------------------------------------------------------------- #
#                            Arguments and constants                           #
# ---------------------------------------------------------------------------- #

_dirs=()
_ids=()
_error_files=()

while [[ $# -gt 0 ]]; do
    case "$1" in
    --help | -h) _help && exit 0 ;;
    --test | -t)
        _dirs+=("$2")
        _ids+=("$3")
        _error_files+=("$4")
        shift 4
        ;;
    esac
done

_n=${#_dirs[@]}

_details=("" "---")

_summary_table=("| test | id | status |")
_summary_table+=("| - | - | - |")

for _i in $(seq 0 $((_n - 1))); do
    _dir=${_dirs[$_i]}
    _dir=${_dir#"$PWD/"}

    _id=${_ids[$_i]}
    _error_file=${_error_files[$_i]}

    _id_link="-"
    _status="ERROR"
    _info=""
    _report=""
    _error=""

    if [[ -n "$_id" ]]; then
        _url=$(yc_test_url "$_id")
        _id_link="[$_id]($_url)"

        _status=$(yc_lt test get "$_id" | jq -r '.summary.status')
        _info=$(yc_lt test get "$_id" --format text)
        _report=$(yc_lt test get-report-table "$_id" --format text)
    elif [[ -f "$_error_file" ]]; then
        _error=$(cat "$_error_file")
    fi

    _summary_table+=("$(_summary_fn)")
    _details+=("$(_details_fn)")
done

cat <<EOF
## Execution

$(printf '%s\n' "${_summary_table[@]}")

$(_md_collapsed "Details..." "$(printf '%s\n' "${_details[@]}")")

EOF
