cmake_minimum_required(VERSION 3.10)

if(NOT (${CMAKE_VERSION} VERSION_LESS "3.13.0"))
	# CMake 3.13+ has less restrictive rules for target_link_libraries()
	# Until we make 3.13 as required minimum version we want to
	# use old behaviour for compatibility
	cmake_policy(SET CMP0079 OLD)
endif()

# TODO: take `host` out of fw build
option(BUILD_HOST "Build host program" OFF)
option(BUILD_UNIT_TESTS "Build unit tests" OFF)

if(BUILD_HOST)
	set(ARCH host)
else()
	# firmware build supports only xtensa arch for now
	set(ARCH xtensa)
endif()

# let user override built-in toolchains
if(DEFINED CMAKE_TOOLCHAIN_FILE)
	set(TOOLCHAIN "${CMAKE_TOOLCHAIN_FILE}")
else()
	include(scripts/cmake/${ARCH}-toolchain.cmake OPTIONAL)
endif()

include(scripts/cmake/misc.cmake)

project(SOF C ASM)

# most of other options are set on per-arch and per-target basis
set(CMAKE_ASM_FLAGS -DASSEMBLY)

# interface library that is used only as container for sof binary options
# other targets can use it to build with the same options
add_library(sof_options INTERFACE)

target_include_directories(sof_options INTERFACE ${PROJECT_SOURCE_DIR}/src/include)

if(BUILD_HOST)
	add_subdirectory(src)
	# rest of this file is not needed for host build
	return()
endif()

set(PYTHON3 python3)

# get compiler name and version
execute_process(
	COMMAND ${CMAKE_C_COMPILER} --version
	COMMAND head -n 1
	OUTPUT_VARIABLE CC_VERSION_TEXT
	OUTPUT_STRIP_TRAILING_WHITESPACE
	ERROR_QUIET
)

set(GENERATED_DIRECTORY ${PROJECT_BINARY_DIR}/generated)
file(MAKE_DIRECTORY ${GENERATED_DIRECTORY}/include)

set(DOT_CONFIG_PATH ${GENERATED_DIRECTORY}/.config)
set(CONFIG_H_PATH ${GENERATED_DIRECTORY}/include/config.h)
set(VERSION_H_PATH ${GENERATED_DIRECTORY}/include/version.h)

include(scripts/cmake/version.cmake)
sof_add_version_h_rule(${PROJECT_SOURCE_DIR}/scripts/cmake/version.cmake)

include(scripts/cmake/defconfigs.cmake)

# cmake itself cannot depend on files that don't exist
# so to make it regenerate when .config file is created,
# we make it depend on containing directory
# NOTE: some filesystems may be unable to watch directory change,
#       in that case cmake may need to be regenerated from CLI
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
	${GENERATED_DIRECTORY} ${DOT_CONFIG_PATH})

if(EXISTS ${DOT_CONFIG_PATH})
	read_kconfig_config(${DOT_CONFIG_PATH})
endif()

add_custom_target(
	menuconfig
	COMMAND ${CMAKE_COMMAND} -E env
		srctree=${PROJECT_SOURCE_DIR}
		CC_VERSION_TEXT=${CC_VERSION_TEXT}
		ARCH=${ARCH}
		${PYTHON3} ${PROJECT_SOURCE_DIR}/scripts/kconfig/menuconfig.py
		${PROJECT_SOURCE_DIR}/Kconfig
	WORKING_DIRECTORY ${GENERATED_DIRECTORY}
	VERBATIM
	USES_TERMINAL
)

add_custom_command(OUTPUT ${CONFIG_H_PATH}
	COMMAND ${CMAKE_COMMAND} -E env
		srctree=${PROJECT_SOURCE_DIR}
		CC_VERSION_TEXT=${CC_VERSION_TEXT}
		ARCH=${ARCH}
		${PYTHON3} ${PROJECT_SOURCE_DIR}/scripts/kconfig/genconfig.py
		--header-path ${CONFIG_H_PATH}
		${PROJECT_SOURCE_DIR}/Kconfig
	DEPENDS ${DOT_CONFIG_PATH}
	WORKING_DIRECTORY ${GENERATED_DIRECTORY}
	COMMENT "Generating ${CONFIG_H_PATH}"
	VERBATIM
	USES_TERMINAL
)

add_custom_target(genconfig DEPENDS ${CONFIG_H_PATH})

add_dependencies(sof_options genconfig)
target_include_directories(sof_options INTERFACE ${GENERATED_DIRECTORY}/include)

if(BUILD_UNIT_TESTS)
	enable_testing()
	add_subdirectory(src/arch/${ARCH})
	add_subdirectory(test)
	# rest of this file is not needed for unit tests
	return()
endif()

add_library(sof_ld_flags INTERFACE)
add_library(sof_ld_scripts INTERFACE)

# declare target with no sources to let cmake know about it
add_executable(sof "")
target_link_libraries(sof sof_options)
target_link_libraries(sof sof_ld_scripts)
target_link_libraries(sof sof_ld_flags)

add_subdirectory(src)

target_link_libraries(sof sof_lib)