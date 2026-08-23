#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
formula_path="${repo_root}/Formula/tardigrade.rb"
tap_name="${TAP_NAME:-Bare-Systems/tap}"

ruby -c "$formula_path"

if grep -qE 'releases/download/v0\.5\.0|version "0\.5\.0"' "$formula_path"; then
    echo "Formula must not reference the pre-native v0.5.0 release as installable" >&2
    exit 1
fi

if grep -qE '^[[:space:]]*url "' "$formula_path"; then
    formula_state="release"
else
    formula_state="preparatory"
fi

if [ "$formula_state" = "preparatory" ]; then
    if ! grep -q "No release-backed native Tardigrade Homebrew formula has been published yet" "$formula_path"; then
        echo "Preparatory formula must fail explicitly during install" >&2
        exit 1
    fi

    if grep -qE 'sha256 "|depends_on "openssl@3"|lib(?:ssl|crypto)' "$formula_path"; then
        echo "Preparatory formula must not carry release checksums or OpenSSL runtime references" >&2
        exit 1
    fi

    echo "Validated preparatory Tardigrade formula state"
    exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to validate a release-backed formula" >&2
    exit 1
fi

formula_installed=false
tap_added=false
tmpdir=""
pid=""

# shellcheck disable=SC2317,SC2329 # invoked by trap
cleanup() {
    if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    fi
    if [ "$formula_installed" = true ]; then
        brew uninstall --formula "$tap_name/tardigrade" >/dev/null 2>&1 || true
    fi
    if [ "$tap_added" = true ]; then
        brew untap "$tap_name" >/dev/null 2>&1 || true
    fi
    [ -z "$tmpdir" ] || rm -rf "$tmpdir"
}
trap cleanup EXIT

os="$(uname -s)"
machine="$(uname -m)"

case "$os:$machine" in
    Linux:x86_64)
        platform_block='on_linux'
        arch_block='on_intel'
        ;;
    Linux:aarch64|Linux:arm64)
        platform_block='on_linux'
        arch_block='on_arm'
        ;;
    Darwin:x86_64)
        platform_block='on_macos'
        arch_block='on_intel'
        ;;
    Darwin:arm64)
        platform_block='on_macos'
        arch_block='on_arm'
        ;;
    *)
        echo "No Homebrew validation runner mapping for ${os}/${machine}; skipping install smoke"
        exit 0
        ;;
esac

if ! awk -v platform="$platform_block" -v arch="$arch_block" '
    $0 == "  " platform " do" { in_platform = 1; next }
    in_platform && $0 == "    " arch " do" { in_arch = 1; next }
    in_arch && /^[[:space:]]*url "/ { found = 1 }
    in_arch && $0 == "    end" { in_arch = 0 }
    in_platform && $0 == "  end" { in_platform = 0 }
    END { exit found ? 0 : 1 }
' "$formula_path"; then
    echo "Formula does not advertise ${os}/${machine}; skipping install smoke"
    exit 0
fi

brew tap "$tap_name" "$repo_root"
tap_added=true
brew audit --formula "$tap_name/tardigrade"
brew install "$tap_name/tardigrade"
formula_installed=true
brew test "$tap_name/tardigrade"

tardi_bin="$(brew --prefix)/bin/tardi"
tardigrade_bin="$(brew --prefix)/bin/tardigrade"

test -x "$tardi_bin"
test -x "$tardigrade_bin"

"$tardi_bin" version
"$tardigrade_bin" version

if [ "$(readlink "$tardigrade_bin" 2>/dev/null || true)" != "tardi" ] &&
    [ "$(realpath "$tardigrade_bin")" != "$(realpath "$tardi_bin")" ]; then
    echo "tardigrade compatibility command does not resolve to tardi" >&2
    exit 1
fi

version_output="$("$tardi_bin" version)"
printf '%s\n' "$version_output"
printf '%s\n' "$version_output" | grep -q 'tls-profile=native'
printf '%s\n' "$version_output" | grep -q 'tls-backend=native'

case "$os" in
    Linux)
        linked_libraries="$(ldd "$tardi_bin")"
        printf '%s\n' "$linked_libraries"
        if printf '%s\n' "$linked_libraries" | grep -E 'lib(ssl|crypto)\.so'; then
            echo "Installed tardi links OpenSSL on Linux" >&2
            exit 1
        fi
        ;;
    Darwin)
        linked_libraries="$(otool -L "$tardi_bin")"
        printf '%s\n' "$linked_libraries"
        if printf '%s\n' "$linked_libraries" | grep -E 'lib(ssl|crypto)|openssl'; then
            echo "Installed tardi links OpenSSL on macOS" >&2
            exit 1
        fi
        ;;
esac

tmpdir="$(mktemp -d)"
mkdir -p "$tmpdir/public"
printf 'ok\n' > "$tmpdir/public/index.html"

port="${TARDIGRADE_SMOKE_PORT:-18089}"
cat > "$tmpdir/tardigrade.conf" <<EOF
listen ${port};
server_name localhost;

root ${tmpdir}/public;

location = /health {
    return 200 ok;
}
EOF

"$tardi_bin" check "$tmpdir/tardigrade.conf"
"$tardi_bin" run -c "$tmpdir/tardigrade.conf" &
pid="$!"

for _ in $(seq 1 20); do
    if response="$(curl -fsS -H 'Host: localhost' "http://127.0.0.1:${port}/health" 2>/dev/null)"; then
        if [ "$response" = "ok" ]; then
            echo "Validated release-backed Tardigrade formula"
            exit 0
        fi
        echo "Unexpected smoke response: $response" >&2
        exit 1
    fi
    sleep 1
done

echo "Timed out waiting for Tardigrade smoke endpoint" >&2
exit 1
