#!/usr/bin/env bash
set -euo pipefail

codex_home="${CODEX_HOME:-${HOME}/.codex}"
config_file="${codex_home}/config.toml"
default_config="/usr/local/share/synapse-sandbox-codex.config.toml"

mkdir -p "${codex_home}"

if [[ ! -s "${config_file}" ]]; then
	rm -f "${config_file}"
	install -m 0600 "${default_config}" "${config_file}"
fi

if [[ ! -w "${config_file}" ]]; then
	echo "sandbox: ${config_file} must be writable so Codex can save trust and settings" >&2
	exit 1
fi

exec "$@"
