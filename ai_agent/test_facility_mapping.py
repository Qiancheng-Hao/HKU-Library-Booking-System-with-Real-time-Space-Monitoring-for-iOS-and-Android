"""
Test script for facility mapping with fuzzy matching.
Tests the conversion from natural language to location/type codes.
"""

from facility_mapping import (
    get_location_code,
    get_room_type_code,
    get_room_range_suggestions,
    LOCATION_NAMES,
    TYPE_NAMES
)


def test_location_conversion():
    """Test location name to code conversion with various inputs"""
    print("=" * 60)
    print("TEST 1: Location Name to Code Conversion")
    print("=" * 60)
    
    test_cases = [
        # Exact matches
        "Chi Wah Learning Commons",
        "Main Library",
        "Law Library",
        
        # Short forms
        "Chi Wah",
        "ChiWah",
        "CW",
        "CWLC",
        
        # Case variations
        "chi wah",
        "CHI WAH",
        "main library",
        
        # Partial matches
        "Law",
        "Medical",
        "Music",
        
        # Typos and fuzzy matches
        "ChiWa",
        "Chiwah Learning",
        "Main Lib",
        
        # Invalid
        "Invalid Location",
        "XYZ"
    ]
    
    for location_input in test_cases:
        code, message = get_location_code(location_input)
        status = "true" if code else "false"
        print(f"{status} Input: '{location_input}'")
        print(f"   Result: {message}")
        if code:
            print(f"   Code: {code}")
        print()


def test_room_type_conversion():
    """Test room type name to code conversion for different locations"""
    print("=" * 60)
    print("TEST 2: Room Type Name to Code Conversion")
    print("=" * 60)
    
    # Test for Chi Wah (location code 5)
    print("\n--- Chi Wah Learning Commons (Code: 5) ---")
    test_cases_cw = [
        "Study Room",
        "study room",
        "STUDY ROOM",
        "StudyRoom",
        "study",
        "Invalid Room Type"
    ]
    
    for room_type in test_cases_cw:
        code, message = get_room_type_code("5", room_type)
        status = "true" if code else "false"
        print(f"{status} Input: '{room_type}'")
        print(f"   Result: {message}")
        if code:
            print(f"   Code: {code}")
            range_info = get_room_range_suggestions("5", code)
            print(f"   {range_info}")
        print()
    
    # Test for Main Library (location code 3)
    print("\n--- Main Library (Code: 3) ---")
    test_cases_main = [
        "Discussion Room",
        "Single Study Room",
        "Computer in LTC",
        "discussion",
        "studio",
        "Invalid Room Type"
    ]
    
    for room_type in test_cases_main:
        code, message = get_room_type_code("3", room_type)
        status = "true" if code else "false"
        print(f"{status} Input: '{room_type}'")
        print(f"   Result: {message}")
        if code:
            print(f"   Code: {code}")
            range_info = get_room_range_suggestions("3", code)
            print(f"   {range_info}")
        print()


def test_full_workflow():
    """Test a complete booking workflow with natural language"""
    print("=" * 60)
    print("TEST 3: Complete Workflow Simulation")
    print("=" * 60)
    
    scenarios = [
        {
            "description": "User says: 'I want to book Chi Wah study room'",
            "location": "Chi Wah",
            "room_type": "study room"
        },
        {
            "description": "User says: 'Book a discussion room at Main Library'",
            "location": "Main Library",
            "room_type": "discussion room"
        },
        {
            "description": "User says: 'CW study room please'",
            "location": "CW",
            "room_type": "study"
        },
        {
            "description": "User says: 'Law library discussion room'",
            "location": "Law",
            "room_type": "discussion"
        }
    ]
    
    for scenario in scenarios:
        print(f"\n{scenario['description']}")
        print("-" * 60)
        
        # Step 1: Convert location
        location_code, location_msg = get_location_code(scenario['location'])
        print(f"Step 1 - Convert location '{scenario['location']}':")
        print(f"  {location_msg}")
        
        if location_code:
            # Step 2: Convert room type
            type_code, type_msg = get_room_type_code(location_code, scenario['room_type'])
            print(f"\nStep 2 - Convert room type '{scenario['room_type']}':")
            print(f"  {type_msg}")
            
            if type_code:
                # Step 3: Get room range
                range_info = get_room_range_suggestions(location_code, type_code)
                print(f"\nStep 3 - Room range suggestions:")
                print(f"  {range_info}")
                
                print(f"\n SUCCESS: location={location_code}, type={type_code}")
            else:
                print("\n FAILED: Could not convert room type")
        else:
            print("\n FAILED: Could not convert location")
        
        print()


def test_edge_cases():
    """Test edge cases and error handling"""
    print("=" * 60)
    print("TEST 4: Edge Cases and Error Handling")
    print("=" * 60)
    
    # Test room type without location
    print("\n--- Test: Room type conversion without location ---")
    code, msg = get_room_type_code(None, "study room")
    print(f"Result: {msg}")
    print()
    
    # Test invalid location code
    print("\n--- Test: Room type with invalid location code ---")
    code, msg = get_room_type_code("999", "study room")
    print(f"Result: {msg}")
    print()
    
    # Test empty strings
    print("\n--- Test: Empty location name ---")
    code, msg = get_location_code("")
    print(f"Result: {msg}")
    print()
    
    # Test room range for invalid type
    print("\n--- Test: Room range for invalid type ---")
    range_info = get_room_range_suggestions("5", "999")
    print(f"Result: {range_info}")
    print()


def main():
    """Run all tests"""
    print("\n" + "=" * 60)
    print("FACILITY MAPPING FUZZY MATCHING TEST SUITE")
    print("=" * 60 + "\n")
    
    test_location_conversion()
    test_room_type_conversion()
    test_full_workflow()
    test_edge_cases()
    
    print("\n" + "=" * 60)
    print("ALL TESTS COMPLETED")
    print("=" * 60 + "\n")


if __name__ == "__main__":
    main()
