################################################################################
#
# Makefile project only supported on Linux Platforms)
#
################################################################################
PROJECT := mysgemm
# Location of the CUDA Toolkit
CUDA_PATH       ?= /usr/local/cuda
BUILD_PATH      ?= build

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
CCFLAGS     := -MMD -MP -pthread -fPIC -DNDEBUG -O2 -DUSE_OPENCV 
LDFLAGS     :=

# Debug build flags
ifeq ($(dbg),1)
      NVCCFLAGS += -g -G
      BUILD_TYPE := debug
      $(warning Open dbg mode)
else
      BUILD_TYPE := release
endif

ALL_NVCCFLAGS += $(NVCCFLAGS) $(EXTRA_NVCCFLAGS)
ALL_CCFLAGS += $(addprefix -Xcompiler ,$(CCFLAGS))
ALL_CCFLAGS += $(addprefix -Xcompiler ,$(EXTRA_CCFLAGS))

ALL_LDFLAGS :=
ALL_LDFLAGS += $(ALL_CCFLAGS) $(ALL_NVCCFLAGS) 
ALL_LDFLAGS += $(addprefix -Xlinker ,$(LDFLAGS))
ALL_LDFLAGS += $(addprefix -Xlinker ,$(EXTRA_LDFLAGS))

SHARE_LDFLAGS := -shared -lc
SHARE_LDFLAGS += $(addprefix -Xlinker ,$(LDFLAGS))
SHARE_LDFLAGS += $(addprefix -Xlinker ,$(EXTRA_LDFLAGS))
# Common includes and paths for CUDA
INCLUDES  := -Iinc
LIBRARIES :=

################################################################################

SAMPLE_ENABLED := 1

# Gencode arguments
SMS ?= 50 

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
ALL_NVCCFLAGS += -dc

LIBRARIES += -lcublas -lcublas_device -lcudadevrt

ifeq ($(SAMPLE_ENABLED),0)
EXEC ?= @echo "[@]"
endif

SRC_PATH := src
GPU_SRCS += $(wildcard $(SRC_PATH)/*.cu)
CPU_SRCS += $(wildcard $(SRC_PATH)/*.cpp)
CPU_OBJS := $(addprefix $(BUILD_PATH)/$(BUILD_TYPE)/, ${CPU_SRCS:.cpp=.o})
GPU_OBJS := $(addprefix $(BUILD_PATH)/$(BUILD_TYPE)/, ${GPU_SRCS:.cu=.o})
OBJS := $(CPU_OBJS) $(GPU_OBJS)
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
	$(EXEC) mkdir -p $(BUILD_PATH)/$(BUILD_TYPE)/$(SRC_PATH)/cu

$(BUILD_PATH)/$(BUILD_TYPE)/%.o: %.cpp | CREATE_BUILD_PATH
	$(EXEC) $(HOST_COMPILER) $(INCLUDES) $(CCFLAGS) -o $@ -c $<

$(BUILD_PATH)/$(BUILD_TYPE)/%.o: %.cu | CREATE_BUILD_PATH
	$(EXEC) $(NVCC) $(INCLUDES) $(ALL_NVCCFLAGS) $(GENCODE_FLAGS) -o $@ -c $<

clean:
	rm -rf $(BUILD_PATH)

