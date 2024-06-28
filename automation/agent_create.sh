#!/usr/bin/env bash
source "$(dirname "$0")/_source.sh"

# ---------------------------------------------------------------------------- #
#                     Retrieve arguments from command line                     #
# ---------------------------------------------------------------------------- #

_NO_NET=
_NET=""
if [[ -n $VAR_AGENT_SECURITY_GROUP_IDS ]]; then _NET+=",security-group-ids=$VAR_AGENT_SECURITY_GROUP_IDS"; fi
if [[ -n $VAR_AGENT_IPV4_ADDRESS ]]; then _NET+=",ipv4-address=$VAR_AGENT_IPV4_ADDRESS,nat-ip-version=ipv4"; fi
if [[ -n $VAR_AGENT_SUBNET_ID ]]; then _NET+=",subnet-id=$VAR_AGENT_SUBNET_ID";
elif [[ -n $VAR_AGENT_SUBNET_NAME ]]; then _NET+=",subnet-name=$VAR_AGENT_SUBNET_NAME"; fi
_NET=${_NET#","}

_log "$@"

_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        echo "Usage: $(basename "$0") [--count N] [ARG]..."
        echo ""
        echo "Create N (default = 1) agents and wait until they are READY_FOR_TEST"
        echo ""
        echo "Provided arguments are passed to 'yc loadtesting agent create [ARG]...' as is."
        echo "If missing, some argument values are defaulted YC_LT_* environment variables."
        exit 0
        ;;
    --count) VAR_AGENTS_CNT=$2 && shift 2 ;;
    --service-account-id) VAR_AGENT_SA_ID=$2 && shift 2 ;;
    --name) _AGENT_NAME=$2 && shift 2 ;;
    --description) VAR_AGENT_DESCRIPTION=$2 && shift 2 ;;
    --labels) VAR_AGENT_LABELS=$2 && shift 2 ;;
    --zone) VAR_AGENT_ZONE=$2 && shift 2 ;;
    --cores) VAR_AGENT_CORES=$2 && shift 2 ;;
    --memory) VAR_AGENT_MEMORY=$2 && shift 2 ;;
    --public-ip) _NO_NET=1 && _ARGS+=("$1") && shift 1 ;;
    --public-ip-address) _NO_NET=1 && _ARGS+=("$1" "$2") && shift 2 ;;
    --network-interface) _NET=$2 && shift 2 ;;
    --) shift 1 ;;
    *) _ARGS+=("$1") && shift 1 ;;
    esac
done

_log_stage "[PREPARE]"

assert_not_empty VAR_AGENT_SA_ID
if [[ -z $_NO_NET && -z $_NET ]]; then
    _log "Network settings not specified. Either public ip or subnet must be specified"
    exit 1
fi

if [[ -z "$_AGENT_NAME" ]]; then
    _AGENT_NAME="$VAR_AGENT_NAME_PREFIX"
fi

_log "count: $VAR_AGENTS_CNT (--count $VAR_AGENTS_CNT)"
_log "name/prefix: $_AGENT_NAME (--name $_AGENT_NAME)"

# ---------------------------------------------------------------------------- #
#                               Assert variables                               #
# ---------------------------------------------------------------------------- #

if [[ -z "${VAR_FOLDER_ID:-$(yc_ config get folder-id)}" ]]; then
    _log "Folder ID must be specified either via YC_LT_FOLDER_ID or via CLI profile."
    exit 1
fi

# ---------------------------------------------------------------------------- #
#                         Compose command line options                         #
# ---------------------------------------------------------------------------- #

if [[ -n $VAR_AGENT_SA_ID ]]; then
    _ARGS+=(--service-account-id "$VAR_AGENT_SA_ID")
fi
if [[ -n $VAR_AGENT_DESCRIPTION ]]; then
    _ARGS+=(--description "$VAR_AGENT_DESCRIPTION")
fi
if [[ -n $VAR_AGENT_LABELS ]]; then
    _ARGS+=(--labels "$VAR_AGENT_LABELS")
fi
if [[ -n $VAR_AGENT_ZONE ]]; then
    _ARGS+=(--zone "$VAR_AGENT_ZONE")
fi
if [[ -n $VAR_AGENT_CORES ]]; then
    _ARGS+=(--cores "$VAR_AGENT_CORES")
