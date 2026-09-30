#!/usr/bin/env bash
set +x +e

declare -A EXIT_CODES=(
    [SUCCESS]=0
    [UNSUPPORTED_SHELL]=1
    [ENTER_PROJECT_ROOT_FAILED]=2
    [EXIT_PROJECT_ROOT_FAILED]=3
    [DIST_FOLDER_CREATION_FAILED]=4
    [DATAPACK_GENERATION_FAILED]=5
    [VERSION_NOT_SUPPLIED]=6
    [USER_ABORTED]=7
    [UNKNOWN_ERROR]=8
    [KILLED]=9
)

declare -A EXIT_MESSAGES=(
    [SUCCESS]="Successfully generated datapack!"
    [UNSUPPORTED_SHELL]="Unsupported shell! Please use bash, ksh93, or zsh."
    [ENTER_PROJECT_ROOT_FAILED]="Failed to enter project root directory \"%b%s%b\"!"
    [EXIT_PROJECT_ROOT_FAILED]="Failed to exit project root directory \"%b%s%b\"!"
    [DIST_FOLDER_CREATION_FAILED]="Failed to generate distribution folder \"%b%s%b\"!"
    [DATAPACK_GENERATION_FAILED]="Failed to generate datapack!"
    [VERSION_NOT_SUPPLIED]="Version not supplied!"
    [USER_ABORTED]="User aborted!"
    [UNKNOWN_ERROR]="Unknown error (code \"%b%d%b\") occurred!"
    [KILLED]="Script is being killed by user!"
)

SCRIPT_DIR="$( (
    function get_script_dir() {
        pushd . 2>&1 > /dev/null || return 1
        local SCRIPT_PATH
        if [[ -n "${BASH}" ]]; then
            # shellcheck disable=SC2128
            SCRIPT_PATH="${BASH_SOURCE}"
        elif [[ -n "${ZSH_VERSION}" ]]; then
            # shellcheck disable=SC2296
            SCRIPT_PATH="${(%):-%x}"
        elif [[ -n "${TMOUT}" ]]; then
            # shellcheck disable=SC2296
            SCRIPT_PATH="${.sh.file}"
        elif [[ "${0##*/}" == "dash" ]]; then
            local x
            x="$(lsof -p $$ -Fn0 | tail -1)"
            # shellcheck disable=SC2296
            SCRIPT_PATH="${x#n}"
        else
            printf '\e[38;5;196m[ERROR]\e[0m %s' "${EXIT_MESSAGES[UNSUPPORTED_SHELL]}" 1>&2
            # shellcheck disable=SC2086
            return ${EXIT_CODES[UNSUPPORTED_SHELL]}
        fi
        while [[ -L "${SCRIPT_PATH}" ]]; do
            cd "$(dirname -- "${SCRIPT_PATH}")" || return 2
            SCRIPT_PATH="$(readlink -e -- "$SCRIPT_PATH")"
        done
        cd "$(dirname -- "$SCRIPT_PATH")" > /dev/null || return 2
        SCRIPT_PATH="$(pwd)"
        popd 2>&1 > /dev/null || return 3
        echo "${SCRIPT_PATH}"
        return 0
    }
    get_script_dir
))"

_LIB_PATH="$(readlink -e -- "${SCRIPT_DIR}/lib/")"

# shellcheck source=./lib/boolean.sh
source "${_LIB_PATH}/boolean.sh"
# shellcheck source=./lib/logging.sh
source "${_LIB_PATH}/logging.sh"
# shellcheck source=./lib/io.sh
source "${_LIB_PATH}/io.sh"

# shellcheck disable=SC2329
function kill_handler() {
    printf "\n"
    lib::logging::error "${EXIT_MESSAGES[KILLED]}"
    lib::logging::failure "Failed!"
    # shellcheck disable=SC2086
    exit ${EXIT_CODES[KILLED]}
}

trap kill_handler QUIT TERM INT HUP

# -- The path to the project root directory
PROJECT_ROOT="$(readlink -e -- "${SCRIPT_DIR}/../")"

# -- The path to the folder to place the built datapack in
DIST_FOLDER="$(readlink -f -- "${PROJECT_ROOT}/dist/")"

# -- The default version tag to label the built pack with
DEFAULT_VERSION="$(git describe --tags 2> /dev/null)"

if [[ "$*" == *"--verbose"* ]]; then
    VERBOSE=${TRUE}
    lib::logging::verbose "Verbose logging enabled!"
fi

if [[ -n "${VERSION}" ]]; then
    lib::logging::verbose "Version provided via environment variable, using version \"%b%s%b\" as is..." \
        "<eval lib::sgr::4bit_fg 36/>" "${VERSION}" "<eval lib::sgr::reset/>"
elif [[ "$*" == *"--version"* || "$*" == *"--version="* ]]; then
    VERSION="$(sed -E 's/(.*(--version(=|[[:space:]])([^[:space:]]+)).*)/\4/' <<< "$*")"
    lib::logging::verbose "Version provided via CLI parameter, using version \"%b%s%b\"..." \
        "<eval lib::sgr::4bit_fg 36/>" "${VERSION}" "<eval lib::sgr::reset/>"
