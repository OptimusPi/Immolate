#include "lib/ouiji.h"
#include <time.h>
#include <io.h> // For _access on Windows
#define F_OK 0  // File exists flag

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
    #include <unistd.h>    // For access() on POSIX systems
#endif

// --- Define Structs matching OpenCL ---
// C-compatible version of structures defined in ouiji_config.cl
#define MAX_DESIRES_HOST 10

typedef struct {
    int value; // the item, such as Wee_Joker, Perkeo, Sock_andL_Buskin, etc.
    int edition; // NO_Edition, NEgative, Holographuic, or Polychrome
} JokerAndEdition;

// Per-item desire structure
typedef struct {
    int type;          // 0 = JOKER, 1 = ITEM
    int value;         // Item or joker ID
    JokerAndEdition jokerDetails; // Joker and edition details
    int desireByAnte; // Ante by which this item should be found
} HostDesire;

// Simple version of the config - we're only passing basic values for now
typedef struct {
    int numNeeds;
    int numWants;
    HostDesire Needs[MAX_DESIRES_HOST];
    HostDesire Wants[MAX_DESIRES_HOST];
    int maxSearchAnte;  // Maximum ante to search through
    long cutoff;        // Cutoff value from command line
} OuijiConfig;

// Item name to ID mapping
typedef struct {
    char name[50];
    int id;
} ItemMapping;

// Complete mapping of item names to their enum IDs from lib/items.cl
ItemMapping joker_mapping[] = {
    // Jokers - Common (J_C)
    {"Joker", 3},
    {"Greedy_Joker", 4},
    {"Lusty_Joker", 5},
    {"Wrathful_Joker", 6},
    {"Gluttonous_Joker", 7},
    {"Jolly_Joker", 8},
    {"Zany_Joker", 9},
    {"Mad_Joker", 10},
    {"Crazy_Joker", 11},
    {"Droll_Joker", 12},
    {"Sly_Joker", 13},
    {"Wily_Joker", 14},
    {"Clever_Joker", 15},
    {"Devious_Joker", 16},
    {"Crafty_Joker", 17},
    {"Half_Joker", 18},
    {"Credit_Card", 19},
    {"Banner", 20},
    {"Mystic_Summit", 21},
    {"_8_Ball", 22},
    {"Misprint", 23},
    {"Raised_Fist", 24},
    
    // Jokers - Uncommon (J_U)
    {"Joker_Stencil", 58},
    {"Four_Fingers", 59},
    {"Mime", 60},
    {"Ceremonial_Dagger", 61},
    {"Marble_Joker", 62},
    {"Loyalty_Card", 63},
    {"Dusk", 64},
    {"Fibonacci", 65},
    {"Steel_Joker", 66},
    {"Hack", 67},
    {"Pareidolia", 68},
    {"Space_Joker", 69},
    
    // Jokers - Rare (J_R)
    {"DNA", 164},
    {"Vampire", 165},
    {"Vagabond", 166},
    {"Baron", 167},
    {"Obelisk", 168},
    {"Baseball_Card", 169},
    {"Ancient_Joker", 170},
    {"Campfire", 171},
    {"Blueprint", 172},
    {"Brainstorm", 173},
    
    // Jokers - Legendary (J_L)
    {"Canio", 178},
    {"Triboulet", 179},
    {"Yorick", 180},
    {"Chicot", 181},
    {"Perkeo", 182},
    
    // Spectral cards
    {"Familiar", 275},
    {"Ankh", 285},
    {"Ectoplasm", 286},
    {"The_Soul", 292},
    
    // Tags
    {"Negative_Tag", 309},
    {"Orbital_Tag", 329},
    
    // Vouchers
    {"Observatory", 239},
    {"Telescope", 238},
    {"Magic_Trick", 252},
    
    // End marker
    {"", 0}
};

