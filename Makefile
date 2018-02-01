OS := windows
UNAME := $(shell uname)
ifeq ($(UNAME), Linux)
  OS := linux
endif

MODE ?= development

GNAT_FLAGS ?= -dm
CFLAGS  ?= -O2 -march=native

X_OS := -XOS=$(OS)
X_MODE = -XMode=$(MODE)
X_COMPILER_FLAGS = -XCompiler_Flags="${CFLAGS}"

GPRBUILD = gprbuild $(GNAT_FLAGS) -p $(X_OS) $(X_COMPILER_FLAGS) $(X_MODE)
GPRCLEAN = gprclean -q $(X_OS)
GPRINSTALL = gprinstall -q $(X_OS)

all:
	$(GPRBUILD) -P orka.gpr

clean:
	$(GPRCLEAN) -r -P orka.gpr
	rmdir obj
	rmdir bin
