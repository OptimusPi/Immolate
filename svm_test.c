#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <CL/cl.h>

// Define a result structure that matches what we want to capture
typedef struct {
    char seed[9];   // 8 chars plus null terminator
    int score;      // Total score
} ResultEntry;

// Error checking macro
#define CHECK_CL_ERROR(err, msg) \
    if (err != CL_SUCCESS) { \
        fprintf(stderr, "OpenCL Error %d: %s\n", err, msg); \
        exit(1); \
    }

// Simple kernel that fills a buffer with results
const char* kernel_source = 
"typedef struct { \n"
"    char seed[9]; \n"
"    int score; \n"
"} ResultEntry; \n"
"\n"
"__kernel void test_svm(__global ResultEntry* results, int num_results) { \n"
"    int gid = get_global_id(0); \n"
"    if (gid < num_results) { \n"
"        // Generate a fake seed string \n"
"        char base = 'A' + (gid % 26); \n"
"        for (int i = 0; i < 8; i++) { \n"
"            results[gid].seed[i] = base; \n"
"        } \n"
"        results[gid].seed[8] = '\\0'; \n"
"        \n"
"        // Set a test score \n"
"        results[gid].score = gid * 10; \n"
"    } \n"
"} \n";

int main() {
    cl_int err;
    cl_platform_id platform;
    cl_device_id device;
    cl_context context;
    cl_command_queue queue;
    cl_program program;
    cl_kernel kernel;
    
    // Get platform
    err = clGetPlatformIDs(1, &platform, NULL);
    CHECK_CL_ERROR(err, "Getting platform");
    
    // Get GPU device
    err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, 1, &device, NULL);
    CHECK_CL_ERROR(err, "Getting device");
    
    // Print device name
    char device_name[256];
    err = clGetDeviceInfo(device, CL_DEVICE_NAME, sizeof(device_name), device_name, NULL);
    CHECK_CL_ERROR(err, "Getting device name");
    printf("Device: %s\n", device_name);
    
    // Check for SVM support
    cl_device_svm_capabilities svm_caps;
    err = clGetDeviceInfo(device, CL_DEVICE_SVM_CAPABILITIES, 
                          sizeof(svm_caps), &svm_caps, NULL);
    
    if (err != CL_SUCCESS) {
        printf("SVM not supported on this device (error %d)\n", err);
        return 1;
    }
    
    printf("SVM Capabilities: 0x%lx\n", (unsigned long)svm_caps);
    printf("- Coarse-grained buffer SVM: %s\n", 
           (svm_caps & CL_DEVICE_SVM_COARSE_GRAIN_BUFFER) ? "Yes" : "No");
    printf("- Fine-grained buffer SVM: %s\n", 
           (svm_caps & CL_DEVICE_SVM_FINE_GRAIN_BUFFER) ? "Yes" : "No");
    printf("- Fine-grained system SVM: %s\n", 
           (svm_caps & CL_DEVICE_SVM_FINE_GRAIN_SYSTEM) ? "Yes" : "No");
    printf("- Atomics: %s\n", 
           (svm_caps & CL_DEVICE_SVM_ATOMICS) ? "Yes" : "No");
    
    if (!(svm_caps & CL_DEVICE_SVM_COARSE_GRAIN_BUFFER)) {
        printf("This test requires coarse-grained buffer SVM support.\n");
        return 1;
    }
    
    // Create context
    context = clCreateContext(NULL, 1, &device, NULL, NULL, &err);
    CHECK_CL_ERROR(err, "Creating context");
    
    // Create command queue
    queue = clCreateCommandQueue(context, device, 0, &err);
    CHECK_CL_ERROR(err, "Creating command queue");
    
    // Create and build program
    program = clCreateProgramWithSource(context, 1, &kernel_source, NULL, &err);
    CHECK_CL_ERROR(err, "Creating program");
    
    err = clBuildProgram(program, 1, &device, NULL, NULL, NULL);
    if (err != CL_SUCCESS) {
        size_t log_size;
        clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, 0, NULL, &log_size);
        char *log = (char *)malloc(log_size);
        clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, log_size, log, NULL);
        printf("Build Error: %s\n", log);
        free(log);
        return 1;
    }
    
    // Create kernel
    kernel = clCreateKernel(program, "test_svm", &err);
    CHECK_CL_ERROR(err, "Creating kernel");
    
    // Test parameters
    const int num_results = 100;  // We'll generate this many test results
    
    // Allocate SVM buffer
    printf("\nAllocating SVM buffer for %d results...\n", num_results);
    ResultEntry *results = (ResultEntry *)clSVMAlloc(
        context, 
        CL_MEM_READ_WRITE, 
        num_results * sizeof(ResultEntry), 
        0);
    
    if (!results) {
        printf("Failed to allocate SVM memory\n");
        return 1;
    }
    
    printf("SVM buffer allocated successfully at %p\n", results);
    
    // Set kernel arguments
    err = clSetKernelArgSVMPointer(kernel, 0, results);
    CHECK_CL_ERROR(err, "Setting kernel SVM argument");
    
    err = clSetKernelArg(kernel, 1, sizeof(int), &num_results);
    CHECK_CL_ERROR(err, "Setting kernel argument");
    
    // Execute kernel
    size_t global_size = num_results;
    size_t local_size = 64; // Adjust based on your GPU
    
    printf("Executing kernel...\n");
    err = clEnqueueNDRangeKernel(queue, kernel, 1, NULL, &global_size, &local_size, 
                                0, NULL, NULL);
    CHECK_CL_ERROR(err, "Enqueueing kernel");
    
    // Wait for kernel to complete
    clFinish(queue);
    
    // Print results - directly access the SVM memory from host
    printf("\nResults (first 10 entries):\n");
    printf("-------------------------------\n");
    printf("  Index | Seed      | Score\n");
    printf("-------------------------------\n");
    
    for (int i = 0; i < 10 && i < num_results; i++) {
        printf("  %5d | %-8s | %5d\n", 
               i, results[i].seed, results[i].score);
    }
    
    // Clean up
    clSVMFree(context, results);
    clReleaseKernel(kernel);
    clReleaseProgram(program);
    clReleaseCommandQueue(queue);
    clReleaseContext(context);
    
    printf("\nTest completed successfully!\n");
    return 0;
}