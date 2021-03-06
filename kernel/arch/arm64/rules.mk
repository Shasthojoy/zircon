# Copyright 2016 The Fuchsia Authors
# Copyright (c) 2008-2015 Travis Geiselbrecht
#
# Use of this source code is governed by a MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT

LOCAL_DIR := $(GET_LOCAL_DIR)

MODULE := $(LOCAL_DIR)

MODULE_SRCS += \
	$(LOCAL_DIR)/arch.cpp \
	$(LOCAL_DIR)/asm.S \
	$(LOCAL_DIR)/boot-mmu.cpp \
	$(LOCAL_DIR)/cache-ops.S \
	$(LOCAL_DIR)/debugger.cpp \
	$(LOCAL_DIR)/exceptions.S \
	$(LOCAL_DIR)/exceptions_c.cpp \
	$(LOCAL_DIR)/feature.cpp \
	$(LOCAL_DIR)/fpu.cpp \
	$(LOCAL_DIR)/header.S \
	$(LOCAL_DIR)/mexec.S \
	$(LOCAL_DIR)/mmu.cpp \
	$(LOCAL_DIR)/spinlock.cpp \
	$(LOCAL_DIR)/start.S \
	$(LOCAL_DIR)/sysreg.cpp \
	$(LOCAL_DIR)/thread.cpp \
	$(LOCAL_DIR)/user_copy.S \
	$(LOCAL_DIR)/user_copy_c.cpp \
	$(LOCAL_DIR)/uspace_entry.S

MODULE_DEPS += \
	kernel/dev/iommu/dummy \
	kernel/object \
	third_party/lib/fdt \

KERNEL_DEFINES += \
	ARM_ISA_ARMV8=1 \
	ARM_ISA_ARMV8A=1

# unless otherwise specified, limit to 2 clusters and 8 CPUs per cluster
SMP_CPU_MAX_CLUSTERS ?= 2
SMP_CPU_MAX_CLUSTER_CPUS ?= 8

SMP_MAX_CPUS ?= 16

MODULE_SRCS += \
	$(LOCAL_DIR)/mp.cpp

KERNEL_DEFINES += \
	SMP_MAX_CPUS=$(SMP_MAX_CPUS) \
	SMP_CPU_MAX_CLUSTERS=$(SMP_CPU_MAX_CLUSTERS) \
	SMP_CPU_MAX_CLUSTER_CPUS=$(SMP_CPU_MAX_CLUSTER_CPUS) \

ARCH_OPTFLAGS := -O2

KERNEL_ASPACE_BASE ?= 0xffff000000000000
KERNEL_ASPACE_SIZE ?= 0x0001000000000000
USER_ASPACE_BASE   ?= 0x0000000001000000
USER_ASPACE_SIZE   ?= 0x0000fffffe000000

GLOBAL_DEFINES += \
	KERNEL_ASPACE_BASE=$(KERNEL_ASPACE_BASE) \
	KERNEL_ASPACE_SIZE=$(KERNEL_ASPACE_SIZE) \
	USER_ASPACE_BASE=$(USER_ASPACE_BASE) \
	USER_ASPACE_SIZE=$(USER_ASPACE_SIZE)

# kernel is linked to run at the arbitrary address of -4GB
KERNEL_BASE := 0xffffffff00000000
KERNEL_LOAD_OFFSET ?= 0

KERNEL_DEFINES += \
	KERNEL_BASE=$(KERNEL_BASE) \
	KERNEL_LOAD_OFFSET=$(KERNEL_LOAD_OFFSET)

# try to find the toolchain
include $(LOCAL_DIR)/toolchain.mk
TOOLCHAIN_PREFIX := $(ARCH_$(ARCH)_TOOLCHAIN_PREFIX)

ARCH_COMPILEFLAGS += $(ARCH_$(ARCH)_COMPILEFLAGS)

# generate code for the fairly generic cortex-a53
ARCH_COMPILEFLAGS += -mcpu=cortex-a53

CLANG_ARCH := aarch64
ifeq ($(call TOBOOL,$(USE_CLANG)),true)
GLOBAL_LDFLAGS += -m aarch64elf
GLOBAL_MODULE_LDFLAGS += -m aarch64elf
endif
GLOBAL_LDFLAGS += -z max-page-size=4096

# kernel hard disables floating point
KERNEL_COMPILEFLAGS += -mgeneral-regs-only
KERNEL_DEFINES += WITH_NO_FP=1

# See engine.mk.
KEEP_FRAME_POINTER_COMPILEFLAGS += -mno-omit-leaf-frame-pointer

KERNEL_COMPILEFLAGS += -fPIE -include kernel/include/hidden.h

ifeq ($(call TOBOOL,$(USE_CLANG)),true)

# Clang needs -mcmodel=kernel to tell it to use the right safe-stack ABI for
# the kernel.
KERNEL_COMPILEFLAGS += -mcmodel=kernel

# Clang now supports -fsanitize=safe-stack with -mcmodel=kernel.
KERNEL_COMPILEFLAGS += $(SAFESTACK)

endif

# tell the compiler to leave x18 alone so we can use it to point
# at the current cpu structure
KERNEL_COMPILEFLAGS += -ffixed-x18

include make/module.mk


# The EFI code is its own module because it needs special compilation flags.

MODULE := $(LOCAL_DIR).efi

MODULE_SRCS := $(LOCAL_DIR)/efi.cpp

MODULE_COMPILEFLAGS += $(NO_SAFESTACK)

include make/module.mk
