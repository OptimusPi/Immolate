#include "lib/ouija.h"
#include "lib/host_items.h"
#include "lib/ouija_config_loader.h"
#include "lib/ouija_host_result.h"
#include "lib/utils.h"

#include <time.h>
#include <CL/cl.h>

#define NUM_RESULT_BUFFERS 2 // For double buffering
#define DEFAULT_BATCH_MULTIPLIER 1 // Default batch size multiplier (workgroup * warp * multiplier)

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
    printf_s("Ouija Beta v1.0.1f.1\n");
    fflush(stdout);

    // Handle CLI arguments
    unsigned int platformID = 0;
    unsigned int deviceID = 0;
    size_t numGroups = 16;
    cl_char8 startingSeed; // Keep as cl_char8
    for (int i = 0; i < 8; i++) {
        startingSeed.s[i] = '\0';
    };
    cl_long numSeeds = 2318107019761; // Keep as cl_long to match OpenCL's 64-bit type
    // Default config values
    OuijaConfig config;
    config.numNeeds = 0;         // Default number of needs
    config.numWants = 0;         // Default number of wants
    config.maxSearchAnte = 8;    // Default maximum ante to search through
    int batchResultsMode = 0;    // Default: use original mode, not batching results mode
    cl_uint batchMultiplier = DEFAULT_BATCH_MULTIPLIER; // Default batch multiplier (workgroup * multiplier seeds per batch)

    char* filter = "ouija_template"; // Default filter
    char* config_file = NULL;  // Configuration file path
    int fixedCutoffMode = 0; // Flag for fixed cutoff mode
    int cutoff = 1; // Default cutoff

    // --- Argument Parsing Loop ---
    for (int i = 0; i < argc; i++) {
        if (strcmp(argv[i], "-h")==0) {
            printf_s("Valid command line arguments:\n-h        Shows this help dialog.\n-f <F>    Sets the filter used by Ouija to F. Defaults to ouija_template\n-s <S>    Sets the starting seed to S. Defaults to empty seed. Use \"random\" for a random starting seed.\n-n <N>    Sets the number of seeds to search to N. Defaults to full seed pool.\n-c <C>    Sets the cutoff score for a seed to be printed to C. Defaults to 1.\n-p <P>    Sets the platform ID of the CL device being used to P. Defaults to 0.\n-d <D>    Sets the device ID of the CL device being used to D. Defaults to 0.\n-g <G>    Sets the number of thread groups to G. Defaults to 16. Increasing this might help Ouija run faster.\n-b <B>    Sets batch multiplier to B. Higher values process more seeds per batch. Defaults to 100.\n--config <JSON>  Load configuration from a JSON file.\n--list_devices   Lists information about the detected CL devices.\n--gui    Enables GUI streaming mode.");
            return 0;
        }
        if (strcmp(argv[i], "--config")==0 && i + 1 < argc) {
            config_file = argv[i+1];
            printf_s("Using configuration file: %s\n", config_file);
            i++;
        }
        if (strcmp(argv[i], "-b")==0) {
            if (i + 1 < argc) {
                batchMultiplier = (cl_uint)atoi(argv[i+1]);
                printf_s("Batch multiplier set to %u\n", batchMultiplier);
                i++;
            } else {
                batchResultsMode = 1;
                printf_s("Batch results mode enabled. Results will be collected and processed in batches.\n");
            }
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
            numSeeds = (long long)strtoll(argv[i+1], NULL, 10);
            i++;
        }
        if (strcmp(argv[i],  "-c")==0) {
            cutoff = (int)strtoll(argv[i+1], NULL, 10);
            fixedCutoffMode = 1;
            i++;
        }
        if (strcmp(argv[i],  "-s")==0) {
            int seedLength = (int)strlen(argv[i+1]);
            if (strcmp(argv[i+1],"random")==0 || seedLength > 8) {
                if (seedLength > 8) {
                    printf_s("Invalid seed length! ");
                } 
                printf_s("Generating random seed...\n");
                srand((unsigned int)time(NULL));
                char seedCharacters[] = {'1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'};
                startingSeed.s[0] = seedCharacters[rand() % 35];
                startingSeed.s[1] = seedCharacters[rand() % 35];
                startingSeed.s[2] = seedCharacters[rand() % 35];
                startingSeed.s[3] = seedCharacters[rand() % 35];
                startingSeed.s[4] = seedCharacters[rand() % 35];
                startingSeed.s[5] = seedCharacters[rand() % 35];
                startingSeed.s[6] = seedCharacters[rand() % 35];
                startingSeed.s[7] = seedCharacters[rand() % 35];
            } else {
                for (int j = 0; j < seedLength; j++) {
                    startingSeed.s[j] = argv[i+1][j];
                }
                for (int j = seedLength; j < 8; j++) {
                    startingSeed.s[j] = '\0';
                }
            }
            // Create a proper null-terminated string for printing
            char seedStr[9];
            for (int j = 0; j < 8 && startingSeed.s[j] != '\0'; j++) {
                seedStr[j] = startingSeed.s[j];
                seedStr[j+1] = '\0';  // Ensure null termination
            }
            printf_s("Starting seed set to %s\n", seedStr);
            fflush(stdout);
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

                    err = clGetDeviceInfo(devices[d], CL_DEVICE_MAX_COMPUTE_UNITS, sizeof(buf), &buf, NULL);
                    clErrCheck(err, "clGetDeviceInfo - Getting device compute units");
                    printf_s("Compute Units: %s\n", buf);

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
    cl_int err;

    // Handle loading configuration from file if specified
    if (config_file != NULL) {
        if (!load_config_from_json(config_file, &config)) {
            printf_s("Failed to load configuration from %s. Using default configuration.\n", config_file);
        } else {
            printf_s("Configuration loaded: %d needs and %d wants, with max ante %d\n", 
                    config.numNeeds, config.numWants, config.maxSearchAnte);
            
            // Print needs information
            if (config.numNeeds > 0) {
                printf_s("Needs:\n");
                for (int i = 0; i < config.numNeeds && i < MAX_DESIRES_HOST; i++) {
                    printf_s("  - Item %i by ante %d\n", 
                        config.Needs[i].value, config.Needs[i].desireByAnte);
                }
            }
            
            // Print wants information
            if (config.numWants > 0) {
                printf_s("Wants:\n");
                for (int i = 0; i < config.numWants && i < MAX_DESIRES_HOST; i++) {
                    printf_s("  - ");
                    print_item_host(config.Wants[i].value);
                    printf("\n");
                }
            }
        }
    }

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

    // Using regular OpenCL buffers for device memory operations
    cl_bool svm_supported = CL_FALSE; // Force SVM disabled
    
    cl_context ctx = clCreateContext(NULL, 1, &device, NULL, NULL, &err);
    clErrCheck(err, "clCreateContext - Creating OpenCL context");

    cl_command_queue queue = clCreateCommandQueue(ctx, device, 0, &err);
    clErrCheck(err, "clCreateCommandQueue - Creating OpenCL command queue");

    // Print GPU details for the selected device
    cl_uint compute_units = 0;
    cl_uint warp_size = 32; // Default warp size for most GPUs (NVIDIA)
    err = clGetDeviceInfo(device, CL_DEVICE_MAX_COMPUTE_UNITS, sizeof(compute_units), &compute_units, NULL);
    if (err == CL_SUCCESS) {
        printf_s("Using device with %u compute units\n", compute_units);
    } 

    // --- Kernel Loading/Building ---
    FILE *fp;
    char *ssKernelCode = NULL;
    size_t ssKernelSize = 0;
    cl_program ssKernelProgram;
    int loaded_from_binary = 0;

    // Create config buffer
    cl_mem configBuf = clCreateBuffer(ctx, CL_MEM_READ_ONLY, sizeof(OuijaConfig), NULL, &err);
    clErrCheck(err, "clCreateBuffer - Creating config buffer");
    
    // Copy config to buffer
    err = clEnqueueWriteBuffer(queue, configBuf, CL_TRUE, 0, sizeof(OuijaConfig), &config, 0, NULL, NULL);
    clErrCheck(err, "clEnqueueWriteBuffer - Copying config to buffer");

    // --- NEW: Create seed offset buffer ---
    cl_mem seedOffsetBuf = clCreateBuffer(ctx, CL_MEM_READ_ONLY, sizeof(cl_long), NULL, &err);
    clErrCheck(err, "clCreateBuffer - Creating seed offset buffer");

    char executable_dir[MAX_PATH];
    char include_path[MAX_PATH+6];
    char kernel_path[MAX_PATH+12];
    char binary_path[MAX_PATH];
    getExecutableDir(executable_dir);

    strcpy_s(include_path, sizeof include_path, "-I \"");
    strcat_s(include_path, sizeof include_path, executable_dir);
    strcat_s(include_path, sizeof include_path, "\"");

    createBinaryPath(executable_dir, filter, binary_path, MAX_PATH);

    err = fopen_s(&fp, binary_path, "rb");
    if (err == 0 && fp != NULL) {
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
                exit(1);
            }
            else
            {
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
        printf_s("No pre-compiled kernel binary found.\n");
    }

    if (!loaded_from_binary) {
        strcpy_s(kernel_path, sizeof kernel_path, executable_dir);
        strcat_s(kernel_path, sizeof kernel_path, PATH_SEPARATOR);
        strcat_s(kernel_path, sizeof kernel_path, "ouija_search.cl");

        err = fopen_s(&fp, kernel_path, "r");
        if (!fp) {
            printf_s("Warning: Kernel source not found at %s, attempting working directory...\n", kernel_path);
            err = fopen_s(&fp, "ouija_search.cl", "r");
            if (err != 0 || !fp) {
                fprintf_s(stderr, "Failed to load kernel source.\n");
                free(devices);
                free(platforms);
                clReleaseCommandQueue(queue);
                clReleaseContext(ctx);
                exit(1);
            }
        }
        printf_s("Loading kernel source from %s...\n", kernel_path);

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

        printf_s("Kernel source loaded. Size: %zu bytes.\n", ssKernelSize);

        ssKernelProgram = clCreateProgramWithSource(ctx, 1, (const char**)&ssKernelCode, (const size_t*)&ssKernelSize, &err);
        clErrCheck(err, "clCreateProgramWithSource - Creating OpenCL program from source");
    } else {
        printf_s("Using pre-compiled kernel binary.\n");
    }
    printf_s("Building OpenCL Program...\n");

    // Add -cl-mad-enable to build options, and also testing out fast relaxed math right now!
    char build_options[1024];
    snprintf(build_options, sizeof(build_options), "%s -cl-mad-enable -cl-finite-math-only -Werror -cl-unsafe-math-optimizations -cl-no-signed-zeros", include_path);
    err = clBuildProgram(ssKernelProgram, 1, &device, build_options, NULL, NULL);
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
    printf_s("OpenCL Program compiled successfully.\n");

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

                errno_t fopen_err = fopen_s(&fp, binary_path, "wb");
                if (fopen_err != 0) {
                    fprintf_s(stderr, "Failed to open binary file for writing: %s (error code: %d)\n", binary_path, fopen_err);
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

    printf("Kernel program built successfully. Setting Parameters\n");

    // Load and create kernel
    cl_kernel ssKernel = clCreateKernel(ssKernelProgram, "ouija_search", &err);
    clErrCheck(err, "clCreateKernel - Creating OpenCL kernel");

    // Common kernel argument setup:
    err = clSetKernelArg(ssKernel, 0, sizeof(cl_char8), &startingSeed);
    clErrCheck(err, "clSetKernelArg - Setting starting seed");

    err = clSetKernelArg(ssKernel, 1, sizeof(cl_long), &numSeeds);
    clErrCheck(err, "clSetKernelArg - Setting number of seeds");

    err = clSetKernelArg(ssKernel, 2, sizeof(cl_mem), &configBuf);
    clErrCheck(err, "clSetKernelArg - Setting config buffer");

    size_t max_work_group_size;
    err = clGetKernelWorkGroupInfo(ssKernel, device, CL_KERNEL_WORK_GROUP_SIZE, sizeof(size_t), &max_work_group_size, NULL);
    clErrCheck(err, "clGetKernelWorkGroupInfo - Getting max work group size");
    
    if (!err) {
        if (numGroups > max_work_group_size) {
            numGroups = max_work_group_size;
            printf_s("Warning: numGroups specified is larger than max work group size! Falling back to %zu\n", numGroups);
        }
    }
    
    // Set local work size to numGroups
    cl_long localWorkSize = numGroups;
    printf_s("Using local work size of %lld\n", localWorkSize);

    cl_event kernel_events[NUM_RESULT_BUFFERS] = {NULL};
    cl_long dispatched_kernel_seeds[NUM_RESULT_BUFFERS] = {0}; // ADDED: Track seeds per buffer/event
    int current_buffer_idx = 0;
    cl_long seeds_processed_total = 0; // Counts valid, non-empty results from kernel
    cl_long seeds_scored_total = 0;    // Counts results that meet the cutoff score

    // Define the maximum capacity of a single batch based on device and multiplier
    cl_long batch_capacity = numGroups * compute_units * batchMultiplier;
    if (batch_capacity == 0) batch_capacity = 1; // Ensure batch_capacity is at least 1

    // Create result buffers for alternating between batches, sized by batch_capacity
    cl_mem* resultBuf_dev = (cl_mem*)malloc(NUM_RESULT_BUFFERS * sizeof(cl_mem));

    for (int i = 0; i < NUM_RESULT_BUFFERS; ++i) {
        resultBuf_dev[i] = clCreateBuffer(ctx, CL_MEM_WRITE_ONLY | CL_MEM_ALLOC_HOST_PTR, 
                                       sizeof(OuijaHostResult) * batch_capacity, NULL, &err); // Use batch_capacity
        clErrCheck(err, "clCreateBuffer - Creating result buffer on device");
    }

    // Calculate the total number of batches potentially required
    cl_long total_potential_batches = (numSeeds + batch_capacity - 1) / batch_capacity;
    
    cl_long cumulative_seeds_dispatched = 0; // Total seeds dispatched to kernels
    cl_long seed_offset_for_kernel = 0;      // Starting seed offset for the current kernel dispatch
    cl_long num_seeds_this_dispatch = 0;     // Number of seeds for the kernel dispatch being prepared
    cl_long num_seeds_last_dispatch = 0;     // Number of seeds processed by the completed kernel whose results are being read


    // Print the CSV header for any consuming applications such as the python mvc.
     printf_s("Seed,Score,NegativeJokers");
    for (int w = 0; w < config.numWants && w < MAX_DESIRES_HOST; w++) {
        printf_s(",");
        print_item_host(config.Wants[w].value);
    }
    printf_s("\n");
    fflush(stdout);

    // --- Initial Kernel Launch ---
    if (numSeeds > 0) {
        num_seeds_this_dispatch = (numSeeds > batch_capacity) ? batch_capacity : numSeeds;
        seed_offset_for_kernel = 0; // First batch starts at offset 0 from startingSeed

        err = clSetKernelArg(ssKernel, 0, sizeof(cl_char8), &startingSeed);
        clErrCheck(err, "clSetKernelArg - Setting starting seed for initial batch");
        err = clSetKernelArg(ssKernel, 1, sizeof(cl_long), &num_seeds_this_dispatch);
        clErrCheck(err, "clSetKernelArg - Setting num_seeds for initial batch");
        err = clSetKernelArg(ssKernel, 2, sizeof(cl_mem), &configBuf);
        clErrCheck(err, "clSetKernelArg - Setting config buffer for initial batch");
        err = clSetKernelArg(ssKernel, 3, sizeof(cl_mem), &resultBuf_dev[current_buffer_idx]);
        clErrCheck(err, "clSetKernelArg - Setting result buffer for initial batch");
        err = clSetKernelArg(ssKernel, 4, sizeof(cl_mem), &seedOffsetBuf);
        clErrCheck(err, "clSetKernelArg - Setting seed offset buffer for initial batch");

        err = clEnqueueWriteBuffer(queue, seedOffsetBuf, CL_TRUE, 0, sizeof(cl_long), &seed_offset_for_kernel, 0, NULL, NULL);
        clErrCheck(err, "clEnqueueWriteBuffer - Writing initial seed offset");

        size_t global_work_size_init = (size_t)((num_seeds_this_dispatch + localWorkSize - 1) / localWorkSize) * localWorkSize;
        if (global_work_size_init == 0 && num_seeds_this_dispatch > 0) global_work_size_init = localWorkSize; // Ensure it's not 0 if seeds > 0
        size_t local_work_size_init = (size_t)localWorkSize;
        if (num_seeds_this_dispatch == 0) global_work_size_init = 0; // No work if no seeds


        if (num_seeds_this_dispatch > 0) {
             err = clEnqueueNDRangeKernel(queue, ssKernel, 1, NULL, &global_work_size_init, &local_work_size_init, 0, NULL, &kernel_events[current_buffer_idx]);
             clErrCheck(err, "clEnqueueNDRangeKernel - Initial kernel execution");
        } else {
            kernel_events[current_buffer_idx] = NULL; // No kernel launched
        }
        dispatched_kernel_seeds[current_buffer_idx] = num_seeds_this_dispatch; // ADDED: Store seeds for this launch
        cumulative_seeds_dispatched += num_seeds_this_dispatch;
    }
    // --- End of Initial Kernel Launch ---

    clock_t start_time = clock();
    clock_t ticker = clock();
    if (numSeeds > 0) { // Only print if we are actually searching
        printf_s("Starting seed search...\n");
        fflush(stdout);
    }
    
    // Main processing loop
    for (cl_long batch_idx = 0; batch_idx < total_potential_batches; ++batch_idx) {
        if (num_seeds_this_dispatch == 0 && batch_idx ==0) { // Handles -n 0 case or if first dispatch was 0 seeds
            break;
        }
        // MODIFIED: Determine results buffer and seed count for it
        int results_buffer_idx = current_buffer_idx; 
        num_seeds_last_dispatch = dispatched_kernel_seeds[results_buffer_idx];

        if (kernel_events[results_buffer_idx] != NULL) {
            err = clWaitForEvents(1, &kernel_events[results_buffer_idx]);
            clErrCheck(err, "clWaitForEvents - Waiting for kernel completion");
            clReleaseEvent(kernel_events[results_buffer_idx]);
            kernel_events[results_buffer_idx] = NULL;
        } else if (num_seeds_last_dispatch > 0) { // Only warn if we expected an event
            printf_s("Warning: No event to wait for for buffer index %d, but expected %lld seeds.\n", results_buffer_idx, num_seeds_last_dispatch);
        }
        
        if (num_seeds_last_dispatch > 0) { // Only map and process if the last dispatch had seeds
            //printf_s("Batch %lld/%lld (Processing results for %lld seeds)\n", batch_idx, total_potential_batches, num_seeds_last_dispatch);
            //fflush(stdout);

            OuijaHostResult* mapped_results = (OuijaHostResult*)clEnqueueMapBuffer(queue, resultBuf_dev[results_buffer_idx], CL_TRUE,
                                               CL_MAP_READ, 0, sizeof(OuijaHostResult) * num_seeds_last_dispatch, 0, NULL, NULL, &err);
            clErrCheck(err, "clEnqueueMapBuffer - Mapping result buffer");
            
            for (cl_long i = 0; i < num_seeds_last_dispatch; ++i) {
                OuijaHostResult* result = &mapped_results[i];
                if (result->seed[0] == '\0') continue; // Skip if kernel returned empty seed (e.g. error or no actual processing)
                seeds_processed_total++; // Count actual non-empty results processed
                if (result->TotalScore < cutoff) continue;
                seeds_scored_total++;
                printf_s("|%s,%d,%d",
                            result->seed,
                            result->TotalScore,
                            result->NegativeJokers);
                for (int w = 0; w < config.numWants && w < MAX_DESIRES_HOST; w++) {
                    printf_s(",%d", (int)result->ScoreWants[w]);
                }
                printf_s("\n");
            }
            fflush(stdout);
            
            err = clEnqueueUnmapMemObject(queue, resultBuf_dev[results_buffer_idx], mapped_results, 0, NULL, NULL);
            clErrCheck(err, "clEnqueueUnmapMemObject - Unmapping result buffer");
        }
        
        // Check if all requested seeds have been dispatched
        if (cumulative_seeds_dispatched >= numSeeds) {
            break; 
        }

        // --- Prepare and Launch Next Kernel ---
        current_buffer_idx = (current_buffer_idx + 1) % NUM_RESULT_BUFFERS; // Advance for the next launch

        seed_offset_for_kernel = cumulative_seeds_dispatched;
        cl_long remaining_overall_seeds = numSeeds - cumulative_seeds_dispatched;
        
        if (remaining_overall_seeds <= 0) break; // Should be caught by earlier check, but as a safeguard

        num_seeds_this_dispatch = (remaining_overall_seeds > batch_capacity) ? batch_capacity : remaining_overall_seeds;

        err = clSetKernelArg(ssKernel, 0, sizeof(cl_char8), &startingSeed);  
        clErrCheck(err, "clSetKernelArg - Setting starting seed for current batch");
        err = clSetKernelArg(ssKernel, 1, sizeof(cl_long), &num_seeds_this_dispatch);
        clErrCheck(err, "clSetKernelArg - Setting num_seeds for current batch");
        // Config buffer (arg 2) is already set and doesn't change
        err = clSetKernelArg(ssKernel, 3, sizeof(cl_mem), &resultBuf_dev[current_buffer_idx]);
        clErrCheck(err, "clSetKernelArg - Setting result buffer for current launch");
        // Seed offset buffer (arg 4) is already set
        
        err = clEnqueueWriteBuffer(queue, seedOffsetBuf, CL_TRUE, 0, sizeof(cl_long), &seed_offset_for_kernel, 0, NULL, NULL);
        clErrCheck(err, "clEnqueueWriteBuffer - Updating seed offset for current batch");

        size_t global_work_size_next = (size_t)((num_seeds_this_dispatch + localWorkSize - 1) / localWorkSize) * localWorkSize;
        if (global_work_size_next == 0 && num_seeds_this_dispatch > 0) global_work_size_next = localWorkSize;
        size_t local_work_size_next = (size_t)localWorkSize;
        if (num_seeds_this_dispatch == 0) global_work_size_next = 0;

        // Clean the result buffer before dispatching kernel
        OuijaHostResult* mapped_results = (OuijaHostResult*)clEnqueueMapBuffer(queue, resultBuf_dev[current_buffer_idx], CL_TRUE,
                                               CL_MAP_WRITE, 0, sizeof(OuijaHostResult) * num_seeds_this_dispatch, 0, NULL, NULL, &err);
        clErrCheck(err, "clEnqueueMapBuffer - Mapping result buffer for clearing");
        for (cl_long i = 0; i < num_seeds_this_dispatch; i++) {
            memset(&mapped_results[i], 0, sizeof(OuijaHostResult));
        }
        err = clEnqueueUnmapMemObject(queue, resultBuf_dev[current_buffer_idx], mapped_results, 0, NULL, NULL);
        clErrCheck(err, "clEnqueueUnmapMemObject - Unmapping result buffer after clearing");

        if (clock() - ticker > 1000 && cumulative_seeds_dispatched > 0) { // Use cumulative_seeds_dispatched for progress
            ticker = clock();
            double elapsed_time = (double)(clock() - start_time) / CLOCKS_PER_SEC;
            double estimated_total_time = (elapsed_time / cumulative_seeds_dispatched) * numSeeds;
            double remaining_time = estimated_total_time - elapsed_time;

            printf_s("$Elapsed time: %.2f seconds, Estimated remaining time: %.2f seconds             $clock$%.1fK/s\n", 
                elapsed_time, remaining_time, (elapsed_time > 0) ? 
                    ((double)cumulative_seeds_dispatched / elapsed_time)*0.001f : 0.0);
            fflush(stdout);
        }
        
        if (num_seeds_this_dispatch > 0) {
            err = clEnqueueNDRangeKernel(queue, ssKernel, 1, NULL, &global_work_size_next, &local_work_size_next, 0, NULL, &kernel_events[current_buffer_idx]);
            clErrCheck(err, "clEnqueueNDRangeKernel - Subsequent kernel execution");
        } else {
            kernel_events[current_buffer_idx] = NULL; // No kernel launched
        }
        dispatched_kernel_seeds[current_buffer_idx] = num_seeds_this_dispatch; // ADDED: Store seeds for this launch
        cumulative_seeds_dispatched += num_seeds_this_dispatch;
        // --- End of Prepare and Launch Next Kernel ---
    }

    // After the loop, ensure any final outstanding kernel event is handled
    for (int i = 0; i < NUM_RESULT_BUFFERS; i++) {
        if (kernel_events[i] != NULL) {
            printf_s("Warning: Kernel event still active for buffer %d post-loop, waiting and releasing...\n", i);
            clWaitForEvents(1, &kernel_events[i]);
            clReleaseEvent(kernel_events[i]);
            kernel_events[i] = NULL;
        }
    }
    
    clFinish(queue); // Ensure all enqueued commands are finished
    
    double elaps = (double)(clock() - start_time) / CLOCKS_PER_SEC;
    cl_long reported_total_seeds = (numSeeds == 0 && cumulative_seeds_dispatched == 0) ? 0 : min(cumulative_seeds_dispatched, numSeeds);
    if (numSeeds > 0 && reported_total_seeds == 0 && cumulative_seeds_dispatched > 0) {
        reported_total_seeds = cumulative_seeds_dispatched;
    }

    printf_s("$Search Complete! Found %lli viable out of %lli total seeds @%.1f seeds/s\n",
        seeds_scored_total, reported_total_seeds,
        (elaps > 0 && reported_total_seeds > 0) ? ((double)reported_total_seeds / elaps) : 0.0);
    fflush(stdout);

    // --- Cleanup ---
    if (ssKernelCode != NULL) free(ssKernelCode);
    free(devices);
    free(platforms);

    for (int i = 0; i < NUM_RESULT_BUFFERS; ++i) {
        clReleaseMemObject(resultBuf_dev[i]);
        if(kernel_events[i] != NULL) clReleaseEvent(kernel_events[i]);
    }
    free(resultBuf_dev);
    clReleaseMemObject(configBuf);
    clReleaseMemObject(seedOffsetBuf);
    clReleaseKernel(ssKernel);
    clReleaseProgram(ssKernelProgram);
    clReleaseCommandQueue(queue);
    clReleaseContext(ctx);

    return 0;
}