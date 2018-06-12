# Makefile for test

# Specify default directories
BUILD_DIR = build
BIN_DIR = bin
SRC_DIR = src

# Select target application and required object files
WINDOWS_TARGET = test.exe
LINUX_TARGET = test

OBJECTS = \
	test.obj
	
GLOBAL_DEFINES = 

RELEASE_DEFINES = \
	RELEASE \
	_RELEASE

DEBUG_DEFINES = \
	DEBUG \
	_DEBUG

PROFILE_DEFINES = \
	PROFILE \
	_PROFILE

INCLUDES = \

CC = nvcc

# Get compiler versions
# Find nvcc version using sed.
# NVCC_VSTRING = $(shell ""$(CC)"" --version | sed -n -r 's/.*(V([0-9]+).([0-9]+).([0-9]+))/\2/p')
NVCC_MAJOR = $(shell ""$(CC)"" --version | sed -n -r 's/.*(V([0-9]+).([0-9]+).([0-9]+))/\2/p')
NVCC_MINOR = $(shell ""$(CC)"" --version | sed -n -r 's/.*(V([0-9]+).([0-9]+).([0-9]+))/\3/p')
NVCC_PATCH = $(shell ""$(CC)"" --version | sed -n -r 's/.*(V([0-9]+).([0-9]+).([0-9]+))/\4/p')
NVCC_GE_9_0 = $(shell [ $(NVCC_MAJOR) -ge 9 ] && echo true)

# Set cuda architectures.
ifeq ($(NVCC_GE_9_0),true)
CUDA_ARCH ?= 50 60 70
else
CUDA_ARCH ?= 50 60
endif

# nvcc gencodes
# $(foreach sm,$(CUDA_ARCH),$(eval GENCODE_FLAGS += -gencode arch=compute_$(sm),code=sm_$(sm)))
HIGHEST_SM := $(lastword $(sort $(CUDA_ARCH)))
# GENCODE_FLAGS += -gencode arch=compute_$(HIGHEST_SM),code=compute_$(HIGHEST_SM)
CFLAGS = -m64

# Append global defines
$(foreach def,$(GLOBAL_DEFINES),$(eval CFLAGS += -D$(def)))

# Append include flags
$(foreach inc,$(INCLUDES),$(eval CFLAGS += -I$(inc)))

# Configure linker
LINKER = nvcc
LFLAGS = -m64 -lcurand

# Set global target OS specific linker/compile flags.
ifeq ($(OS),Windows_NT)
	TARGET := $(WINDOWS_TARGET)
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		TARGET := $(LINUX_TARGET)
		CFLAGS += -std=c++11 -D_GLIBCXX_USE_C99=1 --compiler-options -Wall
		LFLAGS += -std=c++11
	endif
endif

# RELEASE BUILD VARIABLES
RELEASE_DIR = release
RELEASE_BUILD_DIR = $(BUILD_DIR)/$(RELEASE_DIR)
RELEASE_TARGET_DIR = $(BIN_DIR)/$(RELEASE_DIR)
RELEASE_TARGET = $(RELEASE_TARGET_DIR)/$(TARGET)
RELEASE_LFLAGS = $(LFLAGS) -O2 -lineinfo
RELEASE_CFLAGS = $(CFLAGS) -O2 -lineinfo
$(foreach def,$(RELEASE_DEFINES),$(eval RELEASE_CFLAGS += -D$(def)))


# DEBUG BUILD VARIABLES
DEBUG_DIR = debug
DEBUG_BUILD_DIR = $(BUILD_DIR)/$(DEBUG_DIR)
DEBUG_TARGET_DIR = $(BIN_DIR)/$(DEBUG_DIR)
DEBUG_TARGET = $(DEBUG_TARGET_DIR)/$(TARGET)
DEBUG_LFLAGS = $(LFLAGS) -g -G
DEBUG_CFLAGS = $(CFLAGS) -g -G
$(foreach def,$(DEBUG_DEFINES),$(eval DEBUG_CFLAGS += -D$(def)))


