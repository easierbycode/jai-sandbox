// ============================================================================
// LEVEL LOADING & MANAGEMENT
// ============================================================================
// Loads levels from JSON files with the following structure:
// - Tile grid (collision)
// - Hazards (spikes, saws, etc.)
// - Spawn point
// - Goal/exit
// ============================================================================

TILE_SIZE :: 16.0;

// Tile types
Tile_Type :: enum u8 {
    EMPTY    :: 0;
    SOLID    :: 1;
    PLATFORM :: 2;  // One-way platform
}

Rect :: struct {
    x, y: float;
    width, height: float;
}

Level :: struct {
    // Dimensions
    width: int;   // In tiles
    height: int;
    
    // Tile data
    tiles: [] Tile_Type;
    
    // Hazards
    hazards: [..] Rect;
    
    // Spawn point
    spawn_x, spawn_y: float;
    
    // Goal
    goal_rect: Rect;
    
    // Visual data
    background_color: Vector4;
    tileset_name: string;
    
    // Metadata
    name: string;
    par_time: float;  // Target time to beat
}

// ============================================================================
// JSON LEVEL LOADING
// ============================================================================

load_level :: (game: *Game_State, filepath: string) -> bool {
    log("Loading level: %", filepath);
    
    // Read file
    file_data, success := read_entire_file(filepath);
    if !success {
        log("ERROR: Could not read file: %", filepath);
        return false;
    }
    defer free(file_data.data);
    
    // Parse JSON
    json, parse_success := json_parse_string(file_data);
    if !parse_success {
        log("ERROR: Failed to parse JSON");
        return false;
    }
    defer json_free(json);
    
    // Clear previous level
    clear_level(*game.level);
    
    // Parse level data
    level := *game.level;
    
    // Metadata
    level.name = json_get_string(json, "name", "Unnamed Level");
    level.par_time = cast(float) json_get_number(json, "par_time", 30.0);
    
    // Dimensions
    level.width = cast(int) json_get_number(json, "width", 40);
    level.height = cast(int) json_get_number(json, "height", 23);
    
    // Allocate tiles
    tile_count := level.width * level.height;
    level.tiles = NewArray(tile_count, Tile_Type);
    
    // Parse tile grid
    tiles_array := json_get_array(json, "tiles");
    if tiles_array {
        for row, y: tiles_array.* {
            row_array := json_as_array(row);
            if row_array {
                for tile_val, x: row_array.* {
                    if x < level.width && y < level.height {
                        index := y * level.width + x;
                        level.tiles[index] = cast(Tile_Type) cast(u8) json_as_number(tile_val);
                    }
                }
            }
        }
    }
    
    // Parse spawn point
    spawn_obj := json_get_object(json, "spawn");
    if spawn_obj {
        level.spawn_x = cast(float) json_get_number(spawn_obj, "x", 2.0) * TILE_SIZE + TILE_SIZE/2;
        level.spawn_y = cast(float) json_get_number(spawn_obj, "y", 2.0) * TILE_SIZE + TILE_SIZE/2;
    } else {
        level.spawn_x = 2 * TILE_SIZE + TILE_SIZE/2;
        level.spawn_y = 2 * TILE_SIZE + TILE_SIZE/2;
    }
    
    // Parse goal
    goal_obj := json_get_object(json, "goal");
    if goal_obj {
        level.goal_rect.x = cast(float) json_get_number(goal_obj, "x", 38.0) * TILE_SIZE;
        level.goal_rect.y = cast(float) json_get_number(goal_obj, "y", 20.0) * TILE_SIZE;
        level.goal_rect.width = cast(float) json_get_number(goal_obj, "width", 2.0) * TILE_SIZE;
        level.goal_rect.height = cast(float) json_get_number(goal_obj, "height", 2.0) * TILE_SIZE;
    }
    
    // Parse hazards
    hazards_array := json_get_array(json, "hazards");
    if hazards_array {
        for hazard_val: hazards_array.* {
            hazard_obj := json_as_object(hazard_val);
            if hazard_obj {
                hazard: Rect;
                hazard.x = cast(float) json_get_number(hazard_obj, "x", 0.0) * TILE_SIZE;
                hazard.y = cast(float) json_get_number(hazard_obj, "y", 0.0) * TILE_SIZE;
                hazard.width = cast(float) json_get_number(hazard_obj, "width", 1.0) * TILE_SIZE;
                hazard.height = cast(float) json_get_number(hazard_obj, "height", 1.0) * TILE_SIZE;
                array_add(*level.hazards, hazard);
            }
        }
    }
    
    // Background color
    bg_array := json_get_array(json, "background_color");
    if bg_array && bg_array.count >= 3 {
        level.background_color.x = cast(float) json_as_number(bg_array.*[0]) / 255.0;
        level.background_color.y = cast(float) json_as_number(bg_array.*[1]) / 255.0;
        level.background_color.z = cast(float) json_as_number(bg_array.*[2]) / 255.0;
        level.background_color.w = 1.0;
    } else {
        level.background_color = .{0.1, 0.1, 0.15, 1.0};  // Dark blue default
    }
    
    log("Level loaded: % (% x %)", level.name, level.width, level.height);
    log("  Spawn: (%, %)", level.spawn_x, level.spawn_y);
    log("  Hazards: %", level.hazards.count);
    
    return true;
}

