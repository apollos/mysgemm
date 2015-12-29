################################################################################
#
# Makefile project only supported on Linux Platforms)
#
################################################################################
PROJECT := libmysgemm
# Location of the CUDA Toolkit
CUDA_PATH       ?= /usr/local/cuda
BUILD_PATH      ?= build
SRC_PATH := src
TST_PATH := test
GPU_SRCS += $(wildcard $(SRC_PATH)/*.cu)
CPU_SRCS += $(wildcard $(SRC_PATH)/*.cpp)
TST_SRCS += $(wildcard $(TST_PATH)/*.cpp)

# architecture
HOST_ARCH   := $(shell uname -m)
TARGET_ARCH ?= $(HOST_ARCH)
ifneq (,$(filter $(TARGET_ARCH),x86_64 aarch64 ppc64le))
    TARGET_SIZE := 64
else
    $(error ERROR - unsupported value $(TARGET_ARCH) for TARGET_ARCH!)
endif
ifneq ($(TARGET_ARCH),$(HOST_ARCH))
    ifeq (,$(filter $(HOST_ARCH)-$(TARGET_ARCH),aarch64-armv7l x86_64-armv7l x86_64-aarch64 x86_64-ppc64le))
        $(error ERROR - cross compiling from $(HOST_ARCH) to $(TARGET_ARCH) is not supported!)
    endif
endif

# operating system
HOST_OS   := $(shell uname -s 2>/dev/null | tr "[:upper:]" "[:lower:]")
TARGET_OS ?= $(HOST_OS)
ifeq (,$(filter $(TARGET_OS),linux ))
    $(error ERROR - unsupported value $(TARGET_OS) for TARGET_OS!)
endif

# host compiler
ifneq ($(TARGET_ARCH),$(HOST_ARCH))
    ifeq ($(TARGET_ARCH),ppc64le)
        HOST_COMPILER ?= powerpc64le-linux-gnu-g++
    endif
endif
HOST_COMPILER ?= g++
NVCC          := $(CUDA_PATH)/bin/nvcc -ccbin=$(HOST_COMPILER)

# internal flags
NVCCFLAGS   := -m${TARGET_SIZE}
CCFLAGS     := -fPIC #-MMD -MP -pthread -fPIC -DNDEBUG -O2 -DUSE_OPENCV 
LDFLAGS     :=

# Debug build flags
ifeq ($(dbg),1)
      NVCCFLAGS += -g -G
      BUILD_TYPE := debug
      $(warning Open dbg mode)
else
      BUILD_TYPE := release
endif

ALL_CCFLAGS += $(NVCCFLAGS)
ALL_CCFLAGS += $(EXTRA_NVCCFLAGS)
ALL_CCFLAGS += $(addprefix -Xcompiler ,$(CCFLAGS))
ALL_CCFLAGS += $(addprefix -Xcompiler ,$(EXTRA_CCFLAGS))

ALL_LDFLAGS :=
ALL_LDFLAGS += $(ALL_CCFLAGS) 
ALL_LDFLAGS += $(addprefix -Xlinker ,$(LDFLAGS))
ALL_LDFLAGS += $(addprefix -Xlinker ,$(EXTRA_LDFLAGS))

SHARE_LDFLAGS := $(addprefix -Xcompiler ,-shared -lc)
SHARE_LDFLAGS += $(ALL_CCFLAGS)
SHARE_LDFLAGS += $(addprefix -Xlinker ,$(LDFLAGS))
SHARE_LDFLAGS += $(addprefix -Xlinker ,$(EXTRA_LDFLAGS))
# Common includes and paths for CUDA
INCLUDES  := -Iinc -I$(CUDA_PATH)/include
LIBRARIES :=

CPU_OBJS := $(addprefix $(BUILD_PATH)/$(BUILD_TYPE)/, ${CPU_SRCS:.cpp=.o})
TST_OBJS := $(addprefix $(BUILD_PATH)/$(BUILD_TYPE)/, ${TST_SRCS:.cpp=.o})
GPU_OBJS := $(addprefix $(BUILD_PATH)/$(BUILD_TYPE)/, ${GPU_SRCS:.cu=.o})
OBJS := $(CPU_OBJS) $(GPU_OBJS)
################################################################################

SAMPLE_ENABLED := 1

# Gencode arguments
SMS ?= 35 37 50 52

ifeq ($(SMS),)
$(info >>> WARNING - no SM architectures have been specified - waiving sample <<<)
SAMPLE_ENABLED := 0
endif

ifeq ($(GENCODE_FLAGS),)
# Generate SASS code for each SM architecture listed in $(SMS)
$(foreach sm,$(SMS),$(eval GENCODE_FLAGS += -gencode arch=compute_$(sm),code=sm_$(sm)))

# Generate PTX code from the highest SM architecture in $(SMS) to guarantee forward-compatibility
HIGHEST_SM := $(lastword $(sort $(SMS)))
ifneq ($(HIGHEST_SM),)
GENCODE_FLAGS += -gencode arch=compute_$(HIGHEST_SM),code=compute_$(HIGHEST_SM)
endif
endif

ALL_CCFLAGS += -dc
LIBRARIES += -lcublas -lcublas_device -lcudadevrt

ifeq ($(SAMPLE_ENABLED),0)
EXEC ?= @echo "[@]"
endif

################################################################################

# Target rules
all: build

build: $(OBJS) | CREATE_BUILD_PATH
	$(EXEC) $(NVCC) $(SHARE_LDFLAGS) $(GENCODE_FLAGS) -o $(BUILD_PATH)/$(BUILD_TYPE)/$(PROJECT).so $+ $(LIBRARIES)

check.deps:
ifeq ($(SAMPLE_ENABLED),0)
	@echo "Sample will be waived due to the above missing dependencies"
else
	@echo "Sample is ready - all dependencies have been met"
endif

CREATE_BUILD_PATH:
	$(EXEC) mkdir -p $(BUILD_PATH)/$(BUILD_TYPE)/$(SRC_PATH) $(BUILD_PATH)/$(BUILD_TYPE)/$(TST_PATH)

$(BUILD_PATH)/$(BUILD_TYPE)/%.o: %.cpp | CREATE_BUILD_PATH
#	$(EXEC) $(HOST_COMPILER) $(INCLUDES) $(CCFLAGS) -o $@ -c $<
	$(EXEC) $(NVCC) $(INCLUDES) $(ALL_CCFLAGS) $(GENCODE_FLAGS) -o $@ -c $<

$(BUILD_PATH)/$(BUILD_TYPE)/%.o: %.cu | CREATE_BUILD_PATH
	$(EXEC) $(NVCC) $(INCLUDES) $(ALL_CCFLAGS) $(GENCODE_FLAGS) -o $@ -c $<

test: $(TST_OBJS)| build
	$(EXEC) $(NVCC) $(ALL_LDFLAGS) $(GENCODE_FLAGS) -o $(BUILD_PATH)/$(BUILD_TYPE)/$@$(PROJECT) $+ $(LIBRARIES) -L./$(BUILD_PATH)/$(BUILD_TYPE) -lmysgemm
#	$(EXEC) $(NVCC) $(ALL_LDFLAGS) $(GENCODE_FLAGS) -o $(BUILD_PATH)/$(BUILD_TYPE)/$@$(PROJECT) $+ $(LIBRARIES) 

clean:
	$(EXEC) rm -rf $(BUILD_PATH)

