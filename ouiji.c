#include "lib/ouiji.h"
#include <time.h>
// Replace stdatomic.h with Windows-specific atomic implementation
#ifdef _WIN32
    #include <windows.h>
    // Define atomic_uint and atomic operations for Windows
    typedef volatile LONG atomic_uint;
    #define atomic_fetch_add(ptr, val) InterlockedExchangeAdd(ptr, val)
    #define atomic_load(ptr) InterlockedCompareExchange(ptr, 0, 0)
    #define atomic_store(ptr, val) InterlockedExchange(ptr, val)
#else
    #include <stdatomic.h> // Only use on platforms where it's supported
#endif

// --- Define Structs matching OpenCL ---
#define MAX_DESIRES_HOST 10
typedef struct {
    int Needs[MAX_DESIRES_HOST];
    int Wants[MAX_DESIRES_HOST];
    int numNeeds;
    int numWants;
    int needByAnte;
    int wantByAnte;
    int needByAntePerkeo;
    long cutoff; // Add cutoff to the struct
} OuijiConfig;

// Define seed struct matching OpenCL's internal seed representation if needed for printing
// For simplicity, we'll convert the cl_char8 back later.
typedef cl_char8 seed_internal; // Assuming seed is cl_char8 internally for now

typedef struct {
    seed_internal _seed; // Use the internal representation
    long score;
    unsigned int wants_mask;
} ResultInfo;

#define MAX_RESULTS_BUFFER 10000

// Helper function to convert internal seed (cl_char8) to string
void seedToString(seed_internal internal_seed, char* output_str, size_t max_len) {
    // Find the length of the seed (up to 8 chars, null terminated potentially)
    int len = 0;
    for (int i = 0; i < 8 && internal_seed.s[i] != '\0'; ++i) {
        len++;
    }
    // Copy the characters
    snprintf(output_str, max_len, "%.*s", len, internal_seed.s);
}

// Helper function to create binary path
void createBinaryPath(const char* executable_dir, const char* filter_name, char* binary_path, size_t max_len) {
    // Ensure the filters directory exists
    char filter_dir_path[MAX_PATH];
    #ifdef _WIN32
        snprintf(filter_dir_path, MAX_PATH, "%s%sfilters", executable_dir, PATH_SEPARATOR);
        CreateDirectory(filter_dir_path, NULL); // Create directory if it doesn't exist (Windows)
    #else
        snprintf(filter_dir_path, MAX_PATH, "%s%sfilters", executable_dir, PATH_SEPARATOR);
        mkdir(filter_dir_path, 0777); // Create directory if it doesn't exist (Linux/macOS)
    #endif

    snprintf(binary_path, max_len, "%s%sfilters%s%s.bin", executable_dir, PATH_SEPARATOR, PATH_SEPARATOR, filter_name);
}

