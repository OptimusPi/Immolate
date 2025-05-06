#include "host_items.h"
#include "lib/ouiji.h"
#include <io.h> // For _access on Windows

#ifndef __OUIJI_CONFIG_LOADER_H_
#define __OUIJI_CONFIG_LOADER_H_

#define MAX_DESIRES_HOST 10
#define F_OK 0  // File exists flag


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
    cl_long cutoff; // Cutoff value from command line
} OuijiConfig;

// Load configuration from JSON file
int load_config_from_json(const char* config_filename, OuijiConfig* config) {
    char config_path[MAX_PATH];
    char executable_dir[MAX_PATH];
    
    // First try to load from ouiji_configs directory
    snprintf(config_path, MAX_PATH, "%s%souiji_configs%s%s", 
             executable_dir, PATH_SEPARATOR, PATH_SEPARATOR, config_filename);
             
    // If file doesn't exist with extension, try adding it
    if (_access(config_path, F_OK) != 0) {
        if (strstr(config_filename, ".ouiji.json") == NULL) {
            snprintf(config_path, MAX_PATH, "%s%souiji_configs%s%s.ouiji.json", 
                     executable_dir, PATH_SEPARATOR, PATH_SEPARATOR, config_filename);
        }
    }
    
    // If still doesn't exist, try as absolute path
    if (_access(config_path, F_OK) != 0) {
        strncpy_s(config_path, MAX_PATH, config_filename, MAX_PATH);
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
        
        // Find the start of each Need item
        char* need_start = needs_section;
        while (need_index < MAX_DESIRES_HOST && need_index < config->numNeeds) {
            // Find the "type" field within the current Need
            need_start = strstr(need_start, "\"type\"");
            if (!need_start) break;
            
            need_start = strchr(need_start, ':');
            if (!need_start) break;
            need_start++;
            
            // Skip whitespace and quotes
            while (*need_start && (*need_start == ' ' || *need_start == '"')) need_start++;
            
            // Find the end of the type value
            char* need_end = strchr(need_start, '"');
            if (!need_end) break;
            
            // Extract and copy the type name
            char type_name[50];
            size_t type_len = (need_end - need_start < 49) ? (need_end - need_start) : 49;
            strncpy_s(type_name, sizeof(type_name), need_start, type_len);
            type_name[type_len] = '\0';
            
            // Find the start of the value
            need_start = strstr(need_start, "\"value\"");
            if (!need_start) break;

            need_start = strchr(need_start, ':');
            if (!need_start) break;
            need_start++;
            
            // Skip whitespace and quotes
            while (*need_start && (*need_start == ' ' || *need_start == '"')) need_start++;
            
            // Find the end of the value
            need_end = strchr(need_start, '"');
            if (!need_end) break;
            
            // Extract and copy the value name
            char value_name[50];
            size_t value_len = (need_end - need_start < 49) ? (need_end - need_start) : 49;
            strncpy_s(value_name, sizeof(value_name), need_start, value_len);
            value_name[value_len] = '\0';
            
            // Set the need value (but not type, as it's already set above)
            config->Needs[need_index].value = parse_item(value_name);
            
            // Look for joker details
            char* joker_section = strstr(need_start, "\"joker\"");
            if (joker_section) {
                // Find edition field
                char* edition_section = strstr(joker_section, "\"edition\"");
                if (edition_section) {
                    edition_section = strchr(edition_section, ':');
                    if (edition_section) {
                        edition_section++;
                        // Skip whitespace and quotes
                        while (*edition_section && (*edition_section == ' ' || *edition_section == '"')) edition_section++;
                        
                        // Find end of edition value
                        char* edition_end = strchr(edition_section, '"');
                        if (edition_end) {
                            char edition_name[50];
                            size_t edition_len = (edition_end - edition_section < 49) ? (edition_end - edition_section) : 49;
                            strncpy_s(edition_name, sizeof(edition_name), edition_section, edition_len);
                            edition_name[edition_len] = '\0';
                            
                            // Set the edition value
                            config->Needs[need_index].jokeredition = parse_item(edition_name);
                        }
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
        
        // Find the start of each Want item
        char* want_start = wants_section;
        while (want_index < MAX_DESIRES_HOST && want_index < config->numWants) {
            // Find the "type" field within the current Want
            want_start = strstr(want_start, "\"type\"");
            if (!want_start) break;
            
            want_start = strchr(want_start, ':');
            if (!want_start) break;
            want_start++;
            
            // Skip whitespace and quotes
            while (*want_start && (*want_start == ' ' || *want_start == '"')) want_start++;
            
            // Extract and copy the type name
            char* want_end = strchr(want_start, '"');
            if (!want_end) break;
            
            char type_name[50];
            size_t type_len = (want_end - want_start < 49) ? (want_end - want_start) : 49;
            strncpy_s(type_name, sizeof(type_name), want_start, type_len);
            type_name[type_len] = '\0';
            
            // Now find the "value" field
            want_start = strstr(want_start, "\"value\"");
            if (!want_start) break;
            
            want_start = strchr(want_start, ':');
            if (!want_start) break;
            want_start++;
            
            // Skip whitespace and quotes
            while (*want_start && (*want_start == ' ' || *want_start == '"')) want_start++;
            
            // Find the end of the value
            want_end = strchr(want_start, '"');
            if (!want_end) break;
            
            // Extract and copy the value name
            char value_name[50];
            size_t value_len = (want_end - want_start < 49) ? (want_end - want_start) : 49;
            strncpy_s(value_name, sizeof(value_name), want_start, value_len);
            value_name[value_len] = '\0';
            
            // Set the Want's value based on the parsed name
            config->Wants[want_index].value = parse_item(value_name);
            
            // Look for joker details
            char* joker_section = strstr(want_start, "\"joker\"");
            if (joker_section) {
                // Find edition field
                char* edition_section = strstr(joker_section, "\"edition\"");
                if (edition_section) {
                    edition_section = strchr(edition_section, ':');
                    if (edition_section) {
                        edition_section++;
                        // Skip whitespace and quotes
                        while (*edition_section && (*edition_section == ' ' || *edition_section == '"')) edition_section++;
                        
                        // Find end of edition value
                        char* edition_end = strchr(edition_section, '"');
                        if (edition_end) {
                            char edition_name[50];
                            size_t edition_len = (edition_end - edition_section < 49) ? (edition_end - edition_section) : 49;
                            strncpy_s(edition_name, sizeof(edition_name), edition_section, edition_len);
                            edition_name[edition_len] = '\0';
                            
                            // Set the edition value
                            config->Wants[want_index].jokeredition = parse_item(edition_name);
                        }
                    }
                }
            }
            
            // Find desireByAnte
            char* ante_str = strstr(want_start, "\"desireByAnte\"");
            if (ante_str) {
                ante_str = strchr(ante_str, ':');
                if (ante_str) {
                    config->Wants[want_index].desireByAnte = atoi(ante_str + 1);
                } else {
                    config->Wants[want_index].desireByAnte = 8; // Default value
                }
            } else {
                config->Wants[want_index].desireByAnte = 8; // Default value
            }
            want_index++;
            
            // Move to the next Want item if there are more
            want_start = strstr(want_start, "},");
            if (!want_start) break;
            want_start += 2;
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
        stake_str = strstr(stake_str, ":");
        if (stake_str) {
            stake_str++;
            while (*stake_str && (*stake_str == ' ' || *stake_str == '"')) stake_str++;
            char stake_name[50];
            char* end = strchr(stake_str, '"');
            if (end) {
                size_t len = (end - stake_str < 49) ? (end - stake_str) : 49;
                strncpy_s(stake_name, sizeof(stake_name), stake_str, len);
                stake_name[len] = '\0';
                config->stake = parse_item(stake_name);
            }
        }
    } else {
        config->stake = RETRY; // Default value
    }
    printf_s("loaded deck: %d\n", config->deck);
    printf_s("loaded stake: %d\n", config->stake);
    }


    free(json_content);
    printf_s("Successfully loaded configuration from %s\n", config_path);
    fflush(stdout);


    printf_s("config loader on HOST: sizeof(OuijiConfig) = %zu\n", sizeof(OuijiConfig));
    printf_s("config loader on HOST: sizeof(HostDesire) = %zu\n", sizeof(HostDesire));
    printf_s("config loader on HOST: sizeof(OuijiConfig) = %zu\n", sizeof(OuijiConfig));
    printf_s("config loader on HOST: sizeof(HostDesire) = %zu\n", sizeof(HostDesire));
    printf("sizeof(OuijiConfig) = %zu\n", sizeof(OuijiConfig));
    printf("sizeof(HostDesire) = %zu\n", sizeof(HostDesire));
    printf("offsetof(OuijiConfig, cutoff) = %zu\n", offsetof(OuijiConfig, cutoff));
    printf("offsetof(OuijiConfig, deck) = %zu\n", offsetof(OuijiConfig, deck));
    printf("offsetof(OuijiConfig, stake) = %zu\n", offsetof(OuijiConfig, stake));
    printf("offsetof(OuijiConfig, Needs) = %zu\n", offsetof(OuijiConfig, Needs));
    printf("offsetof(OuijiConfig, Wants) = %zu\n", offsetof(OuijiConfig, Wants));
    printf("sizeof(item) = %zu\n", sizeof(item));
    fflush(stdout);
    
    return 1;
}
#endif