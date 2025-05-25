cmake_minimum_required(VERSION 3.10) # 3.1 << C_STANDARD 11

project(Ouija LANGUAGES C)

find_package(OpenCL REQUIRED)

add_executable(${PROJECT_NAME} ouija.c)

target_link_libraries(${PROJECT_NAME} PRIVATE OpenCL::OpenCL)

set_target_properties(${PROJECT_NAME} PROPERTIES C_STANDARD 11
                                                 C_STANDARD_REQUIRED ON
                                                 C_EXTENSIONS ON)

# Update from OpenCL 1.0 to 2.0 to enable SVM features
target_compile_definitions(${PROJECT_NAME} PRIVATE CL_TARGET_OPENCL_VERSION=200)

# Enable strong optimizations for Release builds (MSVC)
if(MSVC)
    set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} /O2 /GL /DNDEBUG")
    set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} /OPT:REF /OPT:ICF")
    # Debug builds should be debuggable, not optimized
    set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} /Od /Zi")
    set(CMAKE_EXE_LINKER_FLAGS_DEBUG "${CMAKE_EXE_LINKER_FLAGS_DEBUG} /DEBUG")
endif()

# Add include directories for vcpkg-installed libraries
# Check if CMAKE_TOOLCHAIN_FILE is defined before using it
if(DEFINED CMAKE_TOOLCHAIN_FILE)
    get_filename_component(TOOLCHAIN_DIR ${CMAKE_TOOLCHAIN_FILE} DIRECTORY)
    include_directories(${TOOLCHAIN_DIR}/../include)
else()
    message(WARNING "CMAKE_TOOLCHAIN_FILE is not defined. Assuming vcpkg include directory is reachable.")
    # You might need to manually specify the include path if the toolchain file isn't used
    # include_directories(path/to/vcpkg/installed/x64-windows/include)
endif()