clear_level :: (level: *Level) {
    if level.tiles.data {
        free(level.tiles.data);
        level.tiles = .[];
    }
    array_reset(*level.hazards);
}

// ============================================================================
// LEVEL QUERIES
// ============================================================================

is_solid_tile :: (level: *Level, x: int, y: int) -> bool {
    if x < 0 || x >= level.width return true;   // Out of bounds = solid (walls)
    if y < 0 return true;                        // Ceiling
    if y >= level.height return false;           // No floor below level
    
    index := y * level.width + x;
    return level.tiles[index] == .SOLID;
}

get_tile :: (level: *Level, x: int, y: int) -> Tile_Type {
    if x < 0 || x >= level.width return .SOLID;
    if y < 0 || y >= level.height return .EMPTY;
    
    index := y * level.width + x;
    return level.tiles[index];
}

// ============================================================================
// DEFAULT LEVEL (Fallback if JSON fails)
// ============================================================================

create_default_level :: (game: *Game_State) {
    level := *game.level;
    clear_level(level);
    
    level.name = "Default Level";
    level.width = 40;
    level.height = 23;
    level.par_time = 15.0;
    
    // Allocate tiles
    tile_count := level.width * level.height;
    level.tiles = NewArray(tile_count, Tile_Type);
    
    // Fill with empty
    for i: 0..tile_count-1 {
        level.tiles[i] = .EMPTY;
    }
    
    // Create floor
    for x: 0..level.width-1 {
        set_tile(level, x, level.height - 1, .SOLID);
        set_tile(level, x, level.height - 2, .SOLID);
    }
    
    // Create walls
    for y: 0..level.height-1 {
        set_tile(level, 0, y, .SOLID);
        set_tile(level, level.width - 1, y, .SOLID);
    }
    
    // Some platforms
    for x: 5..10 {
        set_tile(level, x, 18, .SOLID);
    }
    for x: 15..20 {
        set_tile(level, x, 15, .SOLID);
    }
    for x: 25..30 {
        set_tile(level, x, 12, .SOLID);
    }
    
    // Wall for wall jumping
    for y: 5..17 {
        set_tile(level, 33, y, .SOLID);
    }
    
    // Spawn
    level.spawn_x = 3 * TILE_SIZE + TILE_SIZE/2;
    level.spawn_y = 20 * TILE_SIZE + TILE_SIZE/2;
    
    // Goal
    level.goal_rect = .{
        x = 36 * TILE_SIZE,
        y = 4 * TILE_SIZE,
        width = 2 * TILE_SIZE,
        height = 2 * TILE_SIZE
    };
    
    // Hazards (spikes along bottom of some areas)
    array_add(*level.hazards, Rect.{
        x = 12 * TILE_SIZE,
        y = 20 * TILE_SIZE,
        width = 3 * TILE_SIZE,
        height = 1 * TILE_SIZE
    });
    
    level.background_color = .{0.1, 0.1, 0.15, 1.0};
    
    log("Created default level");
}

set_tile :: (level: *Level, x: int, y: int, tile: Tile_Type) {
    if x < 0 || x >= level.width return;
    if y < 0 || y >= level.height return;
    
    index := y * level.width + x;
    level.tiles[index] = tile;
}

// ============================================================================
// JSON HELPER WRAPPERS
// ============================================================================
// These wrap the standard JSON module for easier access

json_get_string :: (obj: *JSON_Value, key: string, default: string = "") -> string {
    val := json_get(obj, key);
    if val && val.type == .STRING {
        return val.str;
    }
    return default;
}

json_get_number :: (obj: *JSON_Value, key: string, default: float64 = 0.0) -> float64 {
    val := json_get(obj, key);
    if val && val.type == .NUMBER {
        return val.number;
    }
    return default;
}

json_get_array :: (obj: *JSON_Value, key: string) -> *[..] *JSON_Value {
    val := json_get(obj, key);
    if val && val.type == .ARRAY {
        return *val.array;
    }
    return null;
}

json_get_object :: (obj: *JSON_Value, key: string) -> *JSON_Value {
    val := json_get(obj, key);
    if val && val.type == .OBJECT {
        return val;
    }
    return null;
}

json_as_number :: (val: *JSON_Value) -> float64 {
    if val && val.type == .NUMBER {
        return val.number;
    }
    return 0.0;
}

json_as_array :: (val: *JSON_Value) -> *[..] *JSON_Value {
    if val && val.type == .ARRAY {
        return *val.array;
    }
    return null;
}

json_as_object :: (val: *JSON_Value) -> *JSON_Value {
    if val && val.type == .OBJECT {
        return val;
    }
    return null;
}
