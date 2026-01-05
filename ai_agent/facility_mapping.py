from difflib import get_close_matches

# Location codes with multiple aliases for each library
LOCATION_MAP = {
    # Main Library (code: 3)
    "main library": "3",
    "main": "3",
    "ml": "3",
    "main lib": "3",
    
    # Chi Wah Learning Commons (code: 5)
    "chi wah learning commons": "5",
    "chi wah": "5",
    "chiwah": "5",
    "chi-wah": "5",
    "cw": "5",
    "cwlc": "5",
    "chi wah commons": "5",
    
    # Law Library (code: 6)
    "law library": "6",
    "law": "6",
    "ll": "6",
    "law lib": "6",
    
    # Medical Library (code: 8)
    "medical library": "8",
    "medical": "8",
    "med": "8",
    "med library": "8",
    "med lib": "8",
    
    # Music Library (code: 4)
    "music library": "4",
    "music": "4",
    "music lib": "4",
}

# Room type codes for each location
# Structure: {location_code: {type_name: type_code}}
TYPE_MAP = {
    "3": {  # Main Library
        "discussion room": "21",
        "discussion": "21",
        "computer": "33",
        "computer in ltc": "33",
        "studio": "34",
        "studio and editing room": "34",
        "editing room": "34",
        "concept and creation room": "35",
        "concept room": "35",
        "creation room": "35",
        "single study room": "31",
        "study table": "23",
    },
    "5": {  # Chi Wah Learning Commons
        "study room": "29",
    },
    "6": {  # Law Library
        "study room": "23",
        "discussion room": "21",
        "discussion": "21",
    },
    "8": {  # Medical Library
        "discussion room": "21",
        "discussion": "21",
    },
    "4": {  # Music Library
        "discussion room": "21",
        "discussion": "21",
    }
}

# Room number ranges for each facility type
# Structure: {location_code: {type_code: [room_ranges]}}
ROOM_RANGES = {
    "3": {  # Main Library
        "21": ["126-133", "135-144"],  # Discussion Room
        "33": ["533-541", "542-548"],  # Computer in LTC
        "34": ["537"],  # Studio and Editing Room
        "31": ["398-404"],  # Single Study Room
        "23": ["334-397"],  # Study Table
    },
    "5": {  # Chi Wah Learning Commons
        "29": ["258-266", "268-271", "274-275"],  # Study room
    },
    "6": {  # Law Library
        "23": ["411-499"],  # Study room
        "21": ["281-286"],  # Discussion Room
    },
    "8": {  # Medical Library
        "21": ["501-506"],  # Discussion Room
    },
    "4": {  # Music Library
        "21": ["313-315"],  # Discussion Room
    }
}

# Reverse mapping for display purposes
# Maps code back to canonical name
LOCATION_NAMES = {
    "3": "Main Library",
    "5": "Chi Wah Learning Commons",
    "6": "Law Library",
    "8": "Medical Library",
    "4": "Music Library"
}

# Type names for each location (canonical names)
TYPE_NAMES = {
    "3": {
        "21": "Discussion Room (3F)",
        "33": "Computer in LTC (2F)",
        "34": "Studio and Editing Room (2F)",
        "35": "Concept and Creation Room (2F)",
        "31": "Single Study Room (4F)",
        "23": "Study Table (4F)",
    },
    "5": {
        "29": "Study Room",
    },
    "6": {
        "23": "Study Room",
        "21": "Discussion Room",
    },
    "8": {
        "21": "Discussion Room",
    },
    "4": {
        "21": "Discussion Room",
    }
}


def get_location_code(name: str) -> tuple[str | None, str]:
    """
    Get location code from name with fuzzy matching.
    
    Args:
        name: Location name from user (e.g., "Chi Wah", "main library")
    
    Returns:
        Tuple of (code, message):
        - code: Location code if found, None otherwise
        - message: Explanation of the match or error
    """
    
    name_lower = name.lower().strip()
    
    # 1. Exact match
    if name_lower in LOCATION_MAP:
        code = LOCATION_MAP[name_lower]
        return code, f"Matched '{name}' → {LOCATION_NAMES[code]}"
    
    # 2. Partial match (contains)
    for key, code in LOCATION_MAP.items():
        if key in name_lower or name_lower in key:
            return code, f"Matched '{name}' to '{key}' → {LOCATION_NAMES[code]}"
    
    # 3. Similarity match using difflib
    matches = get_close_matches(name_lower, LOCATION_MAP.keys(), n=1, cutoff=0.6)
    if matches:
        matched_key = matches[0]
        code = LOCATION_MAP[matched_key]
        return code, f"Best match for '{name}': '{matched_key}' → {LOCATION_NAMES[code]}"
    
    # 4. No match found
    available = "\n  - ".join([LOCATION_NAMES[code] for code in sorted(set(LOCATION_MAP.values()))])
    error_msg = f"Cannot recognize '{name}'.\n\nAvailable libraries:\n  - {available}\n\nPlease specify which library you meant."
    return None, error_msg


def get_room_type_code(location_code: str, type_name: str) -> tuple[str | None, str]:
    """
    Get room type code for a specific location with fuzzy matching.
    
    Args:
        location_code: Location code (e.g., "5")
        type_name: Room type name (e.g., "study room")
    
    Returns:
        Tuple of (code, message):
        - code: Type code if found, None otherwise
        - message: Explanation of the match or error
    """
    
    if location_code not in TYPE_MAP:
        return None, f"Invalid location code: {location_code}"
    
    type_name_lower = type_name.lower().strip()
    location_types = TYPE_MAP[location_code]
    
    # 1. Exact match
    if type_name_lower in location_types:
        code = location_types[type_name_lower]
        type_full_name = TYPE_NAMES[location_code][code]
        return code, f"Matched '{type_name}' → {type_full_name}"
    
    # 2. Partial match (contains)
    for key, code in location_types.items():
        if key in type_name_lower or type_name_lower in key:
            type_full_name = TYPE_NAMES[location_code][code]
            return code, f"Matched '{type_name}' to '{key}' → {type_full_name}"
    
    # 3. Similarity match
    matches = get_close_matches(type_name_lower, location_types.keys(), n=1, cutoff=0.6)
    if matches:
        matched_key = matches[0]
        code = location_types[matched_key]
        type_full_name = TYPE_NAMES[location_code][code]
        return code, f"Best match for '{type_name}': '{matched_key}' → {type_full_name}"
    
    # 4. No match found
    available = "\n  - ".join(location_types.keys())
    location_name = LOCATION_NAMES.get(location_code, f"location {location_code}")
    error_msg = f"Cannot recognize room type '{type_name}' at {location_name}.\n\nAvailable types:\n  - {available}\n\nPlease specify which room type you meant."
    return None, error_msg


def get_room_range_suggestions(location_code: str, type_code: str) -> str:
    """
    Get suggested room number ranges for a facility type.
    Args:
        location_code: Location code
        type_code: Room type code
    Returns:
        Formatted string with room range suggestions
    """
    if location_code not in ROOM_RANGES:
        return ""
    
    if type_code not in ROOM_RANGES[location_code]:
        return ""
    
    ranges = ROOM_RANGES[location_code][type_code]
    return f"Available room ranges: {', '.join(ranges)}"
