#!/usr/bin/env bash
set -euo pipefail

xlen="${1:-32}"
tests_root="${RISCV_TESTS_DIR:-riscv-tests}"
tool_root="${RISCV_TOOL_ROOT:-/opt/riscv/bin}"
tool_prefix="${tool_root}/riscv64-unknown-elf-"
build_root="build/riscv-tests/rv${xlen}"
sim_dir="build/verilator/riscv-tests-rv${xlen}"
export CCACHE_TEMPDIR="${PWD}/build/ccache-tmp"
export CCACHE_DIR="${PWD}/build/ccache"

if [[ "${xlen}" == "32" ]]; then
    march="rv32i_zicsr"
    mabi="ilp32"
    tests=(csr illegal scall sbreak mcsr ma_addr lh-misaligned lw-misaligned sh-misaligned sw-misaligned)
else
    march="rv64i_zicsr"
    mabi="lp64"
    tests=(csr illegal scall sbreak mcsr ma_addr lh-misaligned lw-misaligned ld-misaligned sh-misaligned sw-misaligned sd-misaligned instret_overflow)
fi

mkdir -p "${CCACHE_TEMPDIR}" "${CCACHE_DIR}" "${build_root}" "${sim_dir}" logs

verilator -Wall -Wno-fatal --timing --binary \
    -DCORE_XLEN="${xlen}" \
    -Mdir "${sim_dir}" \
    -f scripts/sim_files.f \
    tb/riscv_tests/tb_riscv_test.sv \
    --top-module tb_riscv_test \
    >"logs/riscv-tests-build-rv${xlen}.log" 2>&1

failures=0
for test_name in "${tests[@]}"; do
    test_dir="${build_root}/${test_name}"
    source_file="${tests_root}/isa/rv${xlen}mi/${test_name}.S"
    mkdir -p "${test_dir}"

    "${tool_prefix}gcc" \
        -march="${march}" -mabi="${mabi}" -mcmodel=medany \
        -nostdlib -nostartfiles -static -no-pie \
        -I tb/riscv_tests/env \
        -I "${tests_root}/env" \
        -I "${tests_root}/isa/macros/scalar" \
        -Wl,--no-relax -Wl,-T,tb/riscv_tests/env/link.ld \
        -Wl,-Map,"${test_dir}/${test_name}.map" \
        "${source_file}" -o "${test_dir}/${test_name}.elf" \
        >"logs/riscv-${test_name}-rv${xlen}-compile.log" 2>&1

    "${tool_prefix}objcopy" -O verilog --verilog-data-width 1 \
        --only-section=.text "${test_dir}/${test_name}.elf" "${test_dir}/imem.vhex"
    "${tool_prefix}objcopy" -O verilog --verilog-data-width 1 \
        --only-section=.data "${test_dir}/${test_name}.elf" "${test_dir}/dmem.vhex"
    python3 scripts/verilator/verilog_hex_to_mem.py \
        "${test_dir}/imem.vhex" "${test_dir}/imem.hex" --word-bytes 4
    python3 scripts/verilator/verilog_hex_to_mem.py \
        "${test_dir}/dmem.vhex" "${test_dir}/dmem.hex" --word-bytes "$((xlen / 8))"
    "${tool_prefix}objdump" -d "${test_dir}/${test_name}.elf" >"${test_dir}/${test_name}.dump"

    run_log="logs/riscv-${test_name}-rv${xlen}.log"
    if "${sim_dir}/Vtb_riscv_test" \
        +IMEM="${test_dir}/imem.hex" \
        +DMEM="${test_dir}/dmem.hex" \
        +TEST="${test_name}" >"${run_log}" 2>&1; then
        grep "PASS ${test_name}" "${run_log}" | tail -n 1
    else
        failures=$((failures + 1))
        tail -n 8 "${run_log}"
    fi
done

if ((failures != 0)); then
    echo "FAIL riscv-tests RV${xlen}: ${failures}/${#tests[@]}"
    exit 1
fi
echo "PASS riscv-tests RV${xlen}: ${#tests[@]}/${#tests[@]}"