elif [[ -n "${DEFAULT_VERSION}" ]]; then
    VERSION="${DEFAULT_VERSION}"
    lib::logging::verbose "Version not provided, using default Git version tag \"%b%s%b\"..." \
        "<eval lib::sgr::4bit_fg 36/>" "${VERSION}" "<eval lib::sgr::reset/>"
else
    lib::logging::error "${EXIT_MESSAGES[VERSION_NOT_SUPPLIED]}"
    lib::logging::failure "Failed!"
    # shellcheck disable=SC2086
    exit ${EXIT_CODES[VERSION_NOT_SUPPLIED]}
fi

lib::logging::info "Starting datapack generation..."

lib::logging::verbose 'Preparing distribution folder "%b%s%b"...' \
    "<eval lib::sgr::4bit_fg 36/>" "${DIST_FOLDER}" "<eval lib::sgr::reset/>"

# shellcheck disable=SC2164
pushd "${PROJECT_ROOT}" > /dev/null 2>&1
RESULT=$?
if [[ $RESULT -ne 0 ]]; then
    lib::logging::error "${EXIT_MESSAGES[ENTER_PROJECT_ROOT_FAILED]}" \
        "<eval lib::sgr::4bit_fg 36/>" "${PROJECT_ROOT}" "<eval lib::sgr::reset/>"
    lib::logging::error "Failed with error code \"%b%d%b\"!" \
        "<eval lib::sgr::4bit_fg 91/>" "${RESULT}" "<eval lib::sgr::reset/>"
    lib::logging::failure "Failed!"
    # shellcheck disable=SC2086
    exit ${EXIT_CODES[ENTER_PROJECT_ROOT_FAILED]}
fi

if [[ -d "${DIST_FOLDER}" ]]; then
    lib::logging::verbose 'Distribution folder "%b%s%b" already exists, not creating...' \
        "<eval lib::sgr::4bit_fg 36/>" "${DIST_FOLDER}" "<eval lib::sgr::reset/>"
else
    mkdir -p "${DIST_FOLDER}" > /dev/null 2>&1
    RESULT=$?
    if [[ ${RESULT} -ne 0 ]]; then
        lib::logging::error "${EXIT_MESSAGES[DIST_FOLDER_CREATION_FAILED]}" \
            "<eval lib::sgr::4bit_fg 36/>" "${DIST_FOLDER}" "<eval lib::sgr::reset/>"
        lib::logging::error "Failed with error code \"%b%d%b\"!" \
            "<eval lib::sgr::4bit_fg 91/>" "${RESULT}" "<eval lib::sgr::reset/>"
        lib::logging::failure "Failed!"
        # shellcheck disable=SC2086
        exit "${EXIT_CODES[DIST_FOLDER_CREATION_FAILED]}"
    fi
fi

ARCHIVE_NAME="${DIST_FOLDER}/$(basename "${PROJECT_ROOT}")-${VERSION}.zip"

if [[ -f "${ARCHIVE_NAME}" ]]; then
    lib::io::prompt_to_continue "Existing datapack build found, do you want to overwrite it?" "y"
    RESULT=$?
    if [[ $RESULT -eq 1 ]]; then
        lib::logging::error "${EXIT_MESSAGES[USER_ABORTED]}"
        lib::logging::failure "Failed!"
        # shellcheck disable=SC2086
        exit "${EXIT_CODES[USER_ABORTED]}"
    elif [[ $RESULT -eq 0 ]]; then
        lib::logging::info "Proceeding..."
    else
        lib::logging::error "${EXIT_MESSAGES[UNKNOWN_ERROR]}" \
            "<eval lib::sgr::4bit_fg 91/>" "${RESULT}" "<eval lib::sgr::reset/>"
        lib::logging::failure "Failed!"
        # shellcheck disable=SC2086
        exit "${EXIT_CODES[UNKNOWN_ERROR]}"
    fi
fi

zip -9 -ll -UN=UTF8 -r "${DIST_FOLDER}/$(basename "${PROJECT_ROOT}")-${VERSION}.zip" \
    "$(realpath -E --relative-to="${PROJECT_ROOT}" -- "${PROJECT_ROOT}/data/")" \
    "$(realpath -E --relative-to="${PROJECT_ROOT}" -- "${PROJECT_ROOT}/pack.mcmeta")" \
    "$(realpath -E --relative-to="${PROJECT_ROOT}" -- "${PROJECT_ROOT}/pack.png")"

# shellcheck disable=SC2164
popd > /dev/null 2>&1
if [[ $RESULT -ne 0 ]]; then
    lib::logging::error "${EXIT_MESSAGES[EXT_PROJECT_ROOT_FAILED]}" \
        "<eval lib::sgr::4bit_fg 36/>" "${PROJECT_ROOT}" "<eval lib::sgr::reset/>"
    lib::logging::error "Failed with error code \"%b%d%b\"!" \
        "<eval lib::sgr::4bit_fg 91/>" "${RESULT}" "<eval lib::sgr::reset/>"
    lib::logging::failure "Failed!"
    # shellcheck disable=SC2086
    exit ${EXIT_CODES[EXT_PROJECT_ROOT_FAILED]}
fi

lib::logging::info "${EXIT_MESSAGES[SUCCESS]}"
lib::logging::success "Success!"
# shellcheck disable=SC2086
exit ${EXIT_CODES[SUCCESS]}
