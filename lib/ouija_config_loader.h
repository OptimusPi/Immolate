#include "host_items.h"
#include "../lib/ouija.h"
#include <io.h> // For _access on Windows
#include <windows.h> // For GetModuleFileNameA
#include <string.h> // For strstr, strrchr
#include <stdio.h>  // For snprintf

#ifndef __OUIJA_CONFIG_LOADER_H_
#define __OUIJA_CONFIG_LOADER_H_

#define MAX_DESIRES_HOST 16 // Changed from 10 to 16 to match MAX_DESIRES_KERNEL
#define F_OK 0  // File exists flag

// Define PATH_SEPARATOR based on OS
#ifdef _WIN32
    #define PATH_SEPARATOR_STR "\\"
#else
    #define PATH_SEPARATOR_STR "/"
#endif

typedef struct {
    item value;         // Item or joker ID
    item jokeredition;      // Joker edition if type is Joker, otherwise value = RETRY
    cl_int desireByAnte;  // Ante by which this item should be found
} HostDesire;

// Simple version of the config - we're only passing basic values for now
typedef struct {
    cl_int numNeeds;
    cl_int numWants;
    HostDesire Needs[MAX_DESIRES_HOST];
    HostDesire Wants[MAX_DESIRES_HOST];
    cl_int maxSearchAnte;  // Maximum ante to search through
    item deck;
    item stake;
} OuijaConfig;