fi
if [[ -n $VAR_AGENT_MEMORY ]]; then
    _ARGS+=(--memory "$VAR_AGENT_MEMORY")
fi
if [[ -z $_NO_NET && -n $_NET ]]; then
    _ARGS+=(--network-interface "$_NET")
fi

# ---------------------------------------------------------------------------- #
#                                Create an agent                               #
# ---------------------------------------------------------------------------- #

function _generate_name() {
    if [[ $VAR_AGENTS_CNT -gt 1 ]]; then
        echo "$_AGENT_NAME-$(rand_str)"
    else
        echo "$_AGENT_NAME"
    fi
}

_log_stage "[CREATE]"

_ids=()
_log "Creating $VAR_AGENTS_CNT agents..."
_log_push_stage "[0]"
for _i in $(seq 1 "$VAR_AGENTS_CNT"); do
    _log_stage "[$_i]"

    _name="$(_generate_name)"
    _logv 1 "Creating $_name..."
    if ! _op=$(yc_lt agent create --async --name "$_name" "${_ARGS[@]}"); then
        _log "Creation failed: $_name"
        exit 1
    fi

    _op_id=$(jq -r '.id' <<<"$_op")
    _id=$(jq -r '.metadata.agent_id' <<<"$_op")
    _log "Creation operation in progress: $_name (id=$_id, operation_id=$_op_id)"

    echo "$_id"
    _ids+=("$_id")
done
_log_pop_stage

# ---------------------------------------------------------------------------- #
#                      Wait until agent is READY_FOR_TEST                      #
# ---------------------------------------------------------------------------- #

_TICK=10
_TIMEOUT=${VAR_AGENT_CREATE_TIMEOUT:-600}

_log_stage "[WAIT]"
_log "Waiting for agents to be ready..."
_log "Timeout: ${_TIMEOUT}s; Poll period: ${_TICK}s"

_log_push_stage "[0s]" "[0/$VAR_AGENTS_CNT]"

_ready=0
_iteration=0
_failed_iterations=0
_elapsed=0
_ts_start=$(date +%s)
while ((_elapsed < _TIMEOUT)); do
    ((_iteration += 1))
    _ts=$(date +%s)
    _elapsed=$((_ts - _ts_start))
    _log_stage "[${_elapsed}s]" "[$_ready/$VAR_AGENTS_CNT]"

    if ! _agents=$(yc_lt agent get "${_ids[@]}"); then
        _log "Failed to get agent status"
        if ((_failed_iterations >= 10)); then
            _log "ERROR: aborting due to $_failed_iterations subsequent failed attempts to check statuses"
            exit 1
        else
            ((_failed_iterations += 1))
            sleep "$_TICK"
            continue
        fi
    else
        _failed_iterations=0
    fi

    if (( VAR_AGENTS_CNT == 1 )); then
        _agents=$(jq '[.]' <<<"$_agents")
    fi

    _new_ready=$(jq -r '[.[] | select(.status == "READY_FOR_TEST")] | length' <<<"$_agents")
    _log_stage "[$_new_ready/$VAR_AGENTS_CNT]"

    if [[ "$_new_ready" -eq "$VAR_AGENTS_CNT" ]]; then
        _log "All agents are ready"
        _logv 1 "Wow! It took only ${_elapsed}s!"
        exit 0
    fi

    if [[ "$_new_ready" -lt "$_ready" ]]; then
        _log "ERROR: something nasty is happening. number of ready agents just decreased by $((_ready - _new_ready))"
        exit 1
    fi

    if [[ "$_new_ready" -ne "$_ready" ]]; then
        _log "Ready: $_new_ready"
        _ready=$_new_ready
    fi

    _statuses=$(jq -r '[.[] | select(.status != "READY_FOR_TEST")] | map("| \(.name): \(.status) |") | join("")' <<<"$_agents")
    _msg_level=$((2 - (_iteration % 6 == 0) - (_iteration % 3 == 0)))
    _logv "$_msg_level" "Waiting for $((VAR_AGENTS_CNT - _ready)) agent(s)..."
    _logv "$_msg_level" "$_statuses"
    _logv "$_msg_level" ""

    sleep "$_TICK"
done

_log_pop_stage 2
_log_stage "[WAIT_FAILED]"
_log "Timeout exceeded: waited for ${_elapsed} while timeout is ${_TIMEOUT}s"
_log "Last statuses: ${_statuses:-unknown}"

exit 1
