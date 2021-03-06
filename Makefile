
# This makefile is optimized to be run from WSL and to interact with the 
# Windows host as there are limitations when building GPU programs. This
# makefile contains the commands for interacting with the visual studio
# build via command line for faster iterations, as the intention is to 
# support other editors (optimised for vim). There are also commands that
# support the builds for linux-native compilations and these are the commands
# starting with mk_.

VCPKG_WIN_PATH ?= "C:\\Users\\axsau\\Programming\\lib\\vcpkg\\scripts\\buildsystems\\vcpkg.cmake"
VCPKG_UNIX_PATH ?= "/c/Users/axsau/Programming/lib/vcpkg/scripts/buildsystems/vcpkg.cmake"

# Regext to pass to catch2 to filter tests
FILTER_TESTS ?= "*"

ifeq ($(OS),Windows_NT)     # is Windows_NT on XP, 2000, 7, Vista, 10...
	CMAKE_BIN ?= "C:\Program Files\CMake\bin\cmake.exe"
	SCMP_BIN="C:\\VulkanSDK\\1.2.141.2\\Bin32\\glslangValidator.exe"
	MSBUILD_BIN ?= "C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\Community\\MSBuild\\Current\\Bin\\MSBuild.exe"
else
	CLANG_FORMAT_BIN ?= "/home/alejandro/Programming/lib/clang+llvm-10.0.0-x86_64-linux-gnu-ubuntu-18.04/bin/clang-format"
	CMAKE_BIN ?= "/c/Program Files/CMake/bin/cmake.exe"
	SCMP_BIN ?= "/c/VulkanSDK/1.2.141.2/Bin32/glslangValidator.exe"
	MSBUILD_BIN ?= "/c/Program Files (x86)/Microsoft Visual Studio/2019/Community/MSBuild/Current/Bin/MSBuild.exe"
endif


####### Main Target Rules #######

push_docs_to_ghpages:
	GIT_DEPLOY_DIR="build/docs/sphinx/" \
		GIT_DEPLOY_BRANCH="gh-pages" \
		GIT_DEPLOY_REPO="origin" \
			./scripts/push_folder_to_branch.sh

####### CMAKE quickstart commands #######

clean_cmake:
	rm -rf build/

####### Visual studio build shortcut commands #######

MK_BUILD_TYPE ?= "Release"
MK_INSTALL_PATH ?= "build/src/CMakeFiles/Export/" # Set to "" if prefer default
MK_CMAKE_EXTRA_FLAGS ?= ""
MK_KOMPUTE_EXTRA_CXX_FLAGS ?= ""

mk_cmake:
	cmake \
		-Bbuild \
		$(MK_CMAKE_EXTRA_FLAGS) \
		-DCMAKE_TOOLCHAIN_FILE=$(VCPKG_UNIX_PATH) \
		-DCMAKE_BUILD_TYPE=$(MK_BUILD_TYPE) \
		-DCMAKE_INSTALL_PREFIX=$(MK_INSTALL_PATH) \
		-DKOMPUTE_EXTRA_CXX_FLAGS=$(MK_KOMPUTE_EXTRA_CXX_FLAGS) \
		-DKOMPUTE_OPT_INSTALL=1 \
		-DKOMPUTE_OPT_REPO_SUBMODULE_BUILD=0 \
		-DKOMPUTE_OPT_BUILD_TESTS=1 \
		-DKOMPUTE_OPT_BUILD_DOCS=1 \
		-DKOMPUTE_OPT_BUILD_SHADERS=1 \
		-DKOMPUTE_OPT_BUILD_SINGLE_HEADER=1 \
		-DKOMPUTE_OPT_ENABLE_SPDLOG=1 \
		-G "Unix Makefiles"

mk_build_all:
	make -C build/

mk_build_docs:
	make -C build/ docs

mk_build_kompute:
	make -C build/ kompute

mk_build_tests:
	make -C build/ test_kompute

mk_run_docs: mk_build_docs
	(cd build/docs/sphinx && python2.7 -m SimpleHTTPServer)

mk_run_tests: mk_build_tests
	./build/test/test_kompute $(FILTER_TESTS)