# PROFILE BUILD VARIABLES
PROFILE_DIR = profile
PROFILE_BUILD_DIR = $(BUILD_DIR)/$(PROFILE_DIR)
PROFILE_TARGET_DIR = $(BIN_DIR)/$(PROFILE_DIR)
PROFILE_TARGET = $(PROFILE_TARGET_DIR)/$(TARGET)
PROFILE_LFLAGS = $(LFLAGS) -O2 -lineinfo
PROFILE_CFLAGS = $(CFLAGS) -O2 -lineinfo
$(foreach def,$(PROFILE_DEFINES),$(eval PROFILE_CFLAGS += -D$(def)))

# Add source directory to virtual path
VPATH = $(SRC_DIR)

all: release debug profile

rebuild: clean all

# @note - lots of duplication to enable partial compilation.
# Release rules
release: checkdirs $(RELEASE_TARGET)
$(RELEASE_TARGET): $(addprefix $(RELEASE_BUILD_DIR)/, $(OBJECTS))
	$(LINKER) $(RELEASE_LFLAGS) $(GENCODE_FLAGS) -o $(RELEASE_TARGET) $^
$(RELEASE_BUILD_DIR)/%.obj: %.cu
	$(CC) $(RELEASE_CFLAGS) $(GENCODE_FLAGS) -o $@ -c $<

# Debug rules.
debug: checkdirs $(DEBUG_TARGET)
$(DEBUG_TARGET): $(addprefix $(DEBUG_BUILD_DIR)/, $(OBJECTS))
	$(LINKER) $(DEBUG_LFLAGS) $(GENCODE_FLAGS) -I$(DEBUG_BUILD_DIR) -o $(DEBUG_TARGET) $^
$(DEBUG_BUILD_DIR)/%.obj: %.cu
	$(CC) $(DEBUG_CFLAGS) $(GENCODE_FLAGS) -o $@ -c $<

profile: checkdirs $(PROFILE_TARGET)
$(PROFILE_TARGET): $(addprefix $(PROFILE_BUILD_DIR)/, $(OBJECTS))
	$(LINKER) $(PROFILE_LFLAGS) $(GENCODE_FLAGS) -o $(PROFILE_TARGET) $^
$(PROFILE_BUILD_DIR)/%.obj: %.cu
	$(CC) $(PROFILE_CFLAGS) $(GENCODE_FLAGS) -o $@ -c $<


# Create required directories
checkdirs:
	@mkdir -p $(RELEASE_BUILD_DIR)
	@mkdir -p $(RELEASE_BUILD_DIR)/satgpu
	@mkdir -p $(RELEASE_BUILD_DIR)/standalone
	@mkdir -p $(RELEASE_TARGET_DIR)

	@mkdir -p $(DEBUG_BUILD_DIR)
	@mkdir -p $(DEBUG_BUILD_DIR)/satgpu
	@mkdir -p $(DEBUG_BUILD_DIR)/standalone
	@mkdir -p $(DEBUG_TARGET_DIR)

	@mkdir -p $(PROFILE_BUILD_DIR)
	@mkdir -p $(PROFILE_BUILD_DIR)/satgpu
	@mkdir -p $(PROFILE_BUILD_DIR)/standalone
	@mkdir -p $(PROFILE_TARGET_DIR)

# Define rules for cleaning, marked as .PHONY as they do not generate files.
.PHONY: clean veryclean

clean:
	find $(BUILD_DIR) -name "*.mod" -type f -delete
	find $(BUILD_DIR) -name "*.obj" -type f -delete
	find $(BUILD_DIR) -name "*.oobj" -type f -delete
	find $(BUILD_DIR) -name "*.pdb" -type f -delete
	find $(BUILD_DIR) -name "*.dwf" -type f -delete
	find $(BUILD_DIR) -name "*.gpu" -type f -delete
	find $(BUILD_DIR) -name "*.ptx" -type f -delete
	find $(BUILD_DIR) -name "*.bin" -type f -delete
	find $(BUILD_DIR) -name "*.exp" -type f -delete
	find $(BUILD_DIR) -name "*.lib" -type f -delete


veryclean: clean
	find $(BIN_DIR) -name "*.exe" -type f -delete
	find $(BIN_DIR) -name "*.dwf" -type f -delete
	find $(BIN_DIR) -name "*.pdb" -type f -delete
