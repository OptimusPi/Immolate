#include "lib/ouiji.h"
#include "lib/host_items.h"
#include "lib/ouiji_config_loader.h"
#include "lib/ouiji_host_result.h"

#include <time.h>

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

// Convert a cl_long index to a variable-length base-35 seed string
void index_to_seed_string(long long index, char* seed_out) {
    const char charset[] = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    int base = 35;
    char buf[9];
    int i = 0;
    if (index == 0) {
        seed_out[0] = charset[0];
        seed_out[1] = '\0';
        return;
    }
    while (index > 0 && i < 8) {
        buf[i++] = charset[index % base];
        index /= base;
    }
    // Reverse to get correct order
    for (int j = 0; j < i; j++) {
        seed_out[j] = buf[i - 1 - j];
    }
    seed_out[i] = '\0';
}

// Advances a cl_char8 seed by n steps in base-35, little-endian, matching device s_skip
void s_skip_host(cl_char8* seed, size_t n) {
    const char charset[] = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    int base = 35;
    int data[8] = {0};
    int len = 0;
    // Convert seed string to digit array (little-endian)
    for (int i = 0; i < 8 && seed->s[i] != '\0'; i++) {
        char* p = strchr(charset, seed->s[i]);
        if (p) data[i] = (int)(p - charset);
        len++;
    }
    if (len == 0) len = 1;
    size_t carry = n;
    for (int i = len - 1; i >= 0 && carry > 0; i--) {
        size_t val = data[i] + carry;
        data[i] = val % base;
        carry = val / base;
    }
    // If carry remains and seed is not max length, grow the seed
    while (carry > 0 && len < 8) {
        data[len] = carry % base;
        carry = carry / base;
        len++;
    }
    // If carry remains and seed is max length, wrap around (optional: zero out)
    if (carry > 0 && len == 8) {
        len = 0;
    }
    // Convert back to string (little-endian)
    for (int i = 0; i < len; i++) seed->s[i] = charset[data[i]];
    for (int i = len; i < 8; i++) seed->s[i] = '\0';
}

// Host-side seed struct and helpers matching device logic
// Digits are stored little-endian: data[0] is least significant digit
// (matches device-side seed.cl)
typedef struct {
    int data[8];
    int len;
} host_seed;

const char charset[] = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

// Convert string to host_seed (little-endian)
void string_to_host_seed(const char* str, host_seed* s) {
    int len = (int)strlen(str);
    s->len = len;
    for (int i = 0; i < len; i++) {
        char* p = strchr(charset, str[len - 1 - i]); // reverse order
        s->data[i] = (p ? (int)(p - charset) : 0);
    }
}

// Convert host_seed to string (big-endian)
void host_seed_to_string(const host_seed* s, char* out) {
    for (int i = 0; i < s->len; i++) {
        out[i] = charset[s->data[s->len - 1 - i]];
    }
    out[s->len] = '\0';
}

// Skip n seeds (matches device s_skip: little-endian, carry from 0 up)
void host_seed_skip(host_seed* s, cl_long n) {
    int base = 35;
    cl_long carry = n;
    for (int i = 0; i < s->len && carry > 0; i++) {
        cl_long val = s->data[i] + carry;
        s->data[i] = (int)(val % base);
        carry = val / base;
    }
    while (carry > 0 && s->len < 8) {
        s->data[s->len] = (int)(carry % base);
        carry = carry / base;
        s->len++;
    }
    if (carry > 0 && s->len == 8) {
        s->len = 0;
    }
}

void host_seed_to_cl_char8(const host_seed* s, cl_char8* out) {
    for (int i = 0; i < s->len; i++) out->s[i] = charset[s->data[s->len - 1 - i]];
    for (int i = s->len; i < 8; i++) out->s[i] = '\0';
}