####### Visual studio build shortcut commands #######

VS_BUILD_TYPE ?= "Debug"
# Run with multiprocessin / parallel build by default
VS_CMAKE_EXTRA_FLAGS ?= ""
VS_KOMPUTE_EXTRA_CXX_FLAGS ?= "/MP" # /MP is for faster multiprocessing builds. You should add "/MT" for submodule builds for compatibility with gtest
VS_INSTALL_PATH ?= "build/src/CMakeFiles/Export/" # Set to "" if prefer default

vs_cmake:
	$(CMAKE_BIN) \
		-Bbuild \
		$(VS_CMAKE_EXTRA_FLAGS) \
		-DCMAKE_TOOLCHAIN_FILE=$(VCPKG_WIN_PATH) \
		-DKOMPUTE_EXTRA_CXX_FLAGS=$(VS_KOMPUTE_EXTRA_CXX_FLAGS) \
		-DCMAKE_INSTALL_PREFIX=$(VS_INSTALL_PATH) \
		-DKOMPUTE_OPT_INSTALL=1 \
		-DKOMPUTE_OPT_REPO_SUBMODULE_BUILD=0 \
		-DKOMPUTE_OPT_BUILD_TESTS=1 \
		-DKOMPUTE_OPT_BUILD_DOCS=1 \
		-DKOMPUTE_OPT_BUILD_SHADERS=1 \
		-DKOMPUTE_OPT_BUILD_SINGLE_HEADER=1 \
		-DKOMPUTE_OPT_ENABLE_SPDLOG=1 \
		-G "Visual Studio 16 2019"

vs_build_all:
	$(MSBUILD_BIN) build/kompute.sln -p:Configuration$(VS_BUILD_TYPE)

vs_build_docs:
	$(MSBUILD_BIN) build/docs/gendocsall.vcxproj -p:Configuration=$(VS_BUILD_TYPE)

vs_install_kompute:
	$(MSBUILD_BIN) build/src/INSTALL.vcxproj -p:Configuration=$(VS_BUILD_TYPE)

vs_build_kompute:
	$(MSBUILD_BIN) build/src/kompute.vcxproj -p:Configuration=$(VS_BUILD_TYPE)

vs_build_tests:
	$(MSBUILD_BIN) build/test/test_kompute.vcxproj -p:Configuration=$(VS_BUILD_TYPE)

vs_run_docs: vs_build_docs
	(cd build/docs/sphinx && python2.7 -m SimpleHTTPServer)

vs_run_tests: vs_build_tests
	./build/test/$(VS_BUILD_TYPE)/test_kompute.exe --gtest_filter=$(FILTER_TESTS)

####### Create release ######

update_builder_image:
	docker build -f builders/Dockerfile.linux . \
		-t axsauze/kompute-builder:0.1
	docker push axsauze/kompute-builder:0.1

create_linux_release:
	docker run -it \
		-v $(pwd):/workspace \
		axsauze/kompute-builder:0.1 \
		/workspace/scripts/build_release_linux.sh

####### General project commands #######

install_python_reqs:
	python3 -m pip install -r scripts/requirements.txt

build_shaders:
	python3 scripts/convert_shaders.py \
		--shader-path shaders/glsl \
		--shader-binary $(SCMP_BIN) \
		--header-path src/include/kompute/shaders/ \
		-v
	python3 scripts/convert_shaders.py \
		--shader-path test/shaders/glsl \
		--shader-binary $(SCMP_BIN) \
		--header-path test/compiled_shaders_include/kompute_test/shaders/ \
		-v

build_single_header:
	quom \
		--include_directory \
		"src/include/" \
		"single_include/AggregateHeaders.cpp" \
		"single_include/kompute/Kompute.hpp"

format:
	$(CLANG_FORMAT_BIN) -i -style="{BasedOnStyle: mozilla, IndentWidth: 4}" src/*.cpp src/include/kompute/*.hpp test/*cpp

clean:
	find src -name "*gch" -exec rm {} \; || "No ghc files"
	rm ./bin/main.exe || echo "No main.exe"

run:
	./bin/main.exe;

