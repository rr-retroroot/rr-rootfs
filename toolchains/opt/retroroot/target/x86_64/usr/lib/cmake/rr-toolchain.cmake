cmake_minimum_required(VERSION 3.6.0)

if (NOT DEFINED ENV{RETROROOT_HOME})
  set(RETROROOT_HOME "/opt/retroroot")
  set(ENV{RETROROOT_HOME} ${RETROROOT_HOME})
else ()
  set(RETROROOT_HOME $ENV{RETROROOT_HOME})
endif ()

set(RETROROOT TRUE)
set(RETROROOT_SYSROOT "${RETROROOT_HOME}/target/x86_64")

set(TARGET x86_64-linux-gnu)
set(CMAKE_SYSTEM_NAME "Linux")
set(CMAKE_SYSTEM_PROCESSOR "x86_64")
set(CMAKE_SYSTEM_VERSION 12)
set(CMAKE_CROSSCOMPILING 1)
set(CMAKE_LIBRARY_ARCHITECTURE x86_64 CACHE INTERNAL "abi")
set(CMAKE_SYSROOT ${RETROROOT_SYSROOT})
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# toolchain setup
set(RETROROOT_HOST "${RETROROOT_HOME}/host/x86_64")
set(RETROROOT_CROSS_PREFIX "${RETROROOT_HOST}/bin")
set(RETROROOT_TOOLS_COMPILER_PREFIX "${RETROROOT_CROSS_PREFIX}/${TARGET}-")
# if toolset was not found in retroroot host, try from $PATH
if(NOT EXISTS "${RETROROOT_TOOLS_COMPILER_PREFIX}gcc")
  set(RETROROOT_HOST "/usr")
  set(RETROROOT_CROSS_PREFIX "${RETROROOT_HOST}/bin")
  set(RETROROOT_TOOLS_COMPILER_PREFIX "${RETROROOT_CROSS_PREFIX}/${TARGET}-")
endif()

set(CMAKE_ASM_COMPILER "${RETROROOT_TOOLS_COMPILER_PREFIX}as" CACHE PATH "")
set(CMAKE_C_COMPILER "${RETROROOT_TOOLS_COMPILER_PREFIX}gcc" CACHE PATH "")
set(CMAKE_CXX_COMPILER "${RETROROOT_TOOLS_COMPILER_PREFIX}g++" CACHE PATH "")
set(CMAKE_LINKER "${RETROROOT_TOOLS_COMPILER_PREFIX}ld" CACHE PATH "")
set(CMAKE_AR "${RETROROOT_TOOLS_COMPILER_PREFIX}ar" CACHE PATH "")
set(CMAKE_RANLIB "${RETROROOT_TOOLS_COMPILER_PREFIX}ranlib" CACHE PATH "")
set(CMAKE_STRIP "${RETROROOT_TOOLS_COMPILER_PREFIX}strip" CACHE PATH "")

set(CMAKE_ASM_FLAGS_INIT "${CMAKE_ASM_FLAGS_INIT} -pipe -fno-plt -fexceptions -D__RETROROOT__ -I${RETROROOT_SYSROOT}/usr/include")
set(CMAKE_C_FLAGS_INIT "${CMAKE_C_FLAGS_INIT} ${CMAKE_ASM_FLAGS_INIT}")
set(CMAKE_CXX_FLAGS_INIT "${CMAKE_CXX_FLAGS_INIT} ${CMAKE_C_FLAGS_INIT}")
set(CMAKE_C_STANDARD_LIBRARIES "-L${RETROROOT_SYSROOT}/usr/lib ${CMAKE_C_STANDARD_LIBRARIES}")
set(CMAKE_CXX_STANDARD_LIBRARIES "-L${RETROROOT_SYSROOT}/usr/lib ${CMAKE_CXX_STANDARD_LIBRARIES} ${CMAKE_C_STANDARD_LIBRARIES}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-L${RETROROOT_SYSROOT}/usr/lib ${CMAKE_EXE_LINKER_FLAGS_INIT} -Wl,-O1,--sort-common,--as-needed")

set(CMAKE_FIND_ROOT_PATH ${RETROROOT_SYSROOT}/usr)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG TRUE)

set(BUILD_SHARED_LIBS OFF CACHE INTERNAL "Shared libs not available")

find_program(PKG_CONFIG_EXECUTABLE NAMES x86_64-linux-gnu-pkg-config HINTS "${RETROROOT_SYSROOT}/usr/bin")
if (NOT PKG_CONFIG_EXECUTABLE)
  message(WARNING "Could not find x86_64-linux-gnu-pkg-config: try installing rr-pkg-config")
endif ()