// Helper function to parse a string item name to its numeric ID
int item_name_to_id(const char* name) {
    for (int i = 0; joker_mapping[i].id != 0; i++) {
        if (strcmp(joker_mapping[i].name, name) == 0) {
            return joker_mapping[i].id;
        }
    }
    // Default to Joker ID if not found
    printf_s("Warning: Unknown item name: %s - using default ID\n", name);
    return 181; // Default to Showman as fallback
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

// Load configuration from JSON file
int load_config_from_json(const char* config_filename, OuijiConfig* config) {
    char config_path[MAX_PATH];
    char executable_dir[MAX_PATH];
    
    getExecutableDir(executable_dir);
    
    // First try to load from ouiji_configs directory
    snprintf(config_path, MAX_PATH, "%s%souiji_configs%s%s", 
             executable_dir, PATH_SEPARATOR, PATH_SEPARATOR, config_filename);
             
    // If file doesn't exist with extension, try adding it
    if (access(config_path, F_OK) != 0) {
        if (strstr(config_filename, ".ouiji.json") == NULL) {
            snprintf(config_path, MAX_PATH, "%s%souiji_configs%s%s.ouiji.json", 
                     executable_dir, PATH_SEPARATOR, PATH_SEPARATOR, config_filename);
        }
    }
    
    // If still doesn't exist, try as absolute path
    if (access(config_path, F_OK) != 0) {
        strncpy(config_path, config_filename, MAX_PATH);
    }
    
    printf_s("Attempting to load config from: %s\n", config_path);
    
    FILE* file = fopen(config_path, "r");
    if (!file) {
        printf_s("Error: Could not open configuration file: %s\n", config_path);
        return 0;
    }
    
    // Read file contents
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    rewind(file);
    
    char* json_content = malloc(file_size + 1);
    if (!json_content) {
        printf_s("Error: Memory allocation failed when reading config file\n");
        fclose(file);
        return 0;
    }
    
    fread(json_content, 1, file_size, file);
    json_content[file_size] = '\0';
    fclose(file);
    
    // Simple JSON parsing - find "filter_config" section 
    char* filter_config = strstr(json_content, "\"filter_config\"");
    if (!filter_config) {
        printf_s("Error: No filter_config section found in JSON\n");
        free(json_content);
        return 0;
    }
    
    // Extract numNeeds
    char* num_needs_str = strstr(filter_config, "\"numNeeds\"");
    if (num_needs_str) {
        num_needs_str = strstr(num_needs_str, ":");
        if (num_needs_str) {
            config->numNeeds = atoi(num_needs_str + 1);
        }
    }
    
    // Extract numWants
    char* num_wants_str = strstr(filter_config, "\"numWants\"");
    if (num_wants_str) {
        num_wants_str = strstr(num_wants_str, ":");
        if (num_wants_str) {
            config->numWants = atoi(num_wants_str + 1);
        }
    }
    
    // Extract maxSearchAnte
    char* max_search_ante_str = strstr(filter_config, "\"maxSearchAnte\"");
    if (max_search_ante_str) {
        max_search_ante_str = strstr(max_search_ante_str, ":");
        if (max_search_ante_str) {
            config->maxSearchAnte = atoi(max_search_ante_str + 1);
        }
    } else {
        config->maxSearchAnte = 8; // Default value
    }
    
    // Parse Needs section
    char* needs_section = strstr(filter_config, "\"Needs\"");
    if (needs_section) {
        int need_index = 0;
        
        char* need_start = needs_section;
        while ((need_start = strstr(need_start, "\"value\"")) && need_index < MAX_DESIRES_HOST) {
            need_start = strchr(need_start, ':');
            if (!need_start) break;
            need_start++;
            
            // Skip whitespace and quotes
            while (*need_start && (*need_start == ' ' || *need_start == '"')) need_start++;
            
            // Find the end of the value
            char* need_end = strchr(need_start, '"');
            if (!need_end) break;
            
            // Extract and copy the value name
            char value_name[50];
            int value_len = (need_end - need_start < 49) ? (need_end - need_start) : 49;
            strncpy(value_name, need_start, value_len);
            value_name[value_len] = '\0';
            
            // Set the need type and value
            config->Needs[need_index].type = 0; // Default to Joker
            config->Needs[need_index].value = item_name_to_id(value_name);
            
            // Find desireByAnte
            char* ante_str = strstr(need_start, "\"desireByAnte\"");
            if (ante_str) {
                ante_str = strchr(ante_str, ':');
                if (ante_str) {
                    config->Needs[need_index].desireByAnte = atoi(ante_str + 1);
                } else {
                    config->Needs[need_index].desireByAnte = 4; // Default value
                }
            } else {
                config->Needs[need_index].desireByAnte = 4; // Default value
            }
            
            need_index++;
        }
    }
    
    // Parse Wants section - similar to Needs section
    char* wants_section = strstr(filter_config, "\"Wants\"");
    if (wants_section) {
        int want_index = 0;
        
        char* want_start = wants_section;
        while ((want_start = strstr(want_start, "\"value\"")) && want_index < MAX_DESIRES_HOST) {
            want_start = strchr(want_start, ':');
            if (!want_start) break;
            want_start++;
            
            // Skip whitespace and quotes
            while (*want_start && (*want_start == ' ' || *want_start == '"')) want_start++;
            
            // Find the end of the value
            char* want_end = strchr(want_start, '"');
            if (!want_end) break;
            
            // Extract and copy the value name
            char value_name[50];
            int value_len = (want_end - want_start < 49) ? (want_end - want_start) : 49;
            strncpy(value_name, want_start, value_len);
            value_name[value_len] = '\0';
            
            // Set the want type and value
            config->Wants[want_index].type = 0; // Default to Joker
            config->Wants[want_index].value = item_name_to_id(value_name);
            
            // Find desireByAnte
            char* ante_str = strstr(want_start, "\"desireByAnte\"");
            if (ante_str) {
                ante_str = strchr(ante_str, ':');
                if (ante_str) {
                    config->Wants[want_index].desireByAnte = atoi(ante_str + 1);
                } else {
                    config->Wants[want_index].desireByAnte = 8; // Default value for wants
                }
            } else {
                config->Wants[want_index].desireByAnte = 8; // Default value for wants
            }
            
            want_index++;
        }
    }
    
    free(json_content);
    printf_s("Successfully loaded configuration from %s\n", config_path);
    return 1;
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
    config.cutoff = 0;           // Default cutoff
    config.numNeeds = 0;         // Default number of needs
    config.numWants = 0;         // Default number of wants
    config.maxSearchAnte = 8;    // Default maximum ante to search through

    char* filter = "ouiji_template"; // Default filter
    int gui_mode = 0;          // GUI mode flag
    char* config_file = NULL;  // Configuration file path

    // --- Argument Parsing Loop ---
    for (int i = 0; i < argc; i++) {
        if (strcmp(argv[i], "-h")==0) {
            printf_s("Valid command line arguments:\n-h        Shows this help dialog.\n-f <F>    Sets the filter used by Ouiji to F. Defaults to ouiji_template\n-s <S>    Sets the starting seed to S. Defaults to empty seed. Use \"random\" for a random starting seed.\n-n <N>    Sets the number of seeds to search to N. Defaults to full seed pool.\n-c <C>    Sets the cutoff score for a seed to be printed to C. Defaults to 1.\n-p <P>    Sets the platform ID of the CL device being used to P. Defaults to 0.\n-d <D>    Sets the device ID of the CL device being used to D. Defaults to 0.\n-g <G>    Sets the number of thread groups to G. Defaults to 16. Increasing this might help Ouiji run faster.\n--config <JSON>  Load configuration from a JSON file.\n--list_devices   Lists information about the detected CL devices.\n--gui    Enables GUI streaming mode.");
            return 0;
        }
        if (strcmp(argv[i], "--gui")==0) {
            gui_mode = 1;
            printf_s("GUI mode enabled. Results will be formatted for GUI parsing.\n");
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
                srand(time(NULL));
                char seedCharacters[] = {'1','2','3','4','5','6','7','8','9','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'};
                startingSeed.s[0] = seedCharacters[rand() % 25 + 10];
                startingSeed.s[1] = seedCharacters[rand() % 25 + 10];
                startingSeed.s[2] = seedCharacters[9];
                startingSeed.s[3] = seedCharacters[9];
                startingSeed.s[4] = seedCharacters[9];
                startingSeed.s[5] = seedCharacters[10];
                startingSeed.s[6] = seedCharacters[11];
                startingSeed.s[7] = seedCharacters[11];
            } else {
                for (int j = 0; j < seedLength; j++) {
                    startingSeed.s[j] = argv[i+1][j];
                }
                for (int j = seedLength; j < 8; j++) {
                    startingSeed.s[j] = '\0';
                }
            }
            printf_s("Starting seed set to %s\n", startingSeed.s);
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
                    printf_s("  - Item %d by ante %d\n", 
                            config.Needs[i].value, config.Needs[i].desireByAnte);
                }
            }
            
            // Print wants information
            if (config.numWants > 0) {
                printf_s("Wants:\n");
                for (int i = 0; i < config.numWants && i < MAX_DESIRES_HOST; i++) {
                    printf_s("  - Item %d\n", config.Wants[i].value);
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
        printf_s("No pre-compiled kernel binary found. Compiling from source...\n");
    }

    if (!loaded_from_binary) {
        printf_s("Building program...\n");
        strcpy_s(kernel_path, sizeof kernel_path, executable_dir);
        strcat_s(kernel_path, sizeof kernel_path, PATH_SEPARATOR);
        strcat_s(kernel_path, sizeof kernel_path, "ouiji_search.cl");

        fp = fopen(kernel_path, "r");
        if (!fp) {
            printf_s("Warning: Kernel source not found at %s, attempting working directory...\n", kernel_path);
            fp = fopen("ouiji_search.cl","r");
            if (!fp) {
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
    printf_s("Kernel Binary is ready. Building OpenCL...\n");

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

    printf("Kernel program built successfully. Setting PArameters\n");
    cl_kernel ssKernel = clCreateKernel(ssKernelProgram, "ouiji_search", &err);
    clErrCheck(err, "clCreateKernel - Creating OpenCL kernel");

    cl_mem configBuf = clCreateBuffer(ctx, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, sizeof(OuijiConfig), &config, &err);
    clErrCheck(err, "clCreateBuffer - Creating config buffer");

    err = clSetKernelArg(ssKernel, 0, sizeof(startingSeed), &startingSeed);
    clErrCheck(err, "clSetKernelArg - Adding starting seed argument");
    err = clSetKernelArg(ssKernel, 1, sizeof(numSeeds), &numSeeds);
    clErrCheck(err, "clSetKernelArg - Adding number of seeds argument");
    err = clSetKernelArg(ssKernel, 2, sizeof(cl_mem), &configBuf);
    clErrCheck(err, "clSetKernelArg - Adding config struct argument");

    size_t globalSize = numGroups * numGroups;
    size_t localSize = numGroups;
    printf_s("Starting search with filter %s\n", filter);
    err = clEnqueueNDRangeKernel(queue, ssKernel, 1, NULL, &globalSize, &localSize, 0, NULL, NULL);
    clErrCheck(err, "clEnqueueNDRangeKernel - Executing OpenCL kernel");

    // Clean up
    err = clReleaseMemObject(configBuf);
    err = clReleaseKernel(ssKernel);
    err = clReleaseProgram(ssKernelProgram);
    err = clReleaseCommandQueue(queue);
    err = clReleaseContext(ctx);
    free(devices);
    free(platforms);

    return EXIT_SUCCESS;
}