# Orderbook - macOS/clang build
#
# Layout:
#   include/     public headers
#   src/         engine sources + main
#   tests/       gtest suite + TestFiles fixtures
#   benchmarks/  perf harness (empty for now)
#
# Usage:
#   make              build the orderbook binary (release)
#   make test         build and run the gtest suite
#   make MODE=debug   build with -O0 -g
#   make help         list all targets

CXX      := clang++
MODE     ?= release

BUILD    := build/$(MODE)
BIN      := $(BUILD)/orderbook
TEST_BIN := $(BUILD)/orderbook_tests

# Engine sources, shared by the app and the test binary.
LIB_SRCS := src/Orderbook.cpp
LIB_OBJS := $(LIB_SRCS:%.cpp=$(BUILD)/%.o)

APP_SRCS := src/main.cpp
APP_OBJS := $(APP_SRCS:%.cpp=$(BUILD)/%.o)

TEST_SRCS := tests/test.cpp
TEST_OBJS := $(TEST_SRCS:%.cpp=$(BUILD)/%.o)

CXXFLAGS := -std=c++20 -Wall -Wextra -MMD -MP -Iinclude

ifeq ($(MODE),release)
  CXXFLAGS += -O2 -DNDEBUG
else ifeq ($(MODE),debug)
  CXXFLAGS += -O0 -g
else ifeq ($(MODE),asan)
  CXXFLAGS += -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined
  LDFLAGS  += -fsanitize=address,undefined
else
  $(error Unknown MODE '$(MODE)'. Use release, debug, or asan)
endif

GTEST_PREFIX := $(shell brew --prefix googletest 2>/dev/null)

# Absolute fixture path baked into the test binary so it runs from anywhere.
TEST_CXXFLAGS := -Itests -I$(GTEST_PREFIX)/include \
                 -DTEST_FILES_DIR='"$(CURDIR)/tests/TestFiles"'
GTEST_LIBS    := -L$(GTEST_PREFIX)/lib -lgtest -lgtest_main

.PHONY: all run test debug asan clean help check-gtest

all: $(BIN)

$(BIN): $(APP_OBJS) $(LIB_OBJS)
	@mkdir -p $(dir $@)
	$(CXX) $(LDFLAGS) $^ -o $@

$(BUILD)/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

run: $(BIN)
	./$(BIN)

test: $(TEST_BIN)
	./$(TEST_BIN)

$(TEST_BIN): $(TEST_OBJS) $(LIB_OBJS)
	@mkdir -p $(dir $@)
	$(CXX) $(LDFLAGS) $^ $(GTEST_LIBS) -o $@

$(TEST_OBJS): $(BUILD)/%.o: %.cpp | check-gtest
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(TEST_CXXFLAGS) -c $< -o $@

check-gtest:
ifeq ($(GTEST_PREFIX),)
	@echo "googletest not found. Install it with: brew install googletest" >&2
	@exit 1
endif

debug:
	@$(MAKE) MODE=debug

asan:
	@$(MAKE) MODE=asan

clean:
	rm -rf build

help:
	@echo "Targets:"
	@echo "  all     build $(BIN) (default)"
	@echo "  run     build and run the orderbook binary"
	@echo "  test    build and run the gtest suite"
	@echo "  debug   build with MODE=debug (-O0 -g)"
	@echo "  asan    build with MODE=asan (address+undefined sanitizers)"
	@echo "  clean   remove the build directory"
	@echo ""
	@echo "Override the config on any target with MODE=release|debug|asan"

-include $(APP_OBJS:.o=.d) $(LIB_OBJS:.o=.d) $(TEST_OBJS:.o=.d)
