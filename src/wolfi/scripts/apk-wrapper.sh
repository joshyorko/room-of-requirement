#!/usr/bin/env bash
set -euo pipefail

apk_real="${ROR_APK_REAL:-/sbin/apk.real}"
apk_world="${ROR_APK_WORLD:-/etc/apk/world}"

sed -i '/^gcompat\([=<>~].*\)\?$/d' "${apk_world}" 2>/dev/null || true

command_name=""
command_index=-1
skip_option_value=0
arguments=("$@")

for index in "${!arguments[@]}"; do
    argument="${arguments[${index}]}"
    if [ "${skip_option_value}" -eq 1 ]; then
        skip_option_value=0
        continue
    fi
    case "${argument}" in
        --root | --keys-dir | --repositories-file | --arch | --cache-dir | --wait | --timeout | --repository | -p | -X)
            skip_option_value=1
            ;;
        -* )
            ;;
        *)
            command_name="${argument}"
            command_index="${index}"
            break
            ;;
    esac
done

if [ "${command_name}" != "add" ]; then
    exec "${apk_real}" "$@"
fi

filtered_arguments=()
package_count=0
skip_option_value=0

for index in "${!arguments[@]}"; do
    argument="${arguments[${index}]}"
    if [ "${index}" -le "${command_index}" ]; then
        filtered_arguments+=("${argument}")
        continue
    fi
    if [ "${skip_option_value}" -eq 1 ]; then
        filtered_arguments+=("${argument}")
        skip_option_value=0
        continue
    fi
    case "${argument}" in
        --repository | --virtual | --arch | --root | --keys-dir | --repositories-file | --cache-dir | --wait | --timeout | -X | -t | -p)
            filtered_arguments+=("${argument}")
            skip_option_value=1
            ;;
        -* )
            filtered_arguments+=("${argument}")
            ;;
        gcompat | gcompat[=\<\>\~]*)
            ;;
        *)
            filtered_arguments+=("${argument}")
            package_count=$((package_count + 1))
            ;;
    esac
done

if [ "${package_count}" -eq 0 ]; then
    exit 0
fi

exec "${apk_real}" "${filtered_arguments[@]}"