// Load configuration from JSON file
int load_config_from_json(const char* config_filename, OuijaConfig* config) {
    char config_path[MAX_PATH];
    char executable_dir[MAX_PATH] = {0}; // Initialize to empty string
    char full_exe_path[MAX_PATH];

    // Get the full path of the executable to find its directory
    if (GetModuleFileNameA(NULL, full_exe_path, MAX_PATH) == 0) {
        // Could not get executable path, so executable_dir remains empty or "."
        // This means the first set of attempts might effectively become relative to CWD if executable_dir is "."
        // Or, if it's empty, snprintf might produce odd paths. Let's default to "."
        printf_s("Warning: GetModuleFileNameA failed. Trying paths relative to current directory.\n");
        strncpy_s(executable_dir, MAX_PATH, ".", _TRUNCATE);
    } else {
        char* last_slash = strrchr(full_exe_path, PATH_SEPARATOR_STR[0]); // Use the char for strrchr
        if (last_slash != NULL) {
            size_t dir_len = last_slash - full_exe_path;
            if (dir_len < MAX_PATH) {
                strncpy_s(executable_dir, MAX_PATH, full_exe_path, dir_len);
                // executable_dir[dir_len] = '\0'; // strncpy_s with _TRUNCATE should null terminate if space
            } else {
                printf_s("Warning: Executable directory path too long. Trying paths relative to current directory.\n");
                strncpy_s(executable_dir, MAX_PATH, ".", _TRUNCATE);
            }
        } else {
            // No slash found, assume executable is in current dir or path is just filename
            strncpy_s(executable_dir, MAX_PATH, ".", _TRUNCATE);
        }
    }

    // Attempt 1: Executable directory + "ouija_configs" + given name
    snprintf(config_path, MAX_PATH, "%s%souija_configs%s%s",
             executable_dir, PATH_SEPARATOR_STR, PATH_SEPARATOR_STR, config_filename);
    if (_access(config_path, F_OK) == 0) {
        goto found_path_or_continue_parsing;
    }

    // Attempt 2: Executable directory + "ouija_configs" + given name + ".ouija.json"
    if (strstr(config_filename, ".ouija.json") == NULL) {
        snprintf(config_path, MAX_PATH, "%s%souija_configs%s%s.ouija.json",
                 executable_dir, PATH_SEPARATOR_STR, PATH_SEPARATOR_STR, config_filename);
        if (_access(config_path, F_OK) == 0) {
            goto found_path_or_continue_parsing;
        }
    }

    // Attempt 3: Current working directory ('.') + "ouija_configs" + given name
    snprintf(config_path, MAX_PATH, ".%souija_configs%s%s",
             PATH_SEPARATOR_STR, PATH_SEPARATOR_STR, config_filename);
    if (_access(config_path, F_OK) == 0) {
        goto found_path_or_continue_parsing;
    }

    // Attempt 4: Current working directory ('.') + "ouija_configs" + given name + ".ouija.json"
    if (strstr(config_filename, ".ouija.json") == NULL) {
        snprintf(config_path, MAX_PATH, ".%souija_configs%s%s.ouija.json",
                 PATH_SEPARATOR_STR, PATH_SEPARATOR_STR, config_filename);
        if (_access(config_path, F_OK) == 0) {
            goto found_path_or_continue_parsing;
        }
    }

    // Attempt 5: Given name directly (as absolute path or relative to current working directory)
    strncpy_s(config_path, MAX_PATH, config_filename, _TRUNCATE);
    if (_access(config_path, F_OK) == 0) {
        goto found_path_or_continue_parsing;
    }

    // Attempt 6: Given name directly + ".ouija.json"
    if (strstr(config_filename, ".ouija.json") == NULL) {
        snprintf(config_path, MAX_PATH, "%s.ouija.json", config_filename);
        if (_access(config_path, F_OK) == 0) {
            goto found_path_or_continue_parsing;
        }
    }
    // If all attempts fail, config_path will hold the last attempted path,
    // and the fopen_s below will fail, printing an error with that path.

found_path_or_continue_parsing:
    printf_s("Attempting to load config from: %s\n", config_path);

    // Using the safer fopen_s instead of deprecated fopen
    FILE* file = NULL;
    errno_t err = fopen_s(&file, config_path, "r");
    if (err != 0 || !file) {
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
    printf_s("loaded numNeeds: %d\n", config->numNeeds);
    
    // Extract numWants
    char* num_wants_str = strstr(filter_config, "\"numWants\"");
    if (num_wants_str) {
        num_wants_str = strstr(num_wants_str, ":");
        if (num_wants_str) {
            config->numWants = atoi(num_wants_str + 1);
        }
    }
    printf_s("loaded numWants: %d\n", config->numWants);

    // Initialize Needs and Wants arrays
    for (int i = 0; i < MAX_DESIRES_HOST; i++) {
        config->Needs[i].value = RETRY;
        config->Needs[i].jokeredition = RETRY;
        config->Needs[i].desireByAnte = 8;
        
        config->Wants[i].value = RETRY;
        config->Wants[i].jokeredition = RETRY;
        config->Wants[i].desireByAnte = 8;
    }
    
    // Parse Needs section
    char* needs_section = strstr(filter_config, "\"Needs\"");
    if (needs_section) {
        int need_index = 0;
        char* need_start = needs_section;
        while (need_index < MAX_DESIRES_HOST && need_index < config->numNeeds) {
            // Find the "value" field
            need_start = strstr(need_start, "\"value\"");
            if (!need_start) break;
            need_start = strchr(need_start, ':');
            if (!need_start) break;
            need_start++;
            while (*need_start && (*need_start == ' ' || *need_start == '"')) need_start++;
            char* need_end = strchr(need_start, '"');
            if (!need_end) break;
            char value_name[50];
            size_t value_len = (need_end - need_start < 49) ? (need_end - need_start) : 49;
            strncpy_s(value_name, sizeof(value_name), need_start, value_len);
            value_name[value_len] = '\0';
            config->Needs[need_index].value = parse_item(value_name);

            // Find the "jokeredition" field (flat, not nested)
            char* edition_section = strstr(need_start, "\"jokeredition\"");
            if (edition_section) {
                edition_section = strchr(edition_section, ':');
                if (edition_section) {
                    edition_section++;
                    while (*edition_section && (*edition_section == ' ' || *edition_section == '"')) edition_section++;
                    char* edition_end = strchr(edition_section, '"');
                    if (edition_end) {
                        char edition_name[50];
                        size_t edition_len = (edition_end - edition_section < 49) ? (edition_end - edition_section) : 49;
                        strncpy_s(edition_name, sizeof(edition_name), edition_section, edition_len);
                        edition_name[edition_len] = '\0';
                        // Validate that the item is a joker before assigning a jokeredition
                        if (config->Needs[need_index].value >= J_BEGIN && config->Needs[need_index].value <= J_C_END) {
                            config->Needs[need_index].jokeredition = parse_item(edition_name);
                        } else {
                            config->Needs[need_index].jokeredition = RETRY;
                        }
                    } else {
                        config->Needs[need_index].jokeredition = RETRY;
                    }
                }
            }
            // Find desireByAnte
            char* ante_str = strstr(need_start, "\"desireByAnte\"");
            if (ante_str) {
                ante_str = strchr(ante_str, ':');
                if (ante_str) {
                    config->Needs[need_index].desireByAnte = atoi(ante_str + 1);
                } else {
                    config->Needs[need_index].desireByAnte = 8;
                }
            } else {
                config->Needs[need_index].desireByAnte = 8;
            }
            need_index++;
            // Move to the next Need item if there are more
            need_start = strstr(need_start, "},");
            if (!need_start) break;
            need_start += 2;
        }
    }

    // Parse Wants section
    char* wants_section = strstr(filter_config, "\"Wants\"");
    if (wants_section) {
        int want_index = 0;
        char* want_start = wants_section;
        while (want_index < MAX_DESIRES_HOST && want_index < config->numWants) {
            // Find the "value" field
            want_start = strstr(want_start, "\"value\"");
            if (!want_start) break;
            want_start = strchr(want_start, ':');
            if (!want_start) break;
            want_start++;
            while (*want_start && (*want_start == ' ' || *want_start == '"')) want_start++;
            char* want_end = strchr(want_start, '"');
            if (!want_end) break;
            char value_name[50];
            size_t value_len = (want_end - want_start < 49) ? (want_end - want_start) : 49;
            strncpy_s(value_name, sizeof(value_name), want_start, value_len);
            value_name[value_len] = '\0';
            config->Wants[want_index].value = parse_item(value_name);

            // Find the "jokeredition" field (flat, not nested)
            char* edition_section = strstr(want_start, "\"jokeredition\"");
            if (edition_section) {
                edition_section = strchr(edition_section, ':');
                if (edition_section) {
                    edition_section++;
                    while (*edition_section && (*edition_section == ' ' || *edition_section == '"')) edition_section++;
                    char* edition_end = strchr(edition_section, '"');
                    if (edition_end) {
                        char edition_name[50];
                        size_t edition_len = (edition_end - edition_section < 49) ? (edition_end - edition_section) : 49;
                        strncpy_s(edition_name, sizeof(edition_name), edition_section, edition_len);
                        edition_name[edition_len] = '\0';
                        config->Wants[want_index].jokeredition = parse_item(edition_name);
                    } else {
                        config->Wants[want_index].jokeredition = RETRY;
                    }
                }
            } else {
                config->Wants[want_index].jokeredition = RETRY;
            }

            // Find desireByAnte
            char* ante_str = strstr(want_start, "\"desireByAnte\"");
            if (ante_str) {
                ante_str = strchr(ante_str, ':');
                if (ante_str) {
                    config->Wants[want_index].desireByAnte = atoi(ante_str + 1);
                } else {
                    config->Wants[want_index].desireByAnte = 8;
                }
            } else {
                config->Wants[want_index].desireByAnte = 8;
            }
            want_index++;
            // Move to the next Want item if there are more
            want_start = strstr(want_start, "},");
            if (!want_start) break;
            want_start += 2;
        }
    }

    // Extract maxSearchAnte
    char* max_search_ante_str = strstr(filter_config, "\"maxSearchAnte\"");
    if (max_search_ante_str) {
        max_search_ante_str = strstr(max_search_ante_str, ":");
        if (max_search_ante_str) {
            config->maxSearchAnte = atoi(max_search_ante_str + 1);
            if (config->maxSearchAnte < 1) {
                printf_s("Warning: maxSearchAnte is set to %d, which is less than 1.\n", config->maxSearchAnte);
                config->maxSearchAnte = 8; // Reset to default
            }
        }
    } else {
        config->maxSearchAnte = 8; // Default value
    }

    if (config->maxSearchAnte > 8) {
        printf_s("Warning: maxSearchAnte is set to %d, which is higher than the default of 8.\n", config->maxSearchAnte);
        printf_s("  - max_search_ante_str is: %s\n", max_search_ante_str);
        config->maxSearchAnte = 8; // Reset to default
    } else {
        printf_s("loaded maxSearchAnte: %d\n", config->maxSearchAnte);
    }

    // Extract deck    // Extract deck
    char* deck_str = strstr(filter_config, "\"deck\"");
    if (deck_str) {
        deck_str = strstr(deck_str, ":");
        if (deck_str) {
            deck_str++;
            while (*deck_str && (*deck_str == ' ' || *deck_str == '"')) deck_str++;
            char deck_name[50];
            char* end = strchr(deck_str, '"');
            if (end) {
                size_t len = (end - deck_str < 49) ? (end - deck_str) : 49;
                strncpy_s(deck_name, sizeof(deck_name), deck_str, len);
                deck_name[len] = '\0';
                config->deck = parse_item(deck_name);
            }
        }
    } else {
        config->deck = RETRY; // Default value
    }

    //Extract stake
    char* stake_str = strstr(filter_config, "\"stake\"");
    if (stake_str) {
        stake_str = strchr(stake_str, ':');
        if (stake_str) {
            stake_str++;
            while (*stake_str && (*stake_str == ' ' || *stake_str == '"')) stake_str++;
            char stake_name[50] = {0};
            char* end = stake_str;
            // Find the end of the value (either quote or comma or end of line)
            while (*end && *end != '"' && *end != ',' && *end != '\n' && *end != '}') end++;
            size_t len = (end - stake_str < 49) ? (end - stake_str) : 49;
            strncpy_s(stake_name, sizeof(stake_name), stake_str, len);
            stake_name[len] = '\0';
            printf_s("raw stake string: '%s'\n", stake_name);
            config->stake = parse_item(stake_name);
            printf_s("parsed stake: %d\n", config->stake);
            printf_s("stake name: '%s'\n", stake_name);
            print_item_host(config->stake);
            printf_s("\n");
        }
    } else {
        config->stake = RETRY; // Default value
    }
    printf_s("loaded deck: ");
    print_item_host(config->deck);
    printf_s("\n");
    printf_s("loaded stake: ");
    print_item_host(config->stake);
    printf_s("\n");

    free(json_content);
    printf_s("Successfully loaded configuration from %s\n", config_path);
    fflush(stdout);
    return 1;
}
#endif