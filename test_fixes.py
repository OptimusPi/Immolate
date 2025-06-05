#!/usr/bin/env python3
"""
Test script to verify the search size dropdown and table column fixes
"""

import sys
sys.path.append('.')

from ouija_mvc.models.search_model import SearchModel

def test_seed_count_mapping():
    """Test that search size dropdown values map correctly to -n parameters"""
    search_model = SearchModel()
    
    print("Testing SEED_COUNT_MAP:")
    test_cases = [
        ("All", None),
        ("1 Single Seed", "1"),
        ("1K", "1000"),
        ("100K", "100000"),
        ("1M", "1000000"),
        ("100M", "100000000"),
        ("1B", "1000000000"),
        ("10B", "10000000000"),
        ("100B", "100000000000"),
    ]
    
    for dropdown_value, expected_param in test_cases:
        actual_param = search_model.SEED_COUNT_MAP.get(dropdown_value)
        status = "✅ PASS" if actual_param == expected_param else "❌ FAIL"
        print(f"  {dropdown_value:15} -> {actual_param:12} (expected: {expected_param:12}) {status}")

def test_command_building():
    """Test that commands are built correctly with -n parameter"""
    search_model = SearchModel()
    
    print("\nTesting command building:")
    test_cases = [
        ("All", None),
        ("1 Single Seed", ["-n", "1"]),
        ("1K", ["-n", "1000"]),
        ("100K", ["-n", "100000"]),
    ]
    
    for dropdown_value, expected_n_param in test_cases:
        command = search_model.build_command(
            config_path="test.json",
            starting_seed="ABCDEF",
            thread_groups="32",
            number_of_seeds=dropdown_value,
            template="ouija_template"
        )
        
        has_n_param = "-n" in command
        expected_has_n = expected_n_param is not None
        
        if expected_has_n:
            expected_value = expected_n_param[1]
            has_correct_value = f"-n {expected_value}" in command
            status = "✅ PASS" if has_n_param and has_correct_value else "❌ FAIL"
            print(f"  {dropdown_value:15} -> {'-n ' + expected_value if expected_has_n else 'no -n':15} {status}")
        else:
            status = "✅ PASS" if not has_n_param else "❌ FAIL"
            print(f"  {dropdown_value:15} -> {'no -n':15} {status}")
        
        if status == "❌ FAIL":
            print(f"    Command: {command}")

if __name__ == "__main__":
    test_seed_count_mapping()
    test_command_building()
    print("\nTest completed!")
