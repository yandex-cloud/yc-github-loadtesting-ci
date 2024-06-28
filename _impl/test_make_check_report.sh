#!/usr/bin/env bash
source "$(dirname "$0")/_source.sh"

function _help() {
    cat <<EOF
Prints tests check report in markdown format.

Usage:
  $(basename "$0") [-t DIR ID DID_PASS REPORT_FILE]...

Parameters:
  -t DIR ID DID_PASS REPORT_FILE - parameters specifying test check. can be repeated multiple times.
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

function _summary_fn() {
    echo "| $_dir | $_id_link | $_status |"
}

function _details_fn() {
    cat <<EOF

#### **--> $_dir**

Test: $_id_link

Status: $_status

$(_md_collapsed "Output..." "$(_md_code_block "$_report")")

---

EOF
}

# ---------------------------------------------------------------------------- #
#                            Arguments and constants                           #
# ---------------------------------------------------------------------------- #

_dirs=()
_ids=()
_pass_statuses=()
_report_files=()

while [[ $# -gt 0 ]]; do
    case "$1" in
    --help | -h) _help && exit 0 ;;
    --test | -t)
        _dirs+=("$2")
        _ids+=("$3")
        _pass_statuses+=("$4")
        _report_files+=("$5")
        shift 5
        ;;
    esac
done

_n=${#_dirs[@]}

_details=("" "---")

_summary_table=("| test | id | result |")
_summary_table+=("| - | - | - |")

for _i in $(seq 0 $((_n - 1))); do
    _dir=${_dirs[$_i]}
    _dir=${_dir#"$PWD/"}

    _id=${_ids[$_i]}
    _pass_status=${_pass_statuses[$_i]}
    _report_file=${_report_files[$_i]}

    _id_link="-"
    _status="INVALID TEST"
    _report=""

    if [[ -n "$_id" ]]; then
        _url=$(yc_test_url "$_id")
        _id_link="[$_id]($_url)"

        case "$_pass_status" in
        1 | ok | OK | passed | PASSED) _status="PASSED" ;;
        *) _status="FAILED" ;;
        esac

        if [[ -f "$_report_file" ]]; then
            _report=$(cat "$_report_file")
        fi
    fi

    _summary_table+=("$(_summary_fn)")
    _details+=("$(_details_fn)")
done

cat <<EOF
## Assessment

$(printf '%s\n' "${_summary_table[@]}")

$(_md_collapsed "Details..." "$(printf '%s\n' "${_details[@]}")")

EOF
