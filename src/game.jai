// ============================================================================
// GAME STATE & CORE LOGIC
// ============================================================================

Game_State_Type :: enum {
    MENU;
    PLAYING;
    PAUSED;
    DEAD;
    LEVEL_COMPLETE;
}

Game_State :: struct {
    state: Game_State_Type;
    
    // Player
    player: Player;
    
    // Level data
    level: Level;
    current_level_index: int;
    
    // Timing
    level_time: float;
    death_count: int;
    total_time: float;
    
    // Death/respawn
    death_timer: float;
    DEATH_RESPAWN_TIME :: 0.5;  // Fast respawn like SMB
    
    // Camera
    camera: Camera;
    
    // Particles (for death effect, etc)
    particles: [..] Particle;
}

Camera :: struct {
    x, y: float;
    target_x, target_y: float;
    zoom: float = 1.0;
    shake_amount: float;
    shake_timer: float;
    
    // Smooth follow params
    FOLLOW_SPEED :: 8.0;
    LOOK_AHEAD :: 50.0;
}

Particle :: struct {
    x, y: float;
    vx, vy: float;
    life: float;
    max_life: float;
    color: Vector4;
    size: float;
}

// ============================================================================
// GAME UPDATE
// ============================================================================

update_game :: (game: *Game_State, input: *Input_State, dt: float) {
    if game.state == {
        case .MENU;
            update_menu(game, input);
            
        case .PLAYING;
            update_playing(game, input, dt);
            
        case .DEAD;
            update_dead(game, dt);
            
        case .LEVEL_COMPLETE;
            update_level_complete(game, input);
            
        case .PAUSED;
            if input.pause_pressed {
                game.state = .PLAYING;
            }
    }
    
    // Always update particles
    update_particles(game, dt);
}

update_menu :: (game: *Game_State, input: *Input_State) {
    if input.jump_pressed || input.start_pressed {
        game.state = .PLAYING;
        spawn_player(game);
    }
}

update_playing :: (game: *Game_State, input: *Input_State, dt: float) {
    // Pause
    if input.pause_pressed {
        game.state = .PAUSED;
        return;
    }
    
    // Update player
    update_player(*game.player, input, *game.level, dt);
    
    // Check hazards
    if check_hazard_collision(*game.player, *game.level) {
        kill_player(game);
        return;
    }
    
    // Check goal
    if check_goal_collision(*game.player, *game.level) {
        complete_level(game);
        return;
    }
    
    // Update camera
    update_camera(*game.camera, *game.player, dt);
    
    // Update timer
    game.level_time += dt;
    game.total_time += dt;
}

update_dead :: (game: *Game_State, dt: float) {
    game.death_timer -= dt;
    
    if game.death_timer <= 0 {
        respawn_player(game);
        game.state = .PLAYING;
    }
}

update_level_complete :: (game: *Game_State, input: *Input_State) {
    if input.jump_pressed || input.start_pressed {
        // Load next level
        game.current_level_index += 1;
        next_level := tprint("assets/levels/level%.json", game.current_level_index + 1);
        
        if !load_level(game, next_level) {
            // No more levels, back to menu or replay
            game.current_level_index = 0;
            load_level(game, "assets/levels/level1.json");
        }
        
        spawn_player(game);
        game.level_time = 0;
        game.state = .PLAYING;
    }
}

// ============================================================================
// PLAYER MANAGEMENT
// ============================================================================

spawn_player :: (game: *Game_State) {
    game.player = .{};
    game.player.x = game.level.spawn_x;
    game.player.y = game.level.spawn_y;
    game.player.width = PLAYER_WIDTH;
    game.player.height = PLAYER_HEIGHT;
    game.player.facing_right = true;
    
    // Reset camera
    game.camera.x = game.player.x;
    game.camera.y = game.player.y;
    game.camera.target_x = game.player.x;
    game.camera.target_y = game.player.y;
}

respawn_player :: (game: *Game_State) {
    spawn_player(game);
}

