// ============================================================================
// PHYSICS UTILITIES
// ============================================================================
// Collision detection and physics helpers
// ============================================================================

Vector2 :: struct {
    x, y: float;
}

Vector3 :: struct {
    x, y, z: float;
}

Vector4 :: struct {
    x, y, z, w: float;
}

Matrix4 :: struct {
    m: [4][4] float;
}

Matrix4_Identity :: Matrix4.{
    m = .[
        .[1, 0, 0, 0],
        .[0, 1, 0, 0],
        .[0, 0, 1, 0],
        .[0, 0, 0, 1]
    ]
};

// ============================================================================
// AABB COLLISION
// ============================================================================

AABB :: struct {
    min_x, min_y: float;
    max_x, max_y: float;
}

aabb_from_rect :: (r: Rect) -> AABB {
    return .{
        min_x = r.x,
        min_y = r.y,
        max_x = r.x + r.width,
        max_y = r.y + r.height
    };
}

aabb_overlap :: (a: AABB, b: AABB) -> bool {
    return a.min_x < b.max_x &&
           a.max_x > b.min_x &&
           a.min_y < b.max_y &&
           a.max_y > b.min_y;
}

aabb_contains_point :: (aabb: AABB, x: float, y: float) -> bool {
    return x >= aabb.min_x && x <= aabb.max_x &&
           y >= aabb.min_y && y <= aabb.max_y;
}

// ============================================================================
// SWEEP COLLISION
// ============================================================================
// Used for continuous collision detection (tunneling prevention)

Sweep_Result :: struct {
    hit: bool;
    time: float;      // 0-1, when collision occurred
    normal_x: float;  // Surface normal at collision
    normal_y: float;
    touch_x: float;   // Contact point
    touch_y: float;
}

// Sweep an AABB against a static AABB
sweep_aabb :: (
    moving: AABB,
    vx: float, vy: float,
    static_box: AABB
) -> Sweep_Result {
    
    result: Sweep_Result;
    result.time = 1.0;  // No collision = full movement
    
    // Early out if not moving
    if vx == 0 && vy == 0 {
        return result;
    }
    
    // Expand static box by moving box dimensions (Minkowski sum)
    expanded := AABB.{
        min_x = static_box.min_x - (moving.max_x - moving.min_x) / 2,
        min_y = static_box.min_y - (moving.max_y - moving.min_y) / 2,
        max_x = static_box.max_x + (moving.max_x - moving.min_x) / 2,
        max_y = static_box.max_y + (moving.max_y - moving.min_y) / 2
    };
    
    // Ray from center of moving box
    center_x := (moving.min_x + moving.max_x) / 2;
    center_y := (moving.min_y + moving.max_y) / 2;
    
    // Calculate entry and exit times for each axis
    INF :: 1e10;
    
    entry_x, exit_x: float;
    entry_y, exit_y: float;
    
    if vx == 0 {
        if center_x >= expanded.min_x && center_x <= expanded.max_x {
            entry_x = -INF;
            exit_x = INF;
        } else {
            // No intersection possible
            return result;
        }
    } else {
        entry_x = (ifx vx > 0 then expanded.min_x else expanded.max_x - center_x) / vx;
        exit_x = (ifx vx > 0 then expanded.max_x else expanded.min_x - center_x) / vx;
    }
    
    if vy == 0 {
        if center_y >= expanded.min_y && center_y <= expanded.max_y {
            entry_y = -INF;
            exit_y = INF;
        } else {
            return result;
        }
    } else {
        entry_y = (ifx vy > 0 then expanded.min_y else expanded.max_y - center_y) / vy;
        exit_y = (ifx vy > 0 then expanded.max_y else expanded.min_y - center_y) / vy;
    }
    
    // Ensure entry < exit
    if entry_x > exit_x { swap(*entry_x, *exit_x); }
    if entry_y > exit_y { swap(*entry_y, *exit_y); }
    
    // Find latest entry and earliest exit
    entry_time := max(entry_x, entry_y);
    exit_time := min(exit_x, exit_y);
    
    // Check for valid intersection
    if entry_time > exit_time || entry_time < 0 || entry_time > 1 {
        return result;
    }
    
    // We have a collision
    result.hit = true;
    result.time = entry_time;
    
    // Determine collision normal
    if entry_x > entry_y {
        result.normal_x = ifx vx > 0 then -1 else 1;
        result.normal_y = 0;
    } else {
        result.normal_x = 0;
        result.normal_y = ifx vy > 0 then -1 else 1;
    }
    
    // Calculate touch point
    result.touch_x = center_x + vx * entry_time;
    result.touch_y = center_y + vy * entry_time;
    
    return result;
}

