@echo off
setlocal enabledelayedexpansion

REM Immolate Config Generator - No compilation required
echo Immolate Configuration Generator v3.1.4

if "%~1"=="" (
    echo Error: No configuration file specified.
    echo Usage: generate_config.bat config_file.txt
    exit /b 1
)

if not exist "%~1" (
    echo Error: Configuration file %~1 not found.
    exit /b 1
)

REM Set default values
set MAX_ANTE=12
set MIN_ANTE=1
set DECK=Ghost_Deck
set STAKE=Black_Stake
set USE_SHOWMAN=true
set ITEMS=0

REM Create output file
set OUTPUT_FILE=filters\runtime_config.cl
echo // Auto-generated runtime configuration - Generated %date% %time% > %OUTPUT_FILE%

REM Read global settings
for /f "tokens=1,2 delims==" %%a in (%~1) do (
    set KEY=%%a
    set VALUE=%%b
    
    if "!KEY!"=="max_ante" set MAX_ANTE=!VALUE!
    if "!KEY!"=="min_ante" set MIN_ANTE=!VALUE!
    if "!KEY!"=="deck" set DECK=!VALUE!
    if "!KEY!"=="stake" set STAKE=!VALUE!
    if "!KEY!"=="use_showman" set USE_SHOWMAN=!VALUE!
)

REM Write settings to config file
echo #define CONFIG_USE_SHOWMAN %USE_SHOWMAN% >> %OUTPUT_FILE%
echo #define CONFIG_MAX_ANTE %MAX_ANTE% >> %OUTPUT_FILE%
echo #define CONFIG_MIN_ANTE %MIN_ANTE% >> %OUTPUT_FILE%
echo #define CONFIG_DECK %DECK% >> %OUTPUT_FILE%
echo #define CONFIG_STAKE %STAKE% >> %OUTPUT_FILE%
echo. >> %OUTPUT_FILE%

REM Count the number of items and generate array
echo // Count the items first to define CONFIG_ITEMS >> %OUTPUT_FILE%
echo // Lines with item,score,flags,source,pack >> %OUTPUT_FILE%

set ITEM_COUNT=0
set ITEMS_SECTION=0

REM First pass - count items
for /f "usebackq tokens=*" %%a in ("%~1") do (
    set LINE=%%a
    
    REM Check for items section
    if "!LINE!"=="[ITEMS]" (
        set ITEMS_SECTION=1
    ) else if !ITEMS_SECTION!==1 (
        REM Skip comments and empty lines
        if not "!LINE:~0,1!"=="#" if not "!LINE!"=="" (
            REM Count lines with comma-separated values (at least 4 values)
            set COMMA_COUNT=0
            set CHECK_LINE=!LINE!
            
            :count_commas
            if "!CHECK_LINE!"=="" goto done_counting
            if "!CHECK_LINE:~0,1!"=="," (
                set /a COMMA_COUNT+=1
            )
            set CHECK_LINE=!CHECK_LINE:~1!
            goto count_commas
            
            :done_counting
            if !COMMA_COUNT! GEQ 3 (
                set /a ITEM_COUNT+=1
            )
        )
    )
)

echo #define CONFIG_ITEMS %ITEM_COUNT% >> %OUTPUT_FILE%
echo. >> %OUTPUT_FILE%

echo // Target items configuration >> %OUTPUT_FILE%
echo target_item CONFIG_TARGET_ITEMS[CONFIG_ITEMS] = { >> %OUTPUT_FILE%

REM Second pass - extract items
set ITEMS_SECTION=0
set CURRENT_ITEM=0

for /f "usebackq tokens=*" %%a in ("%~1") do (
    set LINE=%%a
    
    REM Check for items section
    if "!LINE!"=="[ITEMS]" (
        set ITEMS_SECTION=1
    ) else if !ITEMS_SECTION!==1 (
        REM Skip comments and empty lines
        if not "!LINE:~0,1!"=="#" if not "!LINE!"=="" (
            REM Process lines with comma-separated values (at least 4 values)
            set COMMA_COUNT=0
            set CHECK_LINE=!LINE!
            
            :check_commas
            if "!CHECK_LINE!"=="" goto done_check
            if "!CHECK_LINE:~0,1!"=="," (
                set /a COMMA_COUNT+=1
            )
            set CHECK_LINE=!CHECK_LINE:~1!
            goto check_commas
            
            :done_check
            if !COMMA_COUNT! GEQ 3 (
                REM Parse the line - format: item_name,score,flags,source,pack_type
                for /f "tokens=1-5 delims=," %%i in ("!LINE!") do (
                    set ITEM=%%i
                    set SCORE=%%j
                    set FLAGS=%%k
                    set SOURCE=%%l
                    set PACK=%%m
                    
                    if "!PACK!"=="" set PACK=0
                    
                    REM Increment counter and add to array
                    set /a CURRENT_ITEM+=1
                    
                    REM Add comma for all but the last item
                    if !CURRENT_ITEM! LSS !ITEM_COUNT! (
                        echo     {!ITEM!, !SCORE!, !FLAGS!, !SOURCE!, !PACK!}, // Item !CURRENT_ITEM! >> %OUTPUT_FILE%
                    ) else (
                        echo     {!ITEM!, !SCORE!, !FLAGS!, !SOURCE!, !PACK!} // Item !CURRENT_ITEM! >> %OUTPUT_FILE%
                    )
                )
            )
        )
    )
)

echo }; >> %OUTPUT_FILE%
echo. >> %OUTPUT_FILE%

REM Include the configurable search code
echo #include "configurable_search.cl" >> %OUTPUT_FILE%

echo Configuration file generated: %OUTPUT_FILE%
echo Found %ITEM_COUNT% items configured for search.
echo.
echo Run Immolate with: immolate -f runtime_config

endlocal