kill_player :: (game: *Game_State) {
    game.state = .DEAD;
    game.death_count += 1;
    game.death_timer = game.DEATH_RESPAWN_TIME;
    
    // Spawn death particles (meat chunks!)
    spawn_death_particles(game, game.player.x, game.player.y);
    
    // Camera shake
    game.camera.shake_amount = 5.0;
    game.camera.shake_timer = 0.3;
}

complete_level :: (game: *Game_State) {
    game.state = .LEVEL_COMPLETE;
    // Could play sound, particles, etc.
}

// ============================================================================
// CAMERA
// ============================================================================

update_camera :: (camera: *Camera, player: *Player, dt: float) {
    // Target position with look-ahead
    look_ahead := ifx player.facing_right then camera.LOOK_AHEAD else -camera.LOOK_AHEAD;
    camera.target_x = player.x + look_ahead;
    camera.target_y = player.y;
    
    // Smooth follow
    camera.x += (camera.target_x - camera.x) * camera.FOLLOW_SPEED * dt;
    camera.y += (camera.target_y - camera.y) * camera.FOLLOW_SPEED * dt;
    
    // Shake
    if camera.shake_timer > 0 {
        camera.shake_timer -= dt;
        shake_x := random_range(-camera.shake_amount, camera.shake_amount);
        shake_y := random_range(-camera.shake_amount, camera.shake_amount);
        camera.x += shake_x;
        camera.y += shake_y;
        camera.shake_amount *= 0.9;  // Decay
    }
}

// ============================================================================
// PARTICLES
// ============================================================================

spawn_death_particles :: (game: *Game_State, x: float, y: float) {
    PARTICLE_COUNT :: 20;
    
    for 0..PARTICLE_COUNT-1 {
        p: Particle;
        p.x = x;
        p.y = y;
        
        // Random velocity burst
        angle := random_range(0, TAU);
        speed := random_range(100, 300);
        p.vx = cos(angle) * speed;
        p.vy = sin(angle) * speed;
        
        p.life = random_range(0.3, 0.8);
        p.max_life = p.life;
        p.size = random_range(3, 8);
        
        // Meaty red color
        p.color = .{0.9, 0.2, 0.1, 1.0};
        
        array_add(*game.particles, p);
    }
}

update_particles :: (game: *Game_State, dt: float) {
    GRAVITY :: 500.0;
    
    i := 0;
    while i < game.particles.count {
        p := *game.particles[i];
        
        p.life -= dt;
        if p.life <= 0 {
            array_unordered_remove_by_index(*game.particles, i);
            continue;
        }
        
        // Physics
        p.vy += GRAVITY * dt;
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        
        // Fade out
        p.color.w = p.life / p.max_life;
        
        i += 1;
    }
}

// ============================================================================
// COLLISION CHECKS
// ============================================================================

check_hazard_collision :: (player: *Player, level: *Level) -> bool {
    player_rect := get_player_rect(player);
    
    for * hazard: level.hazards {
        if rects_overlap(player_rect, hazard.*) {
            return true;
        }
    }
    
    // Also check out of bounds
    if player.y > level.height * TILE_SIZE + 100 {
        return true;  // Fell off bottom
    }
    
    return false;
}

check_goal_collision :: (player: *Player, level: *Level) -> bool {
    player_rect := get_player_rect(player);
    return rects_overlap(player_rect, level.goal_rect);
}

get_player_rect :: (player: *Player) -> Rect {
    return .{
        x = player.x - player.width/2,
        y = player.y - player.height/2,
        width = player.width,
        height = player.height
    };
}

rects_overlap :: (a: Rect, b: Rect) -> bool {
    return a.x < b.x + b.width &&
           a.x + a.width > b.x &&
           a.y < b.y + b.height &&
           a.y + a.height > b.y;
}

// ============================================================================
// UTILITY
// ============================================================================

random_range :: (min: float, max: float) -> float {
    t := cast(float) random_get() / cast(float) U64_MAX;
    return min + t * (max - min);
}

TAU :: PI * 2.0;