// ============================================================================
// RAY CASTING
// ============================================================================

Ray :: struct {
    origin_x, origin_y: float;
    dir_x, dir_y: float;
}

Raycast_Result :: struct {
    hit: bool;
    distance: float;
    hit_x, hit_y: float;
    normal_x, normal_y: float;
    tile_x, tile_y: int;
}

// Cast ray through tile grid
raycast_tiles :: (level: *Level, ray: Ray, max_distance: float) -> Raycast_Result {
    result: Raycast_Result;
    
    // DDA algorithm for tile grid raycasting
    
    // Current tile
    tile_x := cast(int) floor(ray.origin_x / TILE_SIZE);
    tile_y := cast(int) floor(ray.origin_y / TILE_SIZE);
    
    // Step direction
    step_x := ifx ray.dir_x >= 0 then 1 else -1;
    step_y := ifx ray.dir_y >= 0 then 1 else -1;
    
    // Distance to next tile boundary
    t_max_x: float;
    t_max_y: float;
    
    if ray.dir_x == 0 {
        t_max_x = 1e10;
    } else {
        next_x := (cast(float)(tile_x + (ifx step_x > 0 then 1 else 0))) * TILE_SIZE;
        t_max_x = (next_x - ray.origin_x) / ray.dir_x;
    }
    
    if ray.dir_y == 0 {
        t_max_y = 1e10;
    } else {
        next_y := (cast(float)(tile_y + (ifx step_y > 0 then 1 else 0))) * TILE_SIZE;
        t_max_y = (next_y - ray.origin_y) / ray.dir_y;
    }
    
    // Distance between tile boundaries
    t_delta_x := ifx ray.dir_x == 0 then 1e10 else abs(TILE_SIZE / ray.dir_x);
    t_delta_y := ifx ray.dir_y == 0 then 1e10 else abs(TILE_SIZE / ray.dir_y);
    
    // March through grid
    distance := 0.0;
    while distance < max_distance {
        // Check current tile
        if is_solid_tile(level, tile_x, tile_y) {
            result.hit = true;
            result.distance = distance;
            result.tile_x = tile_x;
            result.tile_y = tile_y;
            result.hit_x = ray.origin_x + ray.dir_x * distance;
            result.hit_y = ray.origin_y + ray.dir_y * distance;
            return result;
        }
        
        // Step to next tile
        if t_max_x < t_max_y {
            distance = t_max_x;
            t_max_x += t_delta_x;
            tile_x += step_x;
            result.normal_x = cast(float) -step_x;
            result.normal_y = 0;
        } else {
            distance = t_max_y;
            t_max_y += t_delta_y;
            tile_y += step_y;
            result.normal_x = 0;
            result.normal_y = cast(float) -step_y;
        }
    }
    
    return result;
}

// ============================================================================
// MATH HELPERS
// ============================================================================

clamp :: (value: $T, min_val: T, max_val: T) -> T {
    if value < min_val return min_val;
    if value > max_val return max_val;
    return value;
}

min :: (a: $T, b: T) -> T {
    return ifx a < b then a else b;
}

max :: (a: $T, b: T) -> T {
    return ifx a > b then a else b;
}

swap :: (a: *$T, b: *T) {
    temp := a.*;
    a.* = b.*;
    b.* = temp;
}

sign :: (x: float) -> float {
    if x > 0 return 1;
    if x < 0 return -1;
    return 0;
}

floor :: (x: float) -> float {
    i := cast(int) x;
    return cast(float) (ifx x < 0 && cast(float) i != x then i - 1 else i);
}

sqrt :: (x: float) -> float #intrinsic;
sin :: (x: float) -> float #intrinsic;
cos :: (x: float) -> float #intrinsic;

PI :: 3.14159265358979323846;

// ============================================================================
// VECTOR OPERATIONS
// ============================================================================

vec2_length :: (x: float, y: float) -> float {
    return sqrt(x*x + y*y);
}

vec2_normalize :: (x: *float, y: *float) {
    len := vec2_length(x.*, y.*);
    if len > 0 {
        x.* /= len;
        y.* /= len;
    }
}

vec2_dot :: (x1: float, y1: float, x2: float, y2: float) -> float {
    return x1*x2 + y1*y2;
}

// Matrix multiplication
operator * :: (a: Matrix4, b: Matrix4) -> Matrix4 {
    result: Matrix4;
    for i: 0..3 {
        for j: 0..3 {
            sum := 0.0;
            for k: 0..3 {
                sum += a.m[i][k] * b.m[k][j];
            }
            result.m[i][j] = sum;
        }
    }
    return result;
}
