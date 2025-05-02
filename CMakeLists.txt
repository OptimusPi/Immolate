cmake_minimum_required(VERSION 3.10) # 3.1 << C_STANDARD 11

project(Ouiji LANGUAGES C)

find_package(OpenCL REQUIRED)

add_executable(${PROJECT_NAME} ouiji.c)

target_link_libraries(${PROJECT_NAME} PRIVATE OpenCL::OpenCL)

set_target_properties(${PROJECT_NAME} PROPERTIES C_STANDARD 11
                                                 C_STANDARD_REQUIRED ON
                                                 C_EXTENSIONS ON)

target_compile_definitions(${PROJECT_NAME} PRIVATE CL_TARGET_OPENCL_VERSION=100)