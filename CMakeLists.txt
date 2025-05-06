cmake_minimum_required(VERSION 3.10) # 3.1 << C_STANDARD 11

project(Ouiji LANGUAGES C)

find_package(OpenCL REQUIRED)

add_executable(${PROJECT_NAME} ouiji.c)


target_link_libraries(${PROJECT_NAME} PRIVATE OpenCL::OpenCL)

set_target_properties(${PROJECT_NAME} PROPERTIES C_STANDARD 11
                                                 C_STANDARD_REQUIRED ON
                                                 C_EXTENSIONS ON)

target_compile_definitions(${PROJECT_NAME} PRIVATE CL_TARGET_OPENCL_VERSION=100)

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