int main(int argc, char **argv) {

    // Print version
    printf_s("Ouiji Beta v1.0.1f.1\n");

    // Handle CLI arguments
    unsigned int platformID = 0;
    unsigned int deviceID = 0;
    unsigned int numGroups = 16;
    cl_char8 startingSeed; // Keep as cl_char8
    for (int i = 0; i < 8; i++) {
        startingSeed.s[i] = '\0';
    };
    cl_long numSeeds = 2318107019761;
    // Default config values
    OuijiConfig config;
    config.cutoff = 1; // Default cutoff
    config.numNeeds = 0;
    config.numWants = 0;
    config.needByAnte = 8; // Default reasonable antes
    config.wantByAnte = 8;
    config.needByAntePerkeo = 8; // Default
    for(int i=0; i<MAX_DESIRES_HOST; ++i) {
        config.Needs[i] = 0;
        config.Wants[i] = 0;
    }

    char* filter = "template-ouiji"; // Default filter

    // --- Argument Parsing Loop ---
    for (int i = 0; i < argc; i++) {
        if (strcmp(argv[i], "-h")==0) {
            printf_s("Valid command line arguments:\n-h        Shows this help dialog.\n-f <F>    Sets the filter used by Ouiji to F. Defaults to template-ouiji.cl\n-s <S>    Sets the starting seed to S. Defaults to empty seed. Use \"random\" for a random starting seed.\n-n <N>    Sets the number of seeds to search to N. Defaults to full seed pool.\n-c <C>    Sets the cutoff score for a seed to be printed to C. Defaults to 1.\n-p <P>    Sets the platform ID of the CL device being used to P. Defaults to 0.\n-d <D>    Sets the device ID of the CL device being used to D. Defaults to 0.\n-g <G>    Sets the number of thread groups to G. Defaults to 16. Increasing this might help Immolate run faster.\n\n--list_devices   Lists information about the detected CL devices.");
            return 0;
        }
        if (strcmp(argv[i],  "-p")==0) {
            platformID = atoi(argv[i+1]);
            i++;
        }
        if (strcmp(argv[i],  "-f")==0) {
            filter = argv[i+1];
            i++;
        }
        if (strcmp(argv[i],  "-d")==0) {
            deviceID = atoi(argv[i+1]);
            i++;
        }
        if (strcmp(argv[i],  "-g")==0) {
            numGroups = atoi(argv[i+1]);
            i++;
        }
        if (strcmp(argv[i],  "-n")==0) {
            numSeeds = strtoll(argv[i+1], NULL, 10);
            i++;
        }
        if (strcmp(argv[i],  "-c")==0) {
            config.cutoff = strtoll(argv[i+1], NULL, 10); // Parse cutoff into config
            i++;
        }
        if (strcmp(argv[i],  "-s")==0) {
            if (strcmp(argv[i+1],"random")==0) {
                srand(time(NULL));
                char seedCharacters[] = {'1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'};
                for (int j = 0; j < 8; j++) {
                    startingSeed.s[j] = seedCharacters[rand() % 35];
                }
            } else if (strlen(argv[i+1]) <= 8) {
                for (int j = 0; j < strlen(argv[i+1]); j++) {
                    startingSeed.s[j] = argv[i+1][j];
                }
                for (int j = strlen(argv[i+1]); j < 8; j++) {
                    startingSeed.s[j] = '\0';
                }
            } else {
                printf_s("Warning: Inputted seed is not valid, ignoring...\n");
            }
            i++;
        }
        if (strcmp(argv[i],  "--list_devices")==0) {
            cl_int err;
            char buf[1024];
            cl_uint temp_int;

            // Get # of OpenCL Platforms
            cl_uint numPlatforms;
            err = clGetPlatformIDs(0, NULL, &numPlatforms);
            clErrCheck(err, "clGetPlatformIDs - Getting number of available OpenCL platforms");

            // Nothing available? Then leave!
            if (numPlatforms == 0) {
                printf_s("No OpenCL devices found.\n");
                return 0;
            }

            // Now get OpenCL Platforms
            cl_platform_id* platforms = malloc(sizeof(cl_platform_id) * numPlatforms);

            err = clGetPlatformIDs(numPlatforms, platforms, NULL);
            clErrCheck(err, "clGetPlatformIDs - Getting list of availble OpenCL platforms");

            int foundDevice = 0;
            for (unsigned int p = 0; p < numPlatforms; p++) {
                cl_uint numDevices;
                err = clGetDeviceIDs(platforms[p], CL_DEVICE_TYPE_ALL, 0, NULL, &numDevices);
                clErrCheck(err, "clGetDeviceIDs - Getting number of available OpenCL devices");

                if (numDevices > 0) foundDevice = 1;

                cl_device_id* devices = malloc(sizeof(cl_device_id) * numDevices);
                err = clGetDeviceIDs(platforms[p], CL_DEVICE_TYPE_ALL, numDevices, devices, NULL);
                clErrCheck(err, "clGetDeviceIDs - Getting list of available OpenCL devices");

                for (unsigned int d = 0; d < numDevices; d++) {
                    printf_s("Platform ID %i, Device ID %i\n", p, d);

                    // Get Device Info
                    err = clGetDeviceInfo(devices[d], CL_DEVICE_NAME, sizeof(buf), &buf, NULL);
                    clErrCheck(err, "clGetDeviceInfo - Getting device name");
                    printf_s("Name: %s\n", buf);

                    err = clGetDeviceInfo(devices[d], CL_DEVICE_VENDOR, sizeof(buf), &buf, NULL);
                    clErrCheck(err, "clGetDeviceInfo - Getting device vendor");
                    printf_s("Vendor: %s\n", buf);

                    err = clGetDeviceInfo(devices[d], CL_DEVICE_MAX_COMPUTE_UNITS, sizeof(temp_int), &temp_int, NULL);
                    clErrCheck(err, "clGetDeviceInfo - Getting device compute units");
                    printf_s("Compute Units: %i\n", temp_int);

                    err = clGetDeviceInfo(devices[d], CL_DEVICE_MAX_CLOCK_FREQUENCY, sizeof(temp_int), &temp_int, NULL);
                    clErrCheck(err, "clGetDeviceInfo - Getting device clock frequency");
                    printf_s("Clock Frequency: %iMHz\n", temp_int);
                }
                free(devices); // Free devices array for current platform
            }
            free(platforms); // Free platforms array
            if (foundDevice == 0) {
                printf_s("No OpenCL devices found.\n");
            }
            return 0;
        }
    }

    if (config.numNeeds == 0 && config.numWants == 0) {
        printf_s("Warning: No Needs or Wants specified via args, using hardcoded example (Perkeo/Canio).\n");
        config.Needs[0] = 149; // Perkeo
        config.numNeeds = 1;
        config.Wants[0] = 145; // Canio
        config.numWants = 1;
        config.needByAnte = 4;
        config.wantByAnte = 4;
        config.needByAntePerkeo = 2;
    }

    cl_int err;

    // --- Platform and Device Setup ---
    cl_uint numPlatforms;
    err = clGetPlatformIDs(0, NULL, &numPlatforms);
    clErrCheck(err, "clGetPlatformIDs - Getting number of available OpenCL platforms");

    if (numPlatforms == 0) {
        printf_s("No OpenCL platforms found.\n");
        return 0;
    }
    if (platformID > numPlatforms-1) {
        printf_s("Platform ID %i not found.\n", platformID);
        return 0;
    }

    cl_platform_id* platforms = malloc(sizeof(cl_platform_id) * numPlatforms);

    err = clGetPlatformIDs(numPlatforms, platforms, NULL);
    clErrCheck(err, "clGetPlatformIDs - Getting list of availble OpenCL platforms");
    cl_platform_id platform = platforms[platformID];

    cl_uint numDevices;
    err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, 0, NULL, &numDevices);
    clErrCheck(err, "clGetDeviceIDs - Getting number of available OpenCL devices");

    if (numDevices == 0) {
        printf_s("No OpenCL devices found for platform %i.\n", platformID);
        free(platforms);
        return 0;
    }
    if (deviceID > numDevices-1) {
        printf_s("Device ID %i not found.\n", deviceID);
        free(platforms);
        return 0;
    }

    cl_device_id* devices = malloc(sizeof(cl_device_id) * numDevices);
    err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, numDevices, devices, NULL);
    clErrCheck(err, "clGetDeviceIDs - Getting list of available OpenCL devices");
    cl_device_id device = devices[deviceID];

    cl_context ctx = clCreateContext(NULL, 1, &device, NULL, NULL, &err);
    clErrCheck(err, "clCreateContext - Creating OpenCL context");

    cl_command_queue queue = clCreateCommandQueue(ctx, device, 0, &err);
    clErrCheck(err, "clCreateCommandQueue - Creating OpenCL command queue");

    // --- Kernel Loading/Building ---
    FILE *fp;
    char *ssKernelCode = NULL;
    size_t ssKernelSize = 0;
    cl_program ssKernelProgram;
    int loaded_from_binary = 0;

    char executable_dir[MAX_PATH];
    char include_path[MAX_PATH+6];
    char kernel_path[MAX_PATH+12];
    char binary_path[MAX_PATH];
    getExecutableDir(executable_dir);

    strcpy_s(include_path, sizeof include_path, "-I \"");
    strcat_s(include_path, sizeof include_path, executable_dir);
    strcat_s(include_path, sizeof include_path, "\"");

    createBinaryPath(executable_dir, filter, binary_path, MAX_PATH);

    fp = fopen(binary_path, "rb");
    if (fp) {
        printf_s("Found pre-compiled kernel binary: %s\n", binary_path);
        fseek(fp, 0, SEEK_END);
        size_t binary_size = ftell(fp);
        rewind(fp);
        unsigned char *program_binary = (unsigned char*)malloc(binary_size);
        if (!program_binary) {
            fprintf_s(stderr, "Failed to allocate memory for kernel binary.\n");
            fclose(fp);
        } else {
            if (fread(program_binary, 1, binary_size, fp) != binary_size) {
                fprintf_s(stderr, "Failed to read kernel binary.\n");
                free(program_binary);
                fclose(fp);
            } else {
                fclose(fp);
                cl_int binary_status;
                ssKernelProgram = clCreateProgramWithBinary(ctx, 1, &device, &binary_size, (const unsigned char**)&program_binary, &binary_status, &err);
                free(program_binary);

                if (err == CL_SUCCESS && binary_status == CL_SUCCESS) {
                    printf_s("Successfully loaded kernel from binary.\n");
                    loaded_from_binary = 1;
                } else {
                    fprintf_s(stderr, "Failed to create program from binary (err: %d, status: %d). Compiling from source...\n", err, binary_status);
                }
            }
        }
    } else {
        printf_s("No pre-compiled kernel binary found. Compiling from source...\n");
    }

    if (!loaded_from_binary) {
        strcpy_s(kernel_path, sizeof kernel_path, executable_dir);
        strcat_s(kernel_path, sizeof kernel_path, PATH_SEPARATOR);
        strcat_s(kernel_path, sizeof kernel_path, "ouiji-search.cl");

        fp = fopen(kernel_path, "r");
        if (!fp) {
            printf_s("Warning: Kernel source not found at %s, attempting working directory...\n", kernel_path);
            fp = fopen("ouiji-search.cl","r");
            if (!fp) {
                fprintf_s(stderr, "Failed to load kernel source.\n");
                free(devices);
                free(platforms);
                clReleaseCommandQueue(queue);
                clReleaseContext(ctx);
                exit(1);
            }
        }

        ssKernelCode = (char*)malloc(MAX_CODE_SIZE);
        char* ssKernelBuf = (char*)malloc(MAX_CODE_SIZE);
        if (!ssKernelCode || !ssKernelBuf) {
            fprintf_s(stderr, "Failed to allocate memory for kernel source code.\n");
            if (fp) fclose(fp);
            free(devices);
            free(platforms);
            clReleaseCommandQueue(queue);
            clReleaseContext(ctx);
            exit(1);
        }

        strcpy_s(ssKernelCode, MAX_CODE_SIZE, "#include \"filters/");
        strcat_s(ssKernelCode, MAX_CODE_SIZE, filter);
        strcat_s(ssKernelCode, MAX_CODE_SIZE, ".cl\"\n\n");

        size_t current_len = strlen(ssKernelCode);
        size_t bytes_read = fread( ssKernelBuf, 1, MAX_CODE_SIZE - current_len - 1, fp);
        ssKernelBuf[bytes_read] = '\0';
        strcat_s(ssKernelCode, MAX_CODE_SIZE, ssKernelBuf);
        ssKernelSize = strlen(ssKernelCode);
        fclose( fp );
        free(ssKernelBuf);

        ssKernelProgram = clCreateProgramWithSource(ctx, 1, (const char**)&ssKernelCode, (const size_t*)&ssKernelSize, &err);
        clErrCheck(err, "clCreateProgramWithSource - Creating OpenCL program from source");
    }

    printf_s("Building program...\n");
    err = clBuildProgram(ssKernelProgram, 1, &device, include_path, NULL, NULL);
    if (err == CL_BUILD_PROGRAM_FAILURE) {
        size_t logLength = 0;
        err = clGetProgramBuildInfo(ssKernelProgram, device, CL_PROGRAM_BUILD_LOG, 0, NULL, &logLength);
        if (err != CL_SUCCESS) {
            printf_s("Error getting build log length: %d\n", err);
            if (ssKernelCode != NULL) free(ssKernelCode);
            free(devices);
            free(platforms);
            clReleaseCommandQueue(queue);
            clReleaseContext(ctx);
            exit(EXIT_FAILURE);
        }
        char *buf = calloc(logLength, sizeof(char));
        if (!buf) {
            printf_s("Error allocating memory for build log\n");
            if (ssKernelCode != NULL) free(ssKernelCode);
            free(devices);
            free(platforms);
            clReleaseCommandQueue(queue);
            clReleaseContext(ctx);
            exit(EXIT_FAILURE);
        }
        err = clGetProgramBuildInfo(ssKernelProgram, device, CL_PROGRAM_BUILD_LOG, logLength, buf, NULL);
        if (err != CL_SUCCESS) {
            printf_s("Error getting build log: %d\n", err);
            free(buf);
            if (ssKernelCode != NULL) free(ssKernelCode);
            free(devices);
            free(platforms);
            clReleaseCommandQueue(queue);
            clReleaseContext(ctx);
            exit(EXIT_FAILURE);
        }
        printf_s("%s", buf);
        printf_s("\n");
        free(buf);
    }
    clErrCheck(err, "clBuildProgram - Building OpenCL program");

    if (ssKernelCode != NULL) {
        free(ssKernelCode);
        ssKernelCode = NULL;
    }

    if (!loaded_from_binary) {
        printf_s("Saving compiled kernel to binary: %s\n", binary_path);
        size_t binary_size;
        err = clGetProgramInfo(ssKernelProgram, CL_PROGRAM_BINARY_SIZES, sizeof(size_t), &binary_size, NULL);
        clErrCheck(err, "clGetProgramInfo - Getting binary size");

        if (binary_size > 0) {
            unsigned char *program_binary = (unsigned char*)malloc(binary_size);
            if (!program_binary) {
                fprintf_s(stderr, "Failed to allocate memory for saving kernel binary.\n");
            } else {
                unsigned char* p_binary = program_binary;
                err = clGetProgramInfo(ssKernelProgram, CL_PROGRAM_BINARIES, sizeof(unsigned char*), &p_binary, NULL);
                clErrCheck(err, "clGetProgramInfo - Getting program binary");

                fp = fopen(binary_path, "wb");
                if (!fp) {
                    fprintf_s(stderr, "Failed to open binary file for writing: %s\n", binary_path);
                } else {
                    if (fwrite(program_binary, 1, binary_size, fp) != binary_size) {
                        fprintf_s(stderr, "Failed to write kernel binary to file.\n");
                    } else {
                        printf_s("Successfully saved kernel binary.\n");
                    }
                    fclose(fp);
                }
                free(program_binary);
            }
        } else {
            fprintf_s(stderr, "Warning: Compiled program binary size is 0.\n");
        }
    }

    cl_kernel ssKernel = clCreateKernel(ssKernelProgram, "search", &err);
    clErrCheck(err, "clCreateKernel - Creating OpenCL kernel");

    cl_mem configBuf = clCreateBuffer(ctx, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, sizeof(OuijiConfig), &config, &err);
    clErrCheck(err, "clCreateBuffer - Creating config buffer");

    cl_mem resultsBuf = clCreateBuffer(ctx, CL_MEM_WRITE_ONLY, sizeof(ResultInfo) * MAX_RESULTS_BUFFER, NULL, &err);
    clErrCheck(err, "clCreateBuffer - Creating results buffer");

    cl_uint initial_result_count = 0;
    cl_mem resultCountBuf = clCreateBuffer(ctx, CL_MEM_READ_WRITE | CL_MEM_COPY_HOST_PTR, sizeof(cl_uint), &initial_result_count, &err);
    clErrCheck(err, "clCreateBuffer - Creating result count buffer");

    err = clSetKernelArg(ssKernel, 0, sizeof(startingSeed), &startingSeed);
    clErrCheck(err, "clSetKernelArg - Adding starting seed argument");
    err = clSetKernelArg(ssKernel, 1, sizeof(numSeeds), &numSeeds);
    clErrCheck(err, "clSetKernelArg - Adding number of seeds argument");

    err = clSetKernelArg(ssKernel, 3, sizeof(cl_mem), &configBuf);
    clErrCheck(err, "clSetKernelArg - Adding config struct argument");

    err = clSetKernelArg(ssKernel, 4, sizeof(cl_mem), &resultsBuf);
    clErrCheck(err, "clSetKernelArg - Adding results buffer argument");

    err = clSetKernelArg(ssKernel, 5, sizeof(cl_mem), &resultCountBuf);
    clErrCheck(err, "clSetKernelArg - Adding result count argument");

    size_t globalSize = numGroups * numGroups;
    size_t localSize = numGroups;
    printf_s("Starting searcher with cutoff %ld...\n", config.cutoff);
    clock_t begin = clock();
    err = clEnqueueNDRangeKernel(queue, ssKernel, 1, NULL, &globalSize, &localSize, 0, NULL, NULL);
    clErrCheck(err, "clEnqueueNDRangeKernel - Executing OpenCL kernel");

    err = clFinish(queue);
    clErrCheck(err, "clFinish - Waiting for kernel completion");
    clock_t end = clock();

    cl_uint final_result_count = 0;
    err = clEnqueueReadBuffer(queue, resultCountBuf, CL_TRUE, 0, sizeof(cl_uint), &final_result_count, 0, NULL, NULL);
    clErrCheck(err, "clEnqueueReadBuffer - Reading result count");

    printf_s("Kernel finished. Found %u potential results (up to buffer limit %d).\n", final_result_count, MAX_RESULTS_BUFFER);

    ResultInfo* host_results = NULL;
    cl_uint results_to_read = (final_result_count < MAX_RESULTS_BUFFER) ? final_result_count : MAX_RESULTS_BUFFER;

    if (results_to_read > 0) {
        host_results = (ResultInfo*)malloc(sizeof(ResultInfo) * results_to_read);
        if (!host_results) {
            fprintf_s(stderr, "Failed to allocate memory for host results buffer.\n");
            err = clReleaseMemObject(resultCountBuf);
            err = clReleaseMemObject(resultsBuf);
            err = clReleaseMemObject(configBuf);
            err = clReleaseKernel(ssKernel);
            err = clReleaseProgram(ssKernelProgram);
            err = clReleaseCommandQueue(queue);
            err = clReleaseContext(ctx);
            free(devices);
            free(platforms);
            exit(EXIT_FAILURE);
        } else {
            err = clEnqueueReadBuffer(queue, resultsBuf, CL_TRUE, 0, sizeof(ResultInfo) * results_to_read, host_results, 0, NULL, NULL);
            clErrCheck(err, "clEnqueueReadBuffer - Reading results buffer");

            printf_s("--- Found Seeds ---\n");
            for (cl_uint i = 0; i < results_to_read; ++i) {
                char seed_str[9];
                seedToString(host_results[i]._seed, seed_str, sizeof(seed_str));
                printf("FOUND_SEED: %s SCORE: %ld WANTS_MASK: %u\n",
                       seed_str,
                       host_results[i].score,
                       host_results[i].wants_mask);
            }
            printf_s("-------------------\n");
        }
    }

    if (host_results) {
        free(host_results);
    }
    err = clReleaseMemObject(resultCountBuf);
    err = clReleaseMemObject(resultsBuf);
    err = clReleaseMemObject(configBuf);
    err = clReleaseKernel(ssKernel);
    err = clReleaseProgram(ssKernelProgram);
    err = clReleaseCommandQueue(queue);
    err = clReleaseContext(ctx);

    free(devices);
    free(platforms);

    double time_spent = (double)(end-begin) / CLOCKS_PER_SEC;
    printf("Done in %fs\n",time_spent);

    return EXIT_SUCCESS;
}