int main(int argc, char **argv) {

    // Print version
    printf_s("Ouiji Beta v1.0.1f.1\n");
    fflush(stdout);

    // Handle CLI arguments
    unsigned int platformID = 0;
    unsigned int deviceID = 0;
    size_t numGroups = 16;
    cl_char8 startingSeed; // Keep as cl_char8
    for (int i = 0; i < 8; i++) {
        startingSeed.s[i] = '\0';
    };
    size_t numSeeds = 2318107019761; // Keep as cl_long to match OpenCL's 64-bit type
    // Default config values
    OuijiConfig config;
    config.cutoff = 0;           // Default cutoff
    config.numNeeds = 0;         // Default number of needs
    config.numWants = 0;         // Default number of wants
    config.maxSearchAnte = 8;    // Default maximum ante to search through

    char* filter = "ouiji_template"; // Default filter
    char* config_file = NULL;  // Configuration file path

    // --- Argument Parsing Loop ---
    for (int i = 0; i < argc; i++) {
        if (strcmp(argv[i], "-h")==0) {
            printf_s("Valid command line arguments:\n-h        Shows this help dialog.\n-f <F>    Sets the filter used by Ouiji to F. Defaults to ouiji_template\n-s <S>    Sets the starting seed to S. Defaults to empty seed. Use \"random\" for a random starting seed.\n-n <N>    Sets the number of seeds to search to N. Defaults to full seed pool.\n-c <C>    Sets the cutoff score for a seed to be printed to C. Defaults to 1.\n-p <P>    Sets the platform ID of the CL device being used to P. Defaults to 0.\n-d <D>    Sets the device ID of the CL device being used to D. Defaults to 0.\n-g <G>    Sets the number of thread groups to G. Defaults to 16. Increasing this might help Ouiji run faster.\n--config <JSON>  Load configuration from a JSON file.\n--list_devices   Lists information about the detected CL devices.\n--gui    Enables GUI streaming mode.");
            return 0;
        }
        if (strcmp(argv[i], "--config")==0 && i + 1 < argc) {
            config_file = argv[i+1];
            printf_s("Using configuration file: %s\n", config_file);
            i++;
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
            config.cutoff = (int)strtoll(argv[i+1], NULL, 10); // Parse cutoff into config
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
                startingSeed.s[3] = 'P';
                startingSeed.s[4] = 'I';
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
                    printf_s("  - Item %i\n", config.Wants[i].value);
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
        strcat_s(kernel_path, sizeof kernel_path, "ouiji_search.cl");

        err = fopen_s(&fp, kernel_path, "r");
        if (!fp) {
            printf_s("Warning: Kernel source not found at %s, attempting working directory...\n", kernel_path);
            err = fopen_s(&fp, "ouiji_search.cl", "r");
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

    // Add -cl-mad-enable to build options
    char build_options[1024];
    snprintf(build_options, sizeof(build_options), "%s -cl-mad-enable", include_path);
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
    cl_kernel ssKernel = clCreateKernel(ssKernelProgram, "ouiji_search", &err);
    clErrCheck(err, "clCreateKernel - Creating OpenCL kernel");

    cl_mem configBuf = clCreateBuffer(ctx, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, sizeof(OuijiConfig), &config, &err);
    clErrCheck(err, "clCreateBuffer - Creating config buffer");

    printf_s("Starting OpenCL Search search with filter %s\n", filter);
    printf_s("--- CSV RESULTS ---\n");
    fflush(stdout);
    // Print header for CSV output
    printf("Seed,Score,NegativeJokers,");
    for (int i = 0; i < MAX_DESIRES_HOST && i < config.numNeeds; i++) {
        printf("Need(");
        if (config.Needs[i].jokeredition != RETRY && config.Needs[i].jokeredition != No_Edition) {
            print_item(config.Needs[i].jokeredition);
            printf("");
        }
        if (config.Needs[i].value != RETRY) {
            print_item(config.Needs[i].value);
        }
        printf("),");
    }
    for (int i = 0; i < MAX_DESIRES_HOST && i < config.numWants; i++) {
        printf("Want(");
        if (config.Wants[i].jokeredition != RETRY && config.Wants[i].jokeredition != No_Edition) {
            print_item(config.Wants[i].jokeredition);
        }
        if (config.Wants[i].value != RETRY) {
            print_item(config.Wants[i].value);
        }
        printf(")");
        if (i < config.numWants - 1 && i < MAX_DESIRES_HOST - 1) {
            printf(",");
        }
    }
    printf("\n");
    fflush(stdout);  // Force flush the CSV header line

    // --- Batch Processing ---
    size_t batchSize = numGroups * numGroups;
    OuijiHostResult* hostResults = (OuijiHostResult*)malloc(sizeof(OuijiHostResult) * (size_t)batchSize);
    cl_mem resultsBuf = clCreateBuffer(ctx, CL_MEM_WRITE_ONLY, sizeof(OuijiHostResult) * (size_t)batchSize, NULL, &err);
    clErrCheck(err, "clCreateBuffer - Creating results buffer");
    cl_mem resultCountBuf = clCreateBuffer(ctx, CL_MEM_READ_WRITE, sizeof(cl_int), NULL, &err);
    clErrCheck(err, "clCreateBuffer - Creating result count buffer");
    size_t seedsLeft = numSeeds;
    host_seed batchSeedHost;
    // Convert startingSeed (cl_char8) to host_seed
    char startSeedStr[9];
    for (int i = 0; i < 8; i++) startSeedStr[i] = startingSeed.s[i];
    startSeedStr[8] = '\0';
    string_to_host_seed(startSeedStr, &batchSeedHost);
    while (seedsLeft > 0) {
        cl_long thisBatch = (seedsLeft < batchSize) ? seedsLeft : batchSize;
        size_t localSize = numGroups;
        size_t globalSize = ((size_t)thisBatch + localSize - 1) / localSize * localSize; // round up to next multiple
        cl_int zero = 0;
        err = clEnqueueWriteBuffer(queue, resultCountBuf, CL_TRUE, 0, sizeof(cl_int), &zero, 0, NULL, NULL);
        clErrCheck(err, "clEnqueueWriteBuffer - Zeroing result count buffer");
        // Convert host_seed to cl_char8 for kernel
        cl_char8 batchSeed;
        host_seed_to_cl_char8(&batchSeedHost, &batchSeed);
        // Debug print: show starting seed for this batch
        char debugSeed[9];
        host_seed_to_string(&batchSeedHost, debugSeed);
        // Set kernel arguments for this run
        err = clSetKernelArg(ssKernel, 0, sizeof(batchSeed), &batchSeed);
        clErrCheck(err, "clSetKernelArg - Adding starting seed argument");
        err = clSetKernelArg(ssKernel, 1, sizeof(cl_long), &thisBatch);
        clErrCheck(err, "clSetKernelArg - Adding number of seeds argument");
        err = clSetKernelArg(ssKernel, 2, sizeof(cl_mem), &configBuf);
        clErrCheck(err, "clSetKernelArg - Adding config struct argument");
        err = clSetKernelArg(ssKernel, 3, sizeof(cl_mem), &resultsBuf);
        clErrCheck(err, "clSetKernelArg - Adding results buffer argument");
        err = clSetKernelArg(ssKernel, 4, sizeof(cl_mem), &resultCountBuf);
        clErrCheck(err, "clSetKernelArg - Adding result count buffer argument");
        // Launch kernel
        cl_int kernelErr = clEnqueueNDRangeKernel(queue, ssKernel, 1, NULL, &globalSize, &localSize, 0, NULL, NULL);
        clErrCheck(kernelErr, "clEnqueueNDRangeKernel - Executing OpenCL kernel");
        err = clFinish(queue);
        clErrCheck(err, "clFinish - Waiting for kernel to finish");
        // Read the number of valid results written
        cl_int numResults = 0;
        err = clEnqueueReadBuffer(queue, resultCountBuf, CL_TRUE, 0, sizeof(cl_int), &numResults, 0, NULL, NULL);
        clErrCheck(err, "clEnqueueReadBuffer - Reading result count");
        // Read only numResults results from the results buffer
        err = clEnqueueReadBuffer(queue, resultsBuf, CL_TRUE, 0, sizeof(OuijiHostResult) * numResults, hostResults, 0, NULL, NULL);
        clErrCheck(err, "clEnqueueReadBuffer - Reading results buffer");
        // Print valid results
        for (int i = 0; i < numResults; i++) {
            if (hostResults[i].valid) {
                printf_s("|%s,%d,%d,", &hostResults[i].seed, hostResults[i].TotalScore, hostResults[i].NegativeJokers);
                for (int j = 0; j < config.numNeeds && j < MAX_DESIRES_HOST; j++) {
                    printf_s("1");
                    if (j < config.numWants - 1 && j < MAX_DESIRES_HOST - 1) printf_s(",");
                }
                for (int j = 0; j < config.numWants && j < MAX_DESIRES_HOST; j++) {
                    printf_s("%d", hostResults[i].ScoreWants[j]);
                    if (j < config.numWants - 1 && j < MAX_DESIRES_HOST - 1) printf_s(",");
                }
                printf_s("\n");
            }
        }
        fflush(stdout);
        // Advance seed and update seedsLeft
        host_seed_skip(&batchSeedHost, thisBatch);
        
        seedsLeft -= thisBatch;
    }
    free(hostResults);
    clReleaseMemObject(resultsBuf);
    clReleaseMemObject(resultCountBuf);

    err = clReleaseMemObject(configBuf);
    err = clReleaseKernel(ssKernel);
    err = clReleaseProgram(ssKernelProgram);
    err = clReleaseCommandQueue(queue);
    err = clReleaseContext(ctx);
    free(devices);
    free(platforms);

    return EXIT_SUCCESS;
}