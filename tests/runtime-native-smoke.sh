#!/usr/bin/env bash
# Run with a built Wolfi image argument; no pull, install, entrypoint or daemon.
set -euo pipefail

if [ "${1:-}" != "--in-container" ]; then
    image="${1:-${ROR_NATIVE_TEST_IMAGE:-}}"
    if [ -z "${image}" ]; then
        echo 'SKIP: native smoke requires a built Wolfi image argument (or ROR_NATIVE_TEST_IMAGE)'
        [ "${ROR_REQUIRE_NATIVE_SMOKE:-0}" != "1" ]
        exit "$?"
    fi
    script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    exec docker run --rm --pull never --network none --read-only \
        --tmpfs /tmp:rw,exec,nosuid --entrypoint bash \
        --mount "type=bind,source=${script},target=/ror-native-smoke.sh,readonly" \
        "${image}" /ror-native-smoke.sh --in-container
fi

fixture="$(mktemp -d /tmp/ror-native-smoke.XXXXXX)"
trap 'rm -rf "${fixture}"' EXIT
cd "${fixture}"
mkdir include lib

# Project only these two dependencies into scratch space for negative controls.
# Their targets remain the image's real header and repaired linker name.
ffi_include="$(/usr/bin/pkg-config --variable=includedir libffi)"
ln -s "${ffi_include}/ffi.h" include/required-ffi.h
ln -s /usr/lib/libruby.so lib/libruby.so

cat > native.c <<'C'
#include <stdio.h>
#include <required-ffi.h>
#include <ncurses.h>
#include <openssl/ssl.h>
#include <readline/readline.h>
#include <yaml.h>
#include <zlib.h>
#include <ruby.h>

int main(int argc, char **argv) {
    ffi_cif cif;
    if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 0, &ffi_type_void, NULL) != FFI_OK) return 1;
    SSL_CTX *context = SSL_CTX_new(TLS_method());
    if (!context) return 2;
    SSL_CTX_free(context);
    if (!curses_version() || rl_readline_version <= 0 || !zlibVersion()) return 3;
    yaml_parser_t parser;
    if (!yaml_parser_initialize(&parser)) return 4;
    yaml_parser_delete(&parser);
    ruby_sysinit(&argc, &argv);
    RUBY_INIT_STACK;
    ruby_init();
    if (NUM2INT(rb_eval_string("40 + 2")) != 42) return 5;
    if (ruby_cleanup(0) != 0) return 6;
    puts("native headers, FFI, curses, OpenSSL, readline, YAML, zlib and Ruby link/runtime OK");
    return 0;
}
C

mapfile -t ruby_headers < <(/usr/bin/ruby -rrbconfig -e \
    'puts RbConfig::CONFIG.values_at("rubyhdrdir", "rubyarchhdrdir")')
read -r -a native_flags <<< "$(/usr/bin/pkg-config --cflags --libs libffi ncursesw openssl readline yaml-0.1 zlib)"

compile() {
    /usr/bin/gcc -Werror=implicit-function-declaration \
        -I "${fixture}/include" -I "${ruby_headers[0]}" -I "${ruby_headers[1]}" \
        native.c "${native_flags[@]}" "$@" -o native-check
}

# Exercise ordinary gem-style -lruby resolution as well as the exact repaired
# name, so a missing linker symlink cannot be hidden by versioned-library flags.
compile -lruby
./native-check
compile "${fixture}/lib/libruby.so"
./native-check

# The same compile must fail if the required FFI header or unversioned Ruby
# link is removed from the scratch projection. No image files are modified.
unlink include/required-ffi.h
if compile "${fixture}/lib/libruby.so" > missing-header.log 2>&1; then
    echo 'FAIL: native probe accepted a missing FFI header' >&2
    exit 1
fi
grep -Fq 'required-ffi.h' missing-header.log
ln -s "${ffi_include}/ffi.h" include/required-ffi.h
unlink lib/libruby.so
if compile "${fixture}/lib/libruby.so" > missing-link.log 2>&1; then
    echo 'FAIL: native probe accepted a missing unversioned Ruby linker name' >&2
    exit 1
fi
grep -Fq 'libruby.so' missing-link.log
echo 'native negative controls rejected the missing header and Ruby linker name'
