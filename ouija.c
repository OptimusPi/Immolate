#include "lib/ouija.h"
#include "lib/host_items.h"
#include "lib/ouija_config_loader.h"
#include "lib/ouija_host_result.h"
#include "lib/utils.h"

#include <time.h>
#include <CL/cl.h>
#include <assert.h>

#define NUM_RESULT_BUFFERS 2       // For double buffering
#define DEFAULT_BATCH_MULTIPLIER 1 // Default batch size multiplier (workgroup * warp * multiplier)

// Helper function to create binary path
void createBinaryPath(const char *executable_dir, const char *filter_name, char *binary_path, size_t max_len)
{
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

int main(int argc, char **argv)
{

    // Print version
    printf_s("Ouija Beta v1.0.1f.1\n");
    fflush(stdout);

    // Handle CLI arguments
    unsigned int platformID = 0;
    unsigned int deviceID = 0;
    size_t numGroups = 16;
    cl_char8 startingSeed; // Keep as cl_char8
    for (int i = 0; i < 8; i++)
    {
        startingSeed.s[i] = '\0';
    }
    cl_long numSeeds = 2318107019761; // Keep as cl_long to match OpenCL's 64-bit type
    int cutoff = 1;                   // Default cutoff value for host-side filtering
    int auto_cutoff_mode = 0;         // 1 if -c auto, 0 if -c <number>
    // Default config values
    OuijaConfig config;
    config.numNeeds = 0;                                // Default number of needs
    config.numWants = 0;                                // Default number of wants
    config.maxSearchAnte = 8;                           // Default maximum ante to search through
    cl_uint batchMultiplier = DEFAULT_BATCH_MULTIPLIER; // Default batch multiplier (workgroup * multiplier seeds per batch)

    char *filter = "ouija_template"; // Default filter
    char *config_file = NULL;        // Configuration file path

    // --- Argument Parsing Loop ---
    for (int i = 0; i < argc; i++)
    {
        if (strcmp(argv[i], "-h") == 0)
        {
            printf_s("Valid command line arguments:\n-h        Shows this help dialog.\n-f <F>    Sets the filter used by Ouija to F. Defaults to ouija_template\n-s <S>    Sets the starting seed to S. Defaults to empty seed. Use \"random\" for a random starting seed.\n-n <N>    Sets the number of seeds to search to N. Defaults to full seed pool.\n-c <C>    Sets the cutoff score for filtering results. Only results with score >= C will be shown. Defaults to 1.\n-p <P>    Sets the platform ID of the CL device being used to P. Defaults to 0.\n-d <D>    Sets the device ID of the CL device being used to D. Defaults to 0.\n-g <G>    Sets the number of thread groups to G. Defaults to 16. Increasing this might help Ouija run faster.\n-b <B>    Sets batch multiplier to B. Higher values process more seeds per batch. Defaults to 100.\n--config <JSON>  Load configuration from a JSON file.\n--list_devices   Lists information about the detected CL devices.\n--gui    Enables GUI streaming mode.");
            return 0;
        }
        if (strcmp(argv[i], "--config") == 0 && i + 1 < argc)
        {
            config_file = argv[i + 1];
            printf_s("Using configuration file: %s\n", config_file);
            i++;
        }
        if (strcmp(argv[i], "-b") == 0)
        {
            if (i + 1 < argc)
            {
                batchMultiplier = (cl_uint)atoi(argv[i + 1]);
                printf_s("Batch multiplier set to %u\n", batchMultiplier);
                i++;
            }
        }
        if (strcmp(argv[i], "-p") == 0)
        {
            platformID = atoi(argv[i + 1]);
            i++;
        }
        if (strcmp(argv[i], "-f") == 0)
        {
            filter = argv[i + 1];
            i++;
        }
        if (strcmp(argv[i], "-d") == 0)
        {
            deviceID = atoi(argv[i + 1]);
            i++;
        }
        if (strcmp(argv[i], "-g") == 0)
        {
            numGroups = atoi(argv[i + 1]);
            i++;
        }
        if (strcmp(argv[i], "-n") == 0)
        {
            numSeeds = (long long)strtoll(argv[i + 1], NULL, 10);
            i++;
        }
        if (strcmp(argv[i], "-c") == 0)
        {
            if (strcmp(argv[i + 1], "auto") == 0)
            {
                auto_cutoff_mode = 1;
                cutoff = 1; // Start auto cutoff at 1
                printf_s("Cutoff set to AUTO (dynamic)\n");
            }
            else
            {
                cutoff = atoi(argv[i + 1]);
                auto_cutoff_mode = 0;
                printf_s("Cutoff set to %d\n", cutoff);
            }
            i++;
        }
        if (strcmp(argv[i], "-s") == 0)
        {
            int seedLength = (int)strlen(argv[i + 1]);
            if (strcmp(argv[i + 1], "random") == 0 || seedLength > 8)
            {
                if (seedLength > 8)
                {
                    printf_s("Invalid seed length! ");
                }
                printf_s("Generating random seed...\n");
                srand((unsigned int)time(NULL));
                char seedCharacters[] = {'1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'};
                startingSeed.s[0] = seedCharacters[rand() % 35];
                startingSeed.s[1] = seedCharacters[rand() % 35];
                startingSeed.s[2] = seedCharacters[rand() % 35];
                startingSeed.s[3] = seedCharacters[rand() % 35];
                startingSeed.s[4] = seedCharacters[rand() % 35];
                startingSeed.s[5] = seedCharacters[rand() % 35];
                startingSeed.s[6] = seedCharacters[rand() % 35];
                startingSeed.s[7] = seedCharacters[rand() % 35];
            }
            else
            {
                for (int j = 0; j < seedLength; j++)
                {
                    startingSeed.s[j] = argv[i + 1][j];
                }
                for (int j = seedLength; j < 8; j++)
                {
                    startingSeed.s[j] = '\0';
                }
            }
            // Create a proper null-terminated string for printing
            char seedStr[9];
            for (int j = 0; j < 8 && startingSeed.s[j] != '\0'; j++)
            {
                seedStr[j] = startingSeed.s[j];
                seedStr[j + 1] = '\0'; // Ensure null termination
            }
            printf_s("Starting seed set to %s\n", seedStr);
            fflush(stdout);
            i++;
        }
        if (strcmp(argv[i], "--list_devices") == 0)
        {
            cl_int err;
            char buf[1024];
            cl_uint temp_int;

            // Get # of OpenCL Platforms
            cl_uint numPlatforms;
            err = clGetPlatformIDs(0, NULL, &numPlatforms);
            clErrCheck(err, "clGetPlatformIDs - Getting number of available OpenCL platforms");

            // Nothing available? Then leave!
            if (numPlatforms == 0)
            {
                printf_s("No OpenCL devices found.\n");
                return 0;
            }

            // Now get OpenCL Platforms
            cl_platform_id *platforms = malloc(sizeof(cl_platform_id) * numPlatforms);

            err = clGetPlatformIDs(numPlatforms, platforms, NULL);
            clErrCheck(err, "clGetPlatformIDs - Getting list of availble OpenCL platforms");

            int foundDevice = 0;
            for (unsigned int p = 0; p < numPlatforms; p++)
            {
                cl_uint numDevices;
                err = clGetDeviceIDs(platforms[p], CL_DEVICE_TYPE_ALL, 0, NULL, &numDevices);
                clErrCheck(err, "clGetDeviceIDs - Getting number of available OpenCL devices");

                if (numDevices > 0)
                    foundDevice = 1;

                cl_device_id *devices = malloc(sizeof(cl_device_id) * numDevices);
                err = clGetDeviceIDs(platforms[p], CL_DEVICE_TYPE_ALL, numDevices, devices, NULL);
                clErrCheck(err, "clGetDeviceIDs - Getting list of available OpenCL devices");

                for (unsigned int d = 0; d < numDevices; d++)
                {
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
            if (foundDevice == 0)
            {
                printf_s("No OpenCL devices found.\n");
            }
            return 0;
        }
    }
    cl_int err;

    // Handle loading configuration from file if specified
    if (config_file != NULL)
    {
        if (!load_config_from_json(config_file, &config))
        {
            printf_s("Failed to load configuration from %s. Using default configuration.\n", config_file);
        }
        else
        {
            printf_s("Configuration loaded: %d needs and %d wants, with max ante %d\n",
                     config.numNeeds, config.numWants, config.maxSearchAnte);

            // Print needs information
            if (config.numNeeds > 0)
            {
                printf_s("Needs:\n");
                for (int i = 0; i < config.numNeeds && i < MAX_DESIRES_HOST; i++)
                {
                    printf_s("  - ");
                    if (config.Needs[i].jokeredition != RETRY && config.Needs[i].jokeredition != No_Edition)
                    {
                        print_item_host(config.Needs[i].jokeredition);
                        printf(" ");
                    }
                    print_item_host(config.Needs[i].value);
                    printf_s(" by ante %d\n", config.Needs[i].desireByAnte);
                    printf("\n");
                }
            }

            // Print wants information
            if (config.numWants > 0)
            {
                printf_s("Wants:\n");
                for (int i = 0; i < config.numWants && i < MAX_DESIRES_HOST; i++)
                {
                    printf_s("  - ");
                    if (config.Wants[i].jokeredition != RETRY && config.Wants[i].jokeredition != No_Edition)
                    {
                        print_item_host(config.Wants[i].jokeredition);
                        printf(" ");
                    }
                    print_item_host(config.Wants[i].value);
                    printf("\n");
                }
            }
        }
    }

    assert(config.numNeeds <= MAX_DESIRES_HOST);
    assert(config.numWants <= MAX_DESIRES_HOST);

    // Clamp numNeeds and numWants to MAX_DESIRES_HOST for safety before sending to device
    if (config.numNeeds > MAX_DESIRES_HOST)
    {
        printf_s("Warning: numNeeds (%d) > MAX_DESIRES_HOST (%d), clamping!\n", config.numNeeds, MAX_DESIRES_HOST);
        config.numNeeds = MAX_DESIRES_HOST;
    }
    if (config.numWants > MAX_DESIRES_HOST)
    {
        printf_s("Warning: numWants (%d) > MAX_DESIRES_HOST (%d), clamping!\n", config.numWants, MAX_DESIRES_HOST);
        config.numWants = MAX_DESIRES_HOST;
    }
    // Optionally zero out unused entries for safety
    for (int i = config.numNeeds; i < MAX_DESIRES_HOST; ++i)
    {
        memset(&config.Needs[i], 0, sizeof(config.Needs[i]));
    }
    for (int i = config.numWants; i < MAX_DESIRES_HOST; ++i)
    {
        memset(&config.Wants[i], 0, sizeof(config.Wants[i]));
    }

    // --- Platform and Device Setup ---
    cl_uint numPlatforms;
    err = clGetPlatformIDs(0, NULL, &numPlatforms);
    clErrCheck(err, "clGetPlatformIDs - Getting number of available OpenCL platforms");

    if (numPlatforms == 0)
    {
        printf_s("No OpenCL platforms found.\n");
        return 0;
    }
    if (platformID > numPlatforms - 1)
    {
        printf_s("Platform ID %i not found.\n", platformID);
        return 0;
    }

    cl_platform_id *platforms = malloc(sizeof(cl_platform_id) * numPlatforms);

    err = clGetPlatformIDs(numPlatforms, platforms, NULL);
    clErrCheck(err, "clGetPlatformIDs - Getting list of availble OpenCL platforms");
    cl_platform_id platform = platforms[platformID];

    cl_uint numDevices;
    err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, 0, NULL, &numDevices);
    clErrCheck(err, "clGetDeviceIDs - Getting number of available OpenCL devices");

    if (numDevices == 0)
    {
        printf_s("No OpenCL devices found for platform %i.\n", platformID);
        free(platforms);
        return 0;
    }
    if (deviceID > numDevices - 1)
    {
        printf_s("Device ID %i not found.\n", deviceID);
        free(platforms);
        return 0;
    }

    cl_device_id *devices = malloc(sizeof(cl_device_id) * numDevices);
    err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, numDevices, devices, NULL);
    clErrCheck(err, "clGetDeviceIDs - Getting list of available OpenCL devices");
    cl_device_id device = devices[deviceID]; // Check for SVM support to improve memory performance
    cl_device_svm_capabilities svm_caps;
    err = clGetDeviceInfo(device, CL_DEVICE_SVM_CAPABILITIES, sizeof(svm_caps), &svm_caps, NULL);
    cl_bool svm_supported = (err == CL_SUCCESS && (svm_caps & CL_DEVICE_SVM_COARSE_GRAIN_BUFFER) != 0);

    if (svm_supported)
    {
        printf_s("SVM supported - using high-performance shared virtual memory\n");
    }
    else
    {
        printf_s("SVM not supported - falling back to traditional buffer mapping\n");
    }

    cl_context ctx = clCreateContext(NULL, 1, &device, NULL, NULL, &err);
    clErrCheck(err, "clCreateContext - Creating OpenCL context");

    cl_command_queue queue = clCreateCommandQueue(ctx, device, 0, &err);
    clErrCheck(err, "clCreateCommandQueue - Creating OpenCL command queue");

    // Print GPU details for the selected device
    cl_uint compute_units = 0;
    cl_uint warp_size = 32; // Default warp size for most GPUs (NVIDIA)
    err = clGetDeviceInfo(device, CL_DEVICE_MAX_COMPUTE_UNITS, sizeof(compute_units), &compute_units, NULL);
    if (err == CL_SUCCESS)
    {
        printf_s("Using device with %u compute units\n", compute_units);
    }

    // --- Kernel Loading/Building ---
    FILE *fp = NULL; // Initialize fp
    char *ssKernelCode = NULL;
    size_t ssKernelSize = 0;
    cl_program ssKernelProgram = NULL; // Initialize ssKernelProgram
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
    char include_path[MAX_PATH + 6]; // For -I "path"
    char kernel_path[MAX_PATH];      // For main kernel source file like ouija_search.cl
    char binary_path[MAX_PATH];      // For precompiled filter_name.bin
    char build_options[1024];

    getExecutableDir(executable_dir);

    // Construct include path for OpenCL compiler (e.g., -I "X:\\Immolate")
    // This allows #include "filters/filter.cl" to work if filters is a subdir of executable_dir
    strcpy_s(include_path, sizeof include_path, "-I \"");
    strcat_s(include_path, sizeof include_path, executable_dir);
    strcat_s(include_path, sizeof include_path, "\"");

    // Construct path for the pre-compiled binary kernel
    createBinaryPath(executable_dir, filter, binary_path, MAX_PATH);

    // Attempt to load pre-compiled binary
    errno_t err_fopen = fopen_s(&fp, binary_path, "rb");
    if (err_fopen == 0 && fp != NULL)
    {
        fseek(fp, 0, SEEK_END);
        size_t actual_binary_size = ftell(fp);
        rewind(fp);

        if (actual_binary_size > 0)
        {
            unsigned char *program_binary_data = (unsigned char *)malloc(actual_binary_size);
            if (program_binary_data)
            {
                if (fread(program_binary_data, 1, actual_binary_size, fp) == actual_binary_size)
                {
                    cl_int binary_status = 0;
                    ssKernelProgram = clCreateProgramWithBinary(ctx, 1, &device,
                                                                &actual_binary_size,
                                                                (const unsigned char **)&program_binary_data,
                                                                &binary_status, &err);
                    if (err == CL_SUCCESS && binary_status == CL_SUCCESS)
                    {
                        loaded_from_binary = 1;
                    }
                    else
                    {
                        fprintf_s(stderr, "Error: Failed to create program from binary %s (clCreateProgramWithBinary err: %d, binary_status: %d). Will compile from source.\n", binary_path, err, binary_status);
                        if (ssKernelProgram)
                        {
                            clReleaseProgram(ssKernelProgram);
                            ssKernelProgram = NULL;
                        }
                        err = CL_SUCCESS; // Reset OpenCL error as we are falling back to source
                    }
                }
                else
                {
                    fprintf_s(stderr, "Error: Failed to read binary file %s. Will compile from source.\n", binary_path);
                }
                free(program_binary_data);
            }
            else
            {
                fprintf_s(stderr, "Error: Failed to allocate memory for binary %s. Will compile from source.\n", binary_path);
            }
        }
        else
        {
            // Empty binary file, will fall through to source compilation.
            // fprintf_s(stderr, "Warning: Binary file %s is empty. Will compile from source.\n", binary_path);
        }
        fclose(fp);
        fp = NULL;
    }
    // If fopen_s failed, loaded_from_binary remains 0, and we fall through to source compilation.

    if (!loaded_from_binary)
    {
        // Print the user-requested message as the binary was not loaded or failed to load.
        printf_s("$Template binary is not cached for %s. This only needs to build once. Please wait!\n", filter);
        fflush(stdout);

        // Construct path to the main kernel source file (e.g., ouija_search.cl, located in executable_dir)
        snprintf(kernel_path, sizeof(kernel_path), "%s\\\\ouija_search.cl", executable_dir);

        err_fopen = fopen_s(&fp, kernel_path, "r");
        if (err_fopen != 0 || !fp)
        {
            fprintf_s(stderr, "Fatal: Failed to load main kernel source file %s (Error: %d)\n", kernel_path, err_fopen);
            printf_s("$Error: Main kernel source %s not found. Cannot proceed.\n", kernel_path);
            fflush(stdout);
            // Consider proper cleanup before exit if more resources are allocated
            exit(1);
        }

        ssKernelCode = (char *)malloc(MAX_CODE_SIZE);
        char *ssKernelBuf = (char *)malloc(MAX_CODE_SIZE);
        if (!ssKernelCode || !ssKernelBuf)
        {
            fprintf_s(stderr, "Fatal: Malloc failed for kernel source buffers.\n");
            if (fp)
                fclose(fp);
            // Consider proper cleanup
            exit(1);
        }

        // Construct kernel source string: prepend #include for specific filter, then append generic kernel code
        strcpy_s(ssKernelCode, MAX_CODE_SIZE, "#include \"filters/"); // Corrected string literal
        strcat_s(ssKernelCode, MAX_CODE_SIZE, filter);
        strcat_s(ssKernelCode, MAX_CODE_SIZE, ".cl\"\n\n"); // Corrected string literal

        size_t current_len = strlen(ssKernelCode); // Initialize current_len here
        size_t bytes_read = fread(ssKernelBuf, 1, MAX_CODE_SIZE - current_len - 1, fp);

        if (ferror(fp))
        {
            fprintf_s(stderr, "Fatal: Error reading from kernel source file %s.\n", kernel_path);
            fclose(fp);
            free(ssKernelCode);
            free(ssKernelBuf);
            // Consider proper cleanup
            exit(1);
        }
        ssKernelBuf[bytes_read] = (char)0; // Null-terminate the buffer
        strcat_s(ssKernelCode, MAX_CODE_SIZE, ssKernelBuf);
        ssKernelSize = strlen(ssKernelCode);

        fclose(fp);
        fp = NULL;
        free(ssKernelBuf);

        ssKernelProgram = clCreateProgramWithSource(ctx, 1, (const char **)&ssKernelCode, &ssKernelSize, &err);
        clErrCheck(err, "clCreateProgramWithSource - Creating OpenCL program from source");
        // ssKernelCode is managed by OpenCL after clCreateProgramWithSource; free it in the main cleanup.
    }
    else
    {
        printf_s("Using pre-compiled kernel binary from %s.\n", binary_path);
        fflush(stdout);
    }

    // Common build step for both binary and source loaded programs
    printf_s("Building OpenCL Program...\n");
    // Construct build options
    snprintf(build_options, sizeof(build_options), "%s -cl-mad-enable", include_path);

    err = clBuildProgram(ssKernelProgram, 1, &device, build_options, NULL, NULL);
    if (err == CL_BUILD_PROGRAM_FAILURE)
    {
        size_t logLength = 0;
        err = clGetProgramBuildInfo(ssKernelProgram, device, CL_PROGRAM_BUILD_LOG, 0, NULL, &logLength);
        if (err != CL_SUCCESS)
        {
            printf_s("Error getting build log length: %d\n", err);
            if (ssKernelCode != NULL)
                free(ssKernelCode);
            free(devices);
            free(platforms);
            clReleaseCommandQueue(queue);
            clReleaseContext(ctx);
            exit(EXIT_FAILURE);
        }
        char *buf = calloc(logLength, sizeof(char));
        if (!buf)
        {
            printf_s("Error allocating memory for build log\n");
            if (ssKernelCode != NULL)
                free(ssKernelCode);
            free(devices);
            free(platforms);
            clReleaseCommandQueue(queue);
            clReleaseContext(ctx);
            exit(EXIT_FAILURE);
        }
        err = clGetProgramBuildInfo(ssKernelProgram, device, CL_PROGRAM_BUILD_LOG, logLength, buf, NULL);
        if (err != CL_SUCCESS)
        {
            printf_s("Error getting build log: %d\n", err);
            free(buf);
            if (ssKernelCode != NULL)
                free(ssKernelCode);
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

    if (ssKernelCode != NULL)
    {
        free(ssKernelCode);
        ssKernelCode = NULL;
    }
    if (!loaded_from_binary)
    {
        printf_s("Saving compiled kernel to binary: %s\n", binary_path);
        size_t binary_size;
        err = clGetProgramInfo(ssKernelProgram, CL_PROGRAM_BINARY_SIZES, sizeof(size_t), &binary_size, NULL);
        clErrCheck(err, "clGetProgramInfo - Getting binary size");

        if (binary_size > 0)
        {
            printf_s("Binary size: %zu bytes\n", binary_size);
            unsigned char *program_binary = (unsigned char *)malloc(binary_size);

            if (!program_binary)
            {
                fprintf_s(stderr, "Failed to allocate memory for saving kernel binary.\n");
            }
            else
            {
                // Create array of pointers for binaries (only one in our case)
                unsigned char *binaries[1] = {program_binary};

                // Get the actual binary data
                err = clGetProgramInfo(ssKernelProgram, CL_PROGRAM_BINARIES, sizeof(unsigned char *), binaries, NULL);
                if (err != CL_SUCCESS)
                {
                    fprintf_s(stderr, "Failed to get program binary (err: %d)\n", err);
                }
                else
                {
                    errno_t fopen_err = fopen_s(&fp, binary_path, "wb");
                    if (fopen_err != 0)
                    {
                        fprintf_s(stderr, "Failed to open binary file for writing: %s (error code: %d)\n", binary_path, fopen_err);
                    }
                    else
                    {
                        if (fwrite(program_binary, 1, binary_size, fp) != binary_size)
                        {
                            fprintf_s(stderr, "Failed to write kernel binary to file.\n");
                        }
                        else
                        {
                            printf_s("Successfully saved kernel binary.\n");
                        }
                        fclose(fp);
                    }
                }
                free(program_binary);
            }
        }
        else
        {
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

    if (!err)
    {
        if (numGroups > max_work_group_size)
        {
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
    if (batch_capacity == 0)
        batch_capacity = 1; // Ensure batch_capacity is at least 1
    cl_mem *resultBuf_dev = (cl_mem *)malloc(NUM_RESULT_BUFFERS * sizeof(cl_mem));
    OuijaHostResult **svm_result_ptrs = NULL; // SVM pointers for direct access

    if (svm_supported)
    {
        // Use SVM buffers for zero-copy memory access
        svm_result_ptrs = (OuijaHostResult **)malloc(NUM_RESULT_BUFFERS * sizeof(OuijaHostResult *));
        for (int i = 0; i < NUM_RESULT_BUFFERS; ++i)
        {
            svm_result_ptrs[i] = (OuijaHostResult *)clSVMAlloc(ctx, CL_MEM_READ_WRITE,
                                                               sizeof(OuijaHostResult) * batch_capacity, 0);
            if (!svm_result_ptrs[i])
            {
                fprintf_s(stderr, "Fatal: Failed to allocate SVM result buffer %d (size: %zu bytes)\n", i, sizeof(OuijaHostResult) * batch_capacity);
                exit(1);
            } // For SVM, we don't create buffer objects - use direct SVM pointers
            resultBuf_dev[i] = NULL;
        }
    }
    else
    {
        // Fallback to traditional buffer allocation
        for (int i = 0; i < NUM_RESULT_BUFFERS; ++i)
        {
            resultBuf_dev[i] = clCreateBuffer(ctx, CL_MEM_WRITE_ONLY | CL_MEM_ALLOC_HOST_PTR,
                                              sizeof(OuijaHostResult) * batch_capacity, NULL, &err);
            if (!resultBuf_dev[i] || err != CL_SUCCESS)
            {
                fprintf_s(stderr, "Fatal: Failed to allocate result buffer %d (size: %zu bytes, err: %d)\n", i, sizeof(OuijaHostResult) * batch_capacity, err);
                exit(1);
            }
            clErrCheck(err, "clCreateBuffer - Creating result buffer on device");
        }
    }

    // Calculate the total number of batches potentially required
    cl_long total_potential_batches = (numSeeds + batch_capacity - 1) / batch_capacity;

    cl_long cumulative_seeds_dispatched = 0; // Total seeds dispatched to kernels
    cl_long seed_offset_for_kernel = 0;      // Starting seed offset for the current kernel dispatch
    cl_long num_seeds_this_dispatch = 0;     // Number of seeds for the kernel dispatch being prepared
    cl_long num_seeds_last_dispatch = 0;     // Number of seeds processed by the completed kernel whose results are being read
    // Print the CSV header for any consuming applications such as the python mvc.
    printf_s("+Seed,Score");
    // For Jokers found naturally negative, whether wanted or not
    if (config.scoreNaturalNegatives)
    {
        printf_s(",Natural Negative Jokers");
    }
    // For Jokers found naturally negative, that were in Needs and/or Wants list!
    // Also for jokers made negative with skip tag mechanics, that were in needs/wants list!
    if (config.scoreDesiredNegatives)
    {
        printf_s(",Desired Negative Jokers");
    }
    for (int w = 0; w < config.numWants && w < MAX_DESIRES_HOST; w++)
    {
        printf_s(",");
        // Only add edition for actual jokers (not Tarot/Spectral cards)
        if (config.Wants[w].jokeredition != RETRY && config.Wants[w].jokeredition != No_Edition)
        {
            print_item_host(config.Wants[w].jokeredition);
            printf_s("_"); // Replace space with underscore
        }
        print_item_host(config.Wants[w].value);
    }
    printf_s("\n");
    fflush(stdout);

    clock_t start_time = clock();
    clock_t ticker = clock();
    if (numSeeds > 0)
    { 
        // Only print if we are actually searching
        printf_s("Starting seed search...\n");
        fflush(stdout);
    }
    else
    {
        printf_s("No seeds to search. Exiting.\n");
        free(devices);
        free(platforms);
        clReleaseCommandQueue(queue);
        clReleaseContext(ctx);
        exit(0);
    }

    // --- Initial Kernel Launch ---
    if (numSeeds > 0)
    {
        num_seeds_this_dispatch = (numSeeds > batch_capacity) ? batch_capacity : numSeeds;
        seed_offset_for_kernel = 0; // First batch starts at offset 0 from startingSeed

        printf_s("Setting params for initial batch...\n");
        err = clSetKernelArg(ssKernel, 0, sizeof(cl_char8), &startingSeed);
        clErrCheck(err, "clSetKernelArg - Setting starting seed for initial batch");
        err = clSetKernelArg(ssKernel, 1, sizeof(cl_long), &num_seeds_this_dispatch);
        clErrCheck(err, "clSetKernelArg - Setting num_seeds for initial batch");
        err = clSetKernelArg(ssKernel, 2, sizeof(cl_mem), &configBuf);
        clErrCheck(err, "clSetKernelArg - Setting config buffer for initial batch");
        if (svm_supported)
        {
            err = clSetKernelArgSVMPointer(ssKernel, 3, svm_result_ptrs[current_buffer_idx]);
            clErrCheck(err, "clSetKernelArgSVMPointer - Setting SVM result buffer for initial batch");
        }
        else
        {
            err = clSetKernelArg(ssKernel, 3, sizeof(cl_mem), &resultBuf_dev[current_buffer_idx]);
            clErrCheck(err, "clSetKernelArg - Setting result buffer for initial batch");
        }
        err = clSetKernelArg(ssKernel, 4, sizeof(cl_mem), &seedOffsetBuf);
        clErrCheck(err, "clSetKernelArg - Setting seed offset buffer for initial batch");

        err = clEnqueueWriteBuffer(queue, seedOffsetBuf, CL_TRUE, 0, sizeof(cl_long), &seed_offset_for_kernel, 0, NULL, NULL);
        clErrCheck(err, "clEnqueueWriteBuffer - Writing initial seed offset");

        size_t global_work_size_init = (size_t)((num_seeds_this_dispatch + localWorkSize - 1) / localWorkSize) * localWorkSize;
        if (global_work_size_init == 0 && num_seeds_this_dispatch > 0)
            global_work_size_init = localWorkSize; // Ensure it's not 0 if seeds > 0
        size_t local_work_size_init = (size_t)localWorkSize;
        if (num_seeds_this_dispatch == 0)
            global_work_size_init = 0; // No work if no seeds

        if (num_seeds_this_dispatch > 0)
        {
            err = clEnqueueNDRangeKernel(queue, ssKernel, 1, NULL, &global_work_size_init, &local_work_size_init, 0, NULL, &kernel_events[current_buffer_idx]);
            clErrCheck(err, "clEnqueueNDRangeKernel - Initial kernel execution");
        }
        else
        {
            kernel_events[current_buffer_idx] = NULL; // No kernel launched
        }
        dispatched_kernel_seeds[current_buffer_idx] = num_seeds_this_dispatch; // ADDED: Store seeds for this launch
        cumulative_seeds_dispatched += num_seeds_this_dispatch;
    }
    else
    {
        printf_s("No seeds to process. Exiting.\n");
        free(devices);
        free(platforms);
        clReleaseCommandQueue(queue);
        clReleaseContext(ctx);
        exit(3);
    }
    // --- End of Initial Kernel Launch ---

    // Main processing loop
    // printf_s("[HOST] total_potential_batches: %lld\n", total_potential_batches);
    fflush(stdout);

    int is_first_batch = 1; // Track if this is the first batch

    for (cl_long batch_idx = 0; batch_idx < total_potential_batches; ++batch_idx)
    {
        if (num_seeds_this_dispatch == 0 && batch_idx == 0)
        { // Handles -n 0 case or if first dispatch was 0 seeds
            // printf("[HOST] exiting main loop num_seeds_this_dispatch=0 and batch_idx=0\n");
            break;
        }
        // MODIFIED: Determine results buffer and seed count for it
        int results_buffer_idx = current_buffer_idx;
        num_seeds_last_dispatch = dispatched_kernel_seeds[results_buffer_idx];

        if (kernel_events[results_buffer_idx] != NULL)
        {
            // printf_s("[HOST] kernel_events[results_buffer_idx] != NULL. Will process!\n");
            err = clWaitForEvents(1, &kernel_events[results_buffer_idx]);
            clErrCheck(err, "clWaitForEvents - Waiting for kernel completion");
            clReleaseEvent(kernel_events[results_buffer_idx]);
            kernel_events[results_buffer_idx] = NULL;
        }
        else if (num_seeds_last_dispatch > 0)
        { // Only warn if we expected an event
            printf_s("Warning: No event to wait for for buffer index %d, but expected %lld seeds.\n", results_buffer_idx, num_seeds_last_dispatch);
        }
        if (num_seeds_last_dispatch > 0)
        { // Only map and process if the last dispatch had seeds
            // printf_s("[HOST] Processing batch %lld/%lld (results for %lld seeds)\n", batch_idx+1, total_potential_batches, num_seeds_last_dispatch);
            // fflush(stdout);

            OuijaHostResult *mapped_results;
            if (svm_supported)
            {
                // Direct SVM access - no mapping needed
                mapped_results = svm_result_ptrs[results_buffer_idx];
                // Map SVM pointer for host access if needed
                err = clEnqueueSVMMap(queue, CL_TRUE, CL_MAP_READ,
                                      mapped_results, sizeof(OuijaHostResult) * num_seeds_last_dispatch, 0, NULL, NULL);
                clErrCheck(err, "clEnqueueSVMMap - Mapping SVM result buffer");
            }
            else
            {
                // Traditional mapping for non-SVM systems
                mapped_results = (OuijaHostResult *)clEnqueueMapBuffer(queue, resultBuf_dev[results_buffer_idx], CL_TRUE,
                                                                       CL_MAP_READ, 0, sizeof(OuijaHostResult) * num_seeds_last_dispatch, 0, NULL, NULL, &err);
                clErrCheck(err, "clEnqueueMapBuffer - Mapping result buffer");
            }
            // Count all seeds that were dispatched to the kernel as processed
            seeds_processed_total += num_seeds_last_dispatch;

            int batch_high_score = cutoff; // Initialize to current cutoff
            for (cl_long i = 0; i < num_seeds_last_dispatch; ++i)
            {
                OuijaHostResult *result = &mapped_results[i];
                if (result->seed[0] == '\0')
                    continue; // Skip if kernel returned empty seed (e.g., filter didn't pass)

                if (result->TotalScore > batch_high_score)
                    batch_high_score = result->TotalScore;

                if (result->TotalScore >= cutoff)
                {
                    if (is_first_batch && result->TotalScore == cutoff)
                    {
                        // Skip printing scores equal to the cutoff during the first batch
                        continue;
                    }
                    seeds_scored_total++;
                    printf_s("|%s,%d,", result->seed, result->TotalScore);                    
                    if (config.scoreNaturalNegatives)
                    {
                        printf_s("%d", result->NaturalNegativeJokers);
                    }
                    if (config.scoreDesiredNegatives)
                    {
                        printf_s("%d", result->DesiredNegativeJokers);
                    }
                    for (int w = 0; w < config.numWants && w < MAX_DESIRES_HOST; w++)
                    {
                        printf_s(",%d", (int)result->ScoreWants[w]);
                    }
                    printf_s("\n");
                }
            }
            fflush(stdout);
            // After printing, update cutoff if in auto mode
            if (auto_cutoff_mode && batch_high_score > cutoff)
            {
                printf_s("[AUTO] Raising cutoff from %d to %d (highest in batch)\n", cutoff, batch_high_score);
                cutoff = batch_high_score;
            }
            // After processing the first batch, update the cutoff and reset the flag
            if (is_first_batch)
            {
                cutoff = batch_high_score;
                is_first_batch = 0; // First batch processing is complete
                printf_s("[AUTO] First batch cutoff set to %d\n", cutoff);
            }
            if (svm_supported)
            {
                // Unmap SVM pointer
                err = clEnqueueSVMUnmap(queue, mapped_results, 0, NULL, NULL);
                clErrCheck(err, "clEnqueueSVMUnmap - Unmapping SVM result buffer");
            }
            else
            {
                // Traditional unmapping
                err = clEnqueueUnmapMemObject(queue, resultBuf_dev[results_buffer_idx], mapped_results, 0, NULL, NULL);
                clErrCheck(err, "clEnqueueUnmapMemObject - Unmapping result buffer");
            }
        }

        // Check if all requested seeds have been dispatched
        if (cumulative_seeds_dispatched >= numSeeds)
        {
            break;
        }

        // --- Prepare and Launch Next Kernel ---
        current_buffer_idx = (current_buffer_idx + 1) % NUM_RESULT_BUFFERS; // Advance for the next launch

        seed_offset_for_kernel = cumulative_seeds_dispatched;
        cl_long remaining_overall_seeds = numSeeds - cumulative_seeds_dispatched;

        if (remaining_overall_seeds <= 0)
            break; // Should be caught by earlier check, but as a safeguard

        num_seeds_this_dispatch = (remaining_overall_seeds > batch_capacity) ? batch_capacity : remaining_overall_seeds;

        // Only wait for the specific buffer we're about to reuse
        if (kernel_events[current_buffer_idx] != NULL)
        {
            err = clWaitForEvents(1, &kernel_events[current_buffer_idx]);
            if (err != CL_SUCCESS)
            {
                printf_s("Error waiting for kernel event on buffer %d: %d\n", current_buffer_idx, err);
                clErrCheck(err, "clWaitForEvents - Ensuring buffer is ready for reuse");
            }
            clReleaseEvent(kernel_events[current_buffer_idx]);
            kernel_events[current_buffer_idx] = NULL;
        }

        // Add validation before setting kernel args
        if (num_seeds_this_dispatch <= 0 || seed_offset_for_kernel < 0)
        {
            printf_s("Error: Invalid kernel parameters - seeds: %lld, offset: %lld\n",
                     num_seeds_this_dispatch, seed_offset_for_kernel);
            break;
        }

        // Add batch progress tracking for error diagnosis
        if (batch_idx % 100 == 0)
        {
            printf_s("Debug: Processing batch %lld, buffer %d, seeds %lld, offset %lld\n",
                     batch_idx, current_buffer_idx, num_seeds_this_dispatch, seed_offset_for_kernel);
            fflush(stdout);
        }

        err = clSetKernelArg(ssKernel, 0, sizeof(cl_char8), &startingSeed);
        clErrCheck(err, "clSetKernelArg - Setting starting seed for current batch");
        err = clSetKernelArg(ssKernel, 1, sizeof(cl_long), &num_seeds_this_dispatch);
        clErrCheck(err, "clSetKernelArg - Setting num_seeds for current batch"); // Config buffer (arg 2) is already set and doesn't change
        if (svm_supported)
        {
            err = clSetKernelArgSVMPointer(ssKernel, 3, svm_result_ptrs[current_buffer_idx]);
            clErrCheck(err, "clSetKernelArgSVMPointer - Setting SVM result buffer for current launch");
        }
        else
        {
            err = clSetKernelArg(ssKernel, 3, sizeof(cl_mem), &resultBuf_dev[current_buffer_idx]);
            clErrCheck(err, "clSetKernelArg - Setting result buffer for current launch");
        }
        // Seed offset buffer (arg 4) is already set

        err = clEnqueueWriteBuffer(queue, seedOffsetBuf, CL_TRUE, 0, sizeof(cl_long), &seed_offset_for_kernel, 0, NULL, NULL);
        clErrCheck(err, "clEnqueueWriteBuffer - Updating seed offset for current batch");

        size_t global_work_size_next = (size_t)((num_seeds_this_dispatch + localWorkSize - 1) / localWorkSize) * localWorkSize;
        if (global_work_size_next == 0 && num_seeds_this_dispatch > 0)
            global_work_size_next = localWorkSize;
        size_t local_work_size_next = (size_t)localWorkSize;
        if (num_seeds_this_dispatch == 0)
            global_work_size_next = 0; // Clean the result buffer before dispatching kernel
        OuijaHostResult *mapped_results;
        if (svm_supported)
        {
            // Direct SVM access - no mapping needed
            mapped_results = svm_result_ptrs[current_buffer_idx];
            // Map SVM pointer for host access
            err = clEnqueueSVMMap(queue, CL_TRUE, CL_MAP_WRITE,
                                  mapped_results, sizeof(OuijaHostResult) * num_seeds_this_dispatch, 0, NULL, NULL);
            clErrCheck(err, "clEnqueueSVMMap - Mapping SVM result buffer for clearing");
        }
        else
        {
            // Traditional mapping for non-SVM systems
            mapped_results = (OuijaHostResult *)clEnqueueMapBuffer(queue, resultBuf_dev[current_buffer_idx], CL_TRUE,
                                                                   CL_MAP_WRITE, 0, sizeof(OuijaHostResult) * num_seeds_this_dispatch, 0, NULL, NULL, &err);
            clErrCheck(err, "clEnqueueMapBuffer - Mapping result buffer for clearing");
        }

        for (cl_long i = 0; i < num_seeds_this_dispatch; i++)
        {
            memset(&mapped_results[i], 0, sizeof(OuijaHostResult));
        }

        if (svm_supported)
        {
            // Unmap SVM pointer
            err = clEnqueueSVMUnmap(queue, mapped_results, 0, NULL, NULL);
            clErrCheck(err, "clEnqueueSVMUnmap - Unmapping SVM result buffer after clearing");
        }
        else
        {
            // Traditional unmapping
            err = clEnqueueUnmapMemObject(queue, resultBuf_dev[current_buffer_idx], mapped_results, 0, NULL, NULL);
            clErrCheck(err, "clEnqueueUnmapMemObject - Unmapping result buffer after clearing");
        }

        if (clock() - ticker > 1000 && seeds_processed_total > 0)
        { // Use seeds_processed_total for accurate progress
            ticker = clock();
            double elapsed_time = (double)(clock() - start_time) / CLOCKS_PER_SEC;
            double estimated_total_time = (elapsed_time / seeds_processed_total) * numSeeds;
            double remaining_time = estimated_total_time - elapsed_time;

            printf_s("$Elapsed time: %.2f seconds, Estimated remaining time: %.2f seconds             $clock$%.1fK/s\n",
                     elapsed_time, remaining_time, (elapsed_time > 0) ? ((double)seeds_processed_total / elapsed_time) * 0.001f : 0.0);
            fflush(stdout);
        }

        if (num_seeds_this_dispatch > 0)
        {
            err = clEnqueueNDRangeKernel(queue, ssKernel, 1, NULL, &global_work_size_next, &local_work_size_next, 0, NULL, &kernel_events[current_buffer_idx]);
            clErrCheck(err, "clEnqueueNDRangeKernel - Subsequent kernel execution");
        }
        else
        {
            kernel_events[current_buffer_idx] = NULL; // No kernel launched
        }
        dispatched_kernel_seeds[current_buffer_idx] = num_seeds_this_dispatch; // ADDED: Store seeds for this launch
        cumulative_seeds_dispatched += num_seeds_this_dispatch;

        // Put clFinish back - your driver needs it to prevent -9999 errors
        err = clFinish(queue);
        clErrCheck(err, "clFinish - Driver synchronization to prevent -9999 errors");
        // --- End of Prepare and Launch Next Kernel ---
    }
    // printf_s("[HOST] main loop finished.\n");

    // After the loop, ensure any final outstanding kernel event is handled
    double elaps = (double)(clock() - start_time) / CLOCKS_PER_SEC;
    cl_long reported_total_seeds = seeds_processed_total; // Use actual processed seeds for accurate reporting
    if (numSeeds > 0 && reported_total_seeds == 0 && cumulative_seeds_dispatched > 0)
    {
        reported_total_seeds = cumulative_seeds_dispatched; // Fallback to dispatched if no processed seeds
    }
    printf_s("$Search Complete! Found %lli viable out of %lli total seeds @%.1f seeds/s\n",
             seeds_scored_total, seeds_processed_total,
             (elaps > 0 && seeds_processed_total > 0) ? ((double)seeds_processed_total / elaps) : 0.0);
    fflush(stdout);
    // --- Cleanup ---
    if (ssKernelCode != NULL)
        free(ssKernelCode);
    free(devices);
    free(platforms);
    for (int i = 0; i < NUM_RESULT_BUFFERS; ++i)
    {
        if (svm_supported && svm_result_ptrs[i] != NULL)
        {
            clSVMFree(ctx, svm_result_ptrs[i]);
        }
        else if (resultBuf_dev[i] != NULL)
        {
            clReleaseMemObject(resultBuf_dev[i]);
        }
        if (kernel_events[i] != NULL)
            clReleaseEvent(kernel_events[i]);
    }
    if (svm_supported && svm_result_ptrs != NULL)
    {
        free(svm_result_ptrs);
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