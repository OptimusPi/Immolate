#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#define MAX_LINE_LENGTH 1024
#define MAX_ITEMS 20
#define CONFIG_TEMPLATE "filters/config_template.cl"
#define CONFIG_OUTPUT "filters/runtime_config.cl"

// Structure to hold item configuration
typedef struct {
    char name[64];
    int score;
    int flags;
    int source;
    char pack_type[64];
} ConfigItem;

// Structure to hold global settings
typedef struct {
    int num_items;
    int max_ante;
    int min_ante;
    char deck[64];
    char stake[64];
    bool use_showman;
    ConfigItem items[MAX_ITEMS];
} Config;

// Function to parse config file
bool parse_config(const char* filename, Config* config) {
    FILE* file = fopen(filename, "r");
    if (!file) {
        printf("Error: Could not open config file %s\n", filename);
        return false;
    }

    char line[MAX_LINE_LENGTH];
    int item_count = 0;
    
    // Set defaults
    config->num_items = 0;
    config->max_ante = 12;
    config->min_ante = 1;
    strcpy(config->deck, "Ghost_Deck");
    strcpy(config->stake, "Black_Stake");
    config->use_showman = true;

    // Parse header section for global settings
    while (fgets(line, MAX_LINE_LENGTH, file)) {
        // Skip comments and empty lines
        if (line[0] == '#' || line[0] == '\n' || line[0] == '\r') continue;
        
        // If we reach [ITEMS] section, break out to handle items
        if (strstr(line, "[ITEMS]")) break;
        
        char key[64], value[64];
        if (sscanf(line, "%63[^=]=%63s", key, value) == 2) {
            if (strcmp(key, "max_ante") == 0) {
                config->max_ante = atoi(value);
            } else if (strcmp(key, "min_ante") == 0) {
                config->min_ante = atoi(value);
            } else if (strcmp(key, "deck") == 0) {
                strcpy(config->deck, value);
            } else if (strcmp(key, "stake") == 0) {
                strcpy(config->stake, value);
            } else if (strcmp(key, "use_showman") == 0) {
                config->use_showman = (strcmp(value, "true") == 0);
            }
        }
    }
    
    // Reset to start of file to find [ITEMS] section
    rewind(file);
    bool items_section = false;
    
    while (fgets(line, MAX_LINE_LENGTH, file)) {
        // Check for items section
        if (strstr(line, "[ITEMS]")) {
            items_section = true;
            continue;
        }
        
        if (!items_section) continue;
        
        // Skip comments and empty lines
        if (line[0] == '#' || line[0] == '\n' || line[0] == '\r') continue;
        
        // Process item line
        char item_name[64];
        int score, flags, source;
        char pack_type[64] = "0";
        
        // Parse CSV format: item_name,score,flags,source,pack_type
        if (sscanf(line, "%63[^,],%d,%d,%d,%63s", 
                 item_name, &score, &flags, &source, pack_type) >= 4) {
            strcpy(config->items[item_count].name, item_name);
            config->items[item_count].score = score;
            config->items[item_count].flags = flags;
            config->items[item_count].source = source;
            strcpy(config->items[item_count].pack_type, pack_type);
            item_count++;
            
            if (item_count >= MAX_ITEMS) {
                printf("Warning: Maximum number of items (%d) reached. Ignoring rest.\n", MAX_ITEMS);
                break;
            }
        }
    }
    
    config->num_items = item_count;
    fclose(file);
    
    if (item_count == 0) {
        printf("Error: No valid items found in config file.\n");
        return false;
    }
    
    return true;
}

// Function to generate the runtime configuration file
bool generate_config_cl(const Config* config) {
    FILE* template_file = fopen(CONFIG_TEMPLATE, "r");
    if (!template_file) {
        printf("Error: Could not open template file %s\n", CONFIG_TEMPLATE);
        return false;
    }
    
    FILE* output_file = fopen(CONFIG_OUTPUT, "w");
    if (!output_file) {
        printf("Error: Could not create output file %s\n", CONFIG_OUTPUT);
        fclose(template_file);
        return false;
    }
    
    // Write preprocessor defines
    fprintf(output_file, "// Auto-generated runtime configuration file - do not edit manually\n");
    fprintf(output_file, "#define CONFIG_ITEMS %d\n", config->num_items);
    fprintf(output_file, "#define CONFIG_USE_SHOWMAN %s\n", config->use_showman ? "true" : "false");
    fprintf(output_file, "#define CONFIG_MAX_ANTE %d\n", config->max_ante);
    fprintf(output_file, "#define CONFIG_MIN_ANTE %d\n", config->min_ante);
    fprintf(output_file, "#define CONFIG_DECK %s\n", config->deck);
    fprintf(output_file, "#define CONFIG_STAKE %s\n", config->stake);
    fprintf(output_file, "\n");
    
    // Write target items array
    fprintf(output_file, "// Target items configuration\n");
    fprintf(output_file, "target_item CONFIG_TARGET_ITEMS[CONFIG_ITEMS] = {\n");
    
    for (int i = 0; i < config->num_items; i++) {
        fprintf(output_file, "    {%s, %d, %d, %d, %s}%s // Item %d\n", 
                config->items[i].name,
                config->items[i].score,
                config->items[i].flags,
                config->items[i].source,
                config->items[i].pack_type,
                (i < config->num_items - 1) ? "," : "",
                i + 1);
    }
    
    fprintf(output_file, "};\n\n");
    fprintf(output_file, "#include \"configurable_search.cl\"\n");
    
    fclose(template_file);
    fclose(output_file);
    
    printf("Successfully generated runtime configuration file: %s\n", CONFIG_OUTPUT);
    return true;
}

void print_usage() {
    printf("Usage: config_generator <config_file>\n");
    printf("Generates a runtime configuration for Immolate based on the settings in config_file\n");
    printf("\nExample config file format:\n");
    printf("max_ante=12\n");
    printf("min_ante=1\n");
    printf("deck=Ghost_Deck\n");
    printf("stake=Black_Stake\n");
    printf("use_showman=true\n");
    printf("\n[ITEMS]\n");
    printf("Showman,10000,0,0,0\n");
    printf("Blueprint,5000,1,0,0\n");
    printf("The_Soul,2000,0,1,Spectral_Pack\n");
}

void print_config(const Config* config) {
    printf("\n--- Configuration Summary ---\n");
    printf("Global Settings:\n");
    printf("  Max Ante: %d\n", config->max_ante);
    printf("  Min Ante: %d\n", config->min_ante);
    printf("  Deck: %s\n", config->deck);
    printf("  Stake: %s\n", config->stake);
    printf("  Use Showman Logic: %s\n", config->use_showman ? "Yes" : "No");
    
    printf("\nItems (%d):\n", config->num_items);
    printf("  %-20s %-8s %-15s %-15s %-15s\n", "Name", "Score", "Flags", "Source", "Pack Type");
    printf("  %-20s %-8s %-15s %-15s %-15s\n", "----", "-----", "-----", "------", "---------");
    
    for (int i = 0; i < config->num_items; i++) {
        printf("  %-20s %-8d %-15d %-15d %-15s\n", 
              config->items[i].name,
              config->items[i].score,
              config->items[i].flags,
              config->items[i].source,
              config->items[i].pack_type);
    }
    printf("\n");
}

int main(int argc, char** argv) {
    if (argc != 2) {
        print_usage();
        return 1;
    }
    
    Config config;
    if (!parse_config(argv[1], &config)) {
        return 1;
    }
    
    print_config(&config);
    
    if (!generate_config_cl(&config)) {
        return 1;
    }
    
    printf("Run Immolate with: immolate -f runtime_config\n");
    
    return 0;
}