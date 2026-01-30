// ============================================================================
// PLAYER CONTROLLER - SUPER MEAT BOY STYLE
// ============================================================================
// Key characteristics:
// - Instant acceleration (no acceleration curves)
// - High air control
// - Wall sliding with reduced gravity
// - Wall jumping with horizontal boost
// - Variable jump height (release to cut jump short)
// - Coyote time (jump grace period after leaving platform)
// - Jump buffering (queue jump before landing)
// ============================================================================

PLAYER_WIDTH  :: 16.0;
PLAYER_HEIGHT :: 16.0;

Player :: struct {
    // Position
    x, y: float;
    width, height: float;
    
    // Velocity
    vx, vy: float;
    
    // State
    grounded: bool;
    wall_sliding: bool;
    wall_direction: int;  // -1 = left wall, 1 = right wall
    facing_right: bool;
    
    // Jump state
    jump_held: bool;
    can_variable_jump: bool;  // Can still cut jump short
    
    // Coyote time (allows jumping shortly after leaving ground)
    coyote_timer: float;
    COYOTE_TIME :: 0.08;
    
    // Jump buffer (queues jump input before landing)
    jump_buffer_timer: float;
    JUMP_BUFFER_TIME :: 0.1;
    
    // Wall jump cooldown (prevents immediately re-grabbing wall)
    wall_jump_cooldown: float;
    
    // Animation
    run_timer: float;
    squash_stretch: float = 1.0;
}

// ============================================================================
// MOVEMENT CONSTANTS - TUNED FOR TIGHT CONTROLS
// ============================================================================

MOVE_SPEED       :: 280.0;   // Horizontal speed
GRAVITY          :: 1200.0;  // Base gravity
FAST_FALL_MULT   :: 1.5;     // Gravity multiplier when falling
JUMP_FORCE       :: 420.0;   // Initial jump velocity
JUMP_CUT_MULT    :: 0.4;     // Velocity multiplier when releasing jump
MAX_FALL_SPEED   :: 600.0;   // Terminal velocity

// Wall mechanics
WALL_SLIDE_SPEED     :: 80.0;    // Max slide speed on wall
WALL_STICK_TIME      :: 0.1;     // Brief stick before sliding
WALL_JUMP_FORCE_X    :: 320.0;   // Horizontal wall jump boost
WALL_JUMP_FORCE_Y    :: 380.0;   // Vertical wall jump force
WALL_JUMP_COOLDOWN   :: 0.15;    // Time before can grab wall again

// Air control
AIR_CONTROL          :: 0.9;     // High air control (SMB style)
AIR_FRICTION         :: 0.0;     // No air friction

// ============================================================================
// PLAYER UPDATE
// ============================================================================

update_player :: (player: *Player, input: *Input_State, level: *Level, dt: float) {
    // Store previous state
    was_grounded := player.grounded;
    
    // Update timers
    update_timers(player, dt);
    
    // Horizontal movement
    handle_horizontal_movement(player, input, dt);
    
    // Wall detection
    handle_wall_detection(player, input, level);
    
    // Jumping
    handle_jumping(player, input);
    
    // Apply gravity
    apply_gravity(player, dt);
    
    // Apply velocity
    player.x += player.vx * dt;
    player.y += player.vy * dt;
    
    // Collision resolution
    resolve_collisions(player, level);
    
    // Landing effects
    if player.grounded && !was_grounded {
        on_land(player);
    }
    
    // Update facing direction
    if player.vx > 10 {
        player.facing_right = true;
    } else if player.vx < -10 {
        player.facing_right = false;
    }
    
    // Animation
    update_animation(player, dt);
}

// ============================================================================
// MOVEMENT
// ============================================================================

handle_horizontal_movement :: (player: *Player, input: *Input_State, dt: float) {
    target_vx := input.move_x * MOVE_SPEED;
    
    if player.grounded {
        // Instant acceleration on ground
        player.vx = target_vx;
    } else if !player.wall_sliding {
        // High air control
        if input.move_x != 0 {
            player.vx = lerp(player.vx, target_vx, AIR_CONTROL);
        }
        // Minimal air friction when not pressing direction
    }
}

handle_wall_detection :: (player: *Player, input: *Input_State, level: *Level) {
    player.wall_sliding = false;
    player.wall_direction = 0;
    
    // Can't wall slide during cooldown
    if player.wall_jump_cooldown > 0 return;
    
    // Must be airborne and moving toward wall
    if player.grounded return;
    if player.vy < 0 return;  // Only when falling
    
    // Check for walls
    left_wall := check_wall_collision(player, level, -1);
    right_wall := check_wall_collision(player, level, 1);
    
    // Wall slide if pressing toward wall
    if left_wall && input.move_x < -0.1 {
        player.wall_sliding = true;
        player.wall_direction = -1;
    } else if right_wall && input.move_x > 0.1 {
        player.wall_sliding = true;
        player.wall_direction = 1;
    }
}

// ============================================================================
// JUMPING
// ============================================================================

handle_jumping :: (player: *Player, input: *Input_State) {
    // Buffer jump input
    if input.jump_pressed {
        player.jump_buffer_timer = player.JUMP_BUFFER_TIME;
    }
    
    // Track if jump is held
    player.jump_held = input.jump_held;
    
    // Check if can jump
    can_ground_jump := player.grounded || player.coyote_timer > 0;
    can_wall_jump := player.wall_sliding;
    want_to_jump := player.jump_buffer_timer > 0;
    
    if want_to_jump {
        if can_wall_jump {
            // Wall jump!
            wall_jump(player);
            player.jump_buffer_timer = 0;
        } else if can_ground_jump {
            // Normal jump
            ground_jump(player);
            player.jump_buffer_timer = 0;
        }
    }
    
    // Variable jump height - cut jump short when releasing
    if !player.jump_held && player.can_variable_jump && player.vy < 0 {
        player.vy *= JUMP_CUT_MULT;
        player.can_variable_jump = false;
    }
}

ground_jump :: (player: *Player) {
    player.vy = -JUMP_FORCE;
    player.grounded = false;
    player.coyote_timer = 0;
    player.can_variable_jump = true;
    
    // Squash and stretch
    player.squash_stretch = 0.7;
}

wall_jump :: (player: *Player) {
    // Jump away from wall
    player.vx = -player.wall_direction * WALL_JUMP_FORCE_X;
    player.vy = -WALL_JUMP_FORCE_Y;
    
    player.wall_sliding = false;
    player.wall_jump_cooldown = WALL_JUMP_COOLDOWN;
    player.can_variable_jump = true;
    
    // Face away from wall
    player.facing_right = player.wall_direction < 0;
    
    // Squash and stretch
    player.squash_stretch = 0.7;
}

// ============================================================================
// GRAVITY
// ============================================================================

apply_gravity :: (player: *Player, dt: float) {
    gravity := GRAVITY;
    
    if player.wall_sliding {
        // Reduced gravity on wall
        if player.vy > WALL_SLIDE_SPEED {
            player.vy = WALL_SLIDE_SPEED;
        } else {
            player.vy += gravity * 0.3 * dt;
        }
    } else {
        // Normal gravity, faster when falling
        if player.vy > 0 {
            gravity *= FAST_FALL_MULT;
        }
        player.vy += gravity * dt;
    }
    
    // Terminal velocity
    if player.vy > MAX_FALL_SPEED {
        player.vy = MAX_FALL_SPEED;
    }
}

// ============================================================================
// COLLISION
// ============================================================================

resolve_collisions :: (player: *Player, level: *Level) {
    player.grounded = false;
    
    // Get player bounds
    left   := player.x - player.width / 2;
    right  := player.x + player.width / 2;
    top    := player.y - player.height / 2;
    bottom := player.y + player.height / 2;
    
    // Check each tile the player overlaps
    tile_left   := cast(int) floor(left / TILE_SIZE);
    tile_right  := cast(int) floor(right / TILE_SIZE);
    tile_top    := cast(int) floor(top / TILE_SIZE);
    tile_bottom := cast(int) floor(bottom / TILE_SIZE);
    
    for ty: tile_top..tile_bottom {
        for tx: tile_left..tile_right {
            if !is_solid_tile(level, tx, ty) continue;
            
            // Tile bounds
            tile_x := cast(float) tx * TILE_SIZE;
            tile_y := cast(float) ty * TILE_SIZE;
            
            // Calculate overlap
            overlap_left   := right - tile_x;
            overlap_right  := (tile_x + TILE_SIZE) - left;
            overlap_top    := bottom - tile_y;
            overlap_bottom := (tile_y + TILE_SIZE) - top;
            
            // Find minimum overlap
            min_overlap_x := ifx overlap_left < overlap_right then -overlap_left else overlap_right;
            min_overlap_y := ifx overlap_top < overlap_bottom then -overlap_top else overlap_bottom;
            
            // Push out along smallest axis
            if abs(min_overlap_x) < abs(min_overlap_y) {
                player.x += min_overlap_x;
                player.vx = 0;
            } else {
                player.y += min_overlap_y;
                if min_overlap_y < 0 {
                    // Hit ground
                    player.grounded = true;
                    player.coyote_timer = player.COYOTE_TIME;
                }
                player.vy = 0;
            }
        }
    }
}

check_wall_collision :: (player: *Player, level: *Level, direction: int) -> bool {
    // Check a point to the side of player
    check_x := player.x + direction * (player.width / 2 + 2);
    check_y := player.y;
    
    tile_x := cast(int) floor(check_x / TILE_SIZE);
    tile_y := cast(int) floor(check_y / TILE_SIZE);
    
    return is_solid_tile(level, tile_x, tile_y);
}

// ============================================================================
// TIMERS & ANIMATION
// ============================================================================

update_timers :: (player: *Player, dt: float) {
    if player.coyote_timer > 0 {
        player.coyote_timer -= dt;
    }
    if player.jump_buffer_timer > 0 {
        player.jump_buffer_timer -= dt;
    }
    if player.wall_jump_cooldown > 0 {
        player.wall_jump_cooldown -= dt;
    }
}

update_animation :: (player: *Player, dt: float) {
    // Run animation
    if player.grounded && abs(player.vx) > 10 {
        player.run_timer += dt * abs(player.vx) / 100.0;
    }
    
    // Squash/stretch recovery
    player.squash_stretch = lerp(player.squash_stretch, 1.0, 10.0 * dt);
}

on_land :: (player: *Player) {
    // Landing squash
    player.squash_stretch = 1.3;
    player.coyote_timer = player.COYOTE_TIME;
}

// ============================================================================
// UTILITY
// ============================================================================

lerp :: (a: float, b: float, t: float) -> float {
    return a + (b - a) * clamp(t, 0.0, 1.0);
}
