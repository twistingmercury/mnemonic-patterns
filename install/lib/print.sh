# shellcheck shell=bash

print::info() {
    local message="${1}"
    printf "[INFO] %s\n" "${message}"
}

print::success() {
    local message="${1}"
    printf "[SUCCESS] %s\n" "${message}"
}

print::error() {
    local message="${1}"
    printf "[ERROR] %s\n" "${message}" >&2
}

print::warning() {
    local message="${1}"
    printf "[WARNING] %s\n" "${message}"
}
