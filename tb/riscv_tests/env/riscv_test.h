// Environment: riscv_test
// Description: Minimal M-mode environment for running upstream riscv-tests on this core.
#ifndef RHBYV_RISCV_TEST_H
#define RHBYV_RISCV_TEST_H

#include "encoding.h"

#define RVTEST_RV64M                                                    \
  .macro init;                                                          \
  .endm

#define RVTEST_RV32M                                                    \
  .macro init;                                                          \
  .endm

#define INIT_XREG                                                       \
  li x1, 0;                                                             \
  li x2, 0;                                                             \
  li x3, 0;                                                             \
  li x4, 0;                                                             \
  li x5, 0;                                                             \
  li x6, 0;                                                             \
  li x7, 0;                                                             \
  li x8, 0;                                                             \
  li x9, 0;                                                             \
  li x10, 0;                                                            \
  li x11, 0;                                                            \
  li x12, 0;                                                            \
  li x13, 0;                                                            \
  li x14, 0;                                                            \
  li x15, 0;                                                            \
  li x16, 0;                                                            \
  li x17, 0;                                                            \
  li x18, 0;                                                            \
  li x19, 0;                                                            \
  li x20, 0;                                                            \
  li x21, 0;                                                            \
  li x22, 0;                                                            \
  li x23, 0;                                                            \
  li x24, 0;                                                            \
  li x25, 0;                                                            \
  li x26, 0;                                                            \
  li x27, 0;                                                            \
  li x28, 0;                                                            \
  li x29, 0;                                                            \
  li x30, 0;                                                            \
  li x31, 0

#define RVTEST_CODE_BEGIN                                               \
  .section .text.init;                                                  \
  .align 6;                                                             \
  .option norvc;                                                        \
  .weak mtvec_handler;                                                  \
  .globl _start;                                                        \
_start:                                                                 \
  j reset_vector;                                                       \
  .align 2;                                                             \
trap_vector:                                                            \
  la t5, mtvec_handler;                                                 \
  beqz t5, unexpected_trap;                                             \
  jr t5;                                                                \
unexpected_trap:                                                        \
  li TESTNUM, 0x7ff;                                                    \
  RVTEST_FAIL;                                                          \
reset_vector:                                                           \
  INIT_XREG;                                                            \
  li TESTNUM, 0;                                                        \
  la t0, trap_vector;                                                   \
  csrw mtvec, t0;                                                       \
  init

#define RVTEST_CODE_END                                                 \
  .word 0

#define TESTNUM gp

#define RVTEST_PASS                                                     \
  fence;                                                                \
  li t5, 0x10000000;                                                    \
  li t6, 1;                                                             \
  sw t6, 0(t5);                                                         \
1:                                                                      \
  j 1b

#define RVTEST_FAIL                                                     \
  fence;                                                                \
  bnez TESTNUM, 1f;                                                     \
  li TESTNUM, 1;                                                        \
1:                                                                      \
  slli TESTNUM, TESTNUM, 1;                                             \
  ori TESTNUM, TESTNUM, 1;                                              \
  li t5, 0x10000000;                                                    \
  sw TESTNUM, 0(t5);                                                    \
1:                                                                      \
  j 1b

#define RVTEST_DATA_BEGIN                                               \
  .section .data;                                                       \
  .align 4;                                                             \
  .global begin_signature;                                              \
begin_signature:

#define RVTEST_DATA_END                                                 \
  .align 4;                                                             \
  .global end_signature;                                                \
end_signature:

#endif
