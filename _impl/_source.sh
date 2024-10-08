#!/usr/bin/env bash

set -eo pipefail

# shellcheck disable=SC2155
export _SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# shellcheck source=_functions.sh
source "$_SCRIPT_DIR/_functions.sh"

# shellcheck source=_variables.sh
source "$_SCRIPT_DIR/_variables.sh"

assert_installed yc jq
assert_yc_configured

_logv 1 "YC CLI profile: ${VAR_CLI_PROFILE:-"current aka <$(yc_ config profile list | grep ' ACTIVE')>"}"
_logv 1 ""
