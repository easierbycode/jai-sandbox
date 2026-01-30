// ============================================================================
// RENDERER - OpenGL ES 3.0
// ============================================================================
// Efficient batch rendering for 2D platformer
// ============================================================================

Renderer :: struct {
    // Screen dimensions
    screen_width: int;
    screen_height: int;
    
    // Shaders
    sprite_shader: u32;
    
    // Batch rendering
    batch_vertices: [..] Vertex;
    batch_vao: u32;
    batch_vbo: u32;
    MAX_BATCH_VERTICES :: 10000;
    
    // Textures
    white_texture: u32;  // 1x1 white for colored shapes
    player_texture: u32;
    tile_texture: u32;
    
    // View matrix
    projection: Matrix4;
}

Vertex :: struct {
    x, y: float;      // Position
    u, v: float;      // UV
    r, g, b, a: float; // Color
}

// ============================================================================
// INITIALIZATION
// ============================================================================

init_renderer :: (r: *Renderer, width: int, height: int) {
    r.screen_width = width;
    r.screen_height = height;
    
    // OpenGL setup
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_DEPTH_TEST);
    
    // Create shader
    r.sprite_shader = create_shader(VERTEX_SHADER_SOURCE, FRAGMENT_SHADER_SOURCE);
    
    // Create batch buffers
    glGenVertexArrays(1, *r.batch_vao);
    glGenBuffers(1, *r.batch_vbo);
    
    glBindVertexArray(r.batch_vao);
    glBindBuffer(GL_ARRAY_BUFFER, r.batch_vbo);
    glBufferData(GL_ARRAY_BUFFER, r.MAX_BATCH_VERTICES * size_of(Vertex), null, GL_DYNAMIC_DRAW);
    
    // Vertex attributes
    stride := size_of(Vertex);
    
    // Position
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, stride, cast(*void) 0);
    glEnableVertexAttribArray(0);
    
    // UV
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, stride, cast(*void) 8);
    glEnableVertexAttribArray(1);
    
    // Color
    glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, stride, cast(*void) 16);
    glEnableVertexAttribArray(2);
    
    // Create white texture
    r.white_texture = create_white_texture();
    
    // Orthographic projection
    update_projection(r);
    
    log("Renderer initialized");
}

shutdown_renderer :: (r: *Renderer) {
    glDeleteBuffers(1, *r.batch_vbo);
    glDeleteVertexArrays(1, *r.batch_vao);
    glDeleteProgram(r.sprite_shader);
    glDeleteTextures(1, *r.white_texture);
}

update_projection :: (r: *Renderer) {
    // Orthographic projection centered at 0,0
    hw := cast(float) r.screen_width / 2.0;
    hh := cast(float) r.screen_height / 2.0;
    r.projection = orthographic_projection(-hw, hw, hh, -hh, -1, 1);
}

// ============================================================================
// RENDERING
// ============================================================================

render_game :: (r: *Renderer, game: *Game_State) {
    // Clear
    bg := game.level.background_color;
    glClearColor(bg.x, bg.y, bg.z, bg.w);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // Setup shader
    glUseProgram(r.sprite_shader);
    
    // Calculate view matrix (camera transform)
    view := make_view_matrix(*game.camera, r.screen_width, r.screen_height);
    mvp := r.projection * view;
    
    loc := glGetUniformLocation(r.sprite_shader, "u_MVP");
    glUniformMatrix4fv(loc, 1, GL_FALSE, *mvp.m[0][0]);
    
    // Bind texture
    glBindTexture(GL_TEXTURE_2D, r.white_texture);
    
    // Reset batch
    array_reset(*r.batch_vertices);
    
    // Render level
    render_level(r, *game.level);
    
    // Render goal
    render_goal(r, *game.level);
    
    // Render hazards
    render_hazards(r, *game.level);
    
    // Render player (if alive)
    if game.state != .DEAD {
        render_player(r, *game.player);
    }
    
    // Render particles
    render_particles(r, *game.particles);
    
    // Flush batch
    flush_batch(r);
    
    // Render UI (separate pass, screen space)
    render_ui(r, game);
}

// ============================================================================
// LEVEL RENDERING
// ============================================================================

render_level :: (r: *Renderer, level: *Level) {
    TILE_COLOR :: Vector4.{0.4, 0.4, 0.5, 1.0};
    
    for y: 0..level.height-1 {
        for x: 0..level.width-1 {
            tile := get_tile(level, x, y);
            if tile == .EMPTY continue;
            
            px := cast(float) x * TILE_SIZE;
            py := cast(float) y * TILE_SIZE;
            
            add_quad(r, px, py, TILE_SIZE, TILE_SIZE, TILE_COLOR);
        }
    }
}

render_goal :: (r: *Renderer, level: *Level) {
    // Pulsing goal indicator
    time := cast(float) get_time();
    pulse := 0.7 + sin(time * 5.0) * 0.3;
    
    color := Vector4.{0.2 * pulse, 0.8 * pulse, 0.3 * pulse, 1.0};
    
    g := level.goal_rect;
    add_quad(r, g.x, g.y, g.width, g.height, color);
}

render_hazards :: (r: *Renderer, level: *Level) {
    HAZARD_COLOR :: Vector4.{0.9, 0.2, 0.2, 1.0};
    
    for * hazard: level.hazards {
        add_quad(r, hazard.x, hazard.y, hazard.width, hazard.height, HAZARD_COLOR);
    }
}

// ============================================================================
// PLAYER RENDERING
// ============================================================================

render_player :: (r: *Renderer, player: *Player) {
    // Player color (meaty pink/red)
    color := Vector4.{0.9, 0.4, 0.35, 1.0};
    
    // Apply squash/stretch
    stretch_y := player.squash_stretch;
    stretch_x := 1.0 / stretch_y;  // Preserve volume
    
    width := player.width * stretch_x;
    height := player.height * stretch_y;
    
    // Center position
    x := player.x - width / 2;
    y := player.y - height / 2;
    
    // Offset when stretched (keep feet grounded)
    if player.grounded {
        y += (player.height - height) / 2;
    }
    
    add_quad(r, x, y, width, height, color);
    
    // Wall slide indicator
    if player.wall_sliding {
        wall_color := Vector4.{1.0, 1.0, 1.0, 0.5};
        indicator_x := ifx player.wall_direction < 0 then x - 4 else x + width;
        add_quad(r, indicator_x, y + 4, 3, height - 8, wall_color);
    }
}

// ============================================================================
// PARTICLE RENDERING
// ============================================================================

render_particles :: (r: *Renderer, particles: *[..] Particle) {
    for * p: particles.* {
        add_quad(r, p.x - p.size/2, p.y - p.size/2, p.size, p.size, p.color);
    }
}

// ============================================================================
// UI RENDERING
// ============================================================================

render_ui :: (r: *Renderer, game: *Game_State) {
    // Switch to screen space projection
    glUseProgram(r.sprite_shader);
    
    ui_proj := orthographic_projection(0, cast(float) r.screen_width, 
                                        cast(float) r.screen_height, 0, -1, 1);
    loc := glGetUniformLocation(r.sprite_shader, "u_MVP");
    glUniformMatrix4fv(loc, 1, GL_FALSE, *ui_proj.m[0][0]);
    
    array_reset(*r.batch_vertices);
    
    // Death counter (top left)
    if game.death_count > 0 {
        // Simple death counter bar
        bar_width := cast(float) min(game.death_count * 5, 200);
        add_quad(r, 20, 20, bar_width, 10, .{0.9, 0.2, 0.2, 0.8});
    }
    
    // State-specific UI
    if game.state == {
        case .DEAD;
            // Flash screen red
            alpha := game.death_timer / game.DEATH_RESPAWN_TIME;
            add_quad(r, 0, 0, cast(float) r.screen_width, cast(float) r.screen_height,
                     .{1.0, 0.0, 0.0, alpha * 0.3});
                     
        case .LEVEL_COMPLETE;
            // Green overlay
            add_quad(r, 0, 0, cast(float) r.screen_width, cast(float) r.screen_height,
                     .{0.0, 1.0, 0.0, 0.2});
                     
        case .MENU;
            // Darken background
            add_quad(r, 0, 0, cast(float) r.screen_width, cast(float) r.screen_height,
                     .{0.0, 0.0, 0.0, 0.5});
    }
    
    flush_batch(r);
}

// ============================================================================
// BATCH RENDERING
// ============================================================================

add_quad :: (r: *Renderer, x: float, y: float, w: float, h: float, color: Vector4) {
    // Two triangles
    // Top-left, top-right, bottom-right
    // Top-left, bottom-right, bottom-left
    
    v1 := Vertex.{ x,     y,     0, 0, color.x, color.y, color.z, color.w };
    v2 := Vertex.{ x + w, y,     1, 0, color.x, color.y, color.z, color.w };
    v3 := Vertex.{ x + w, y + h, 1, 1, color.x, color.y, color.z, color.w };
    v4 := Vertex.{ x,     y + h, 0, 1, color.x, color.y, color.z, color.w };
    
    array_add(*r.batch_vertices, v1);
    array_add(*r.batch_vertices, v2);
    array_add(*r.batch_vertices, v3);
    
    array_add(*r.batch_vertices, v1);
    array_add(*r.batch_vertices, v3);
    array_add(*r.batch_vertices, v4);
    
    // Auto-flush if batch full
    if r.batch_vertices.count >= r.MAX_BATCH_VERTICES - 6 {
        flush_batch(r);
    }
}

flush_batch :: (r: *Renderer) {
    if r.batch_vertices.count == 0 return;
    
    glBindVertexArray(r.batch_vao);
    glBindBuffer(GL_ARRAY_BUFFER, r.batch_vbo);
    
    // Upload vertices
    data_size := r.batch_vertices.count * size_of(Vertex);
    glBufferSubData(GL_ARRAY_BUFFER, 0, data_size, r.batch_vertices.data);
    
    // Draw
    glDrawArrays(GL_TRIANGLES, 0, cast(s32) r.batch_vertices.count);
    
    array_reset(*r.batch_vertices);
}

// ============================================================================
// CAMERA
// ============================================================================

make_view_matrix :: (camera: *Camera, screen_width: int, screen_height: int) -> Matrix4 {
    // Translate to center camera position
    return translation_matrix(-camera.x, -camera.y, 0);
}

// ============================================================================
// SHADER
// ============================================================================

VERTEX_SHADER_SOURCE :: #string GLSL
#version 300 es
precision highp float;

layout(location = 0) in vec2 a_Position;
layout(location = 1) in vec2 a_UV;
layout(location = 2) in vec4 a_Color;

uniform mat4 u_MVP;

out vec2 v_UV;
out vec4 v_Color;

void main() {
    gl_Position = u_MVP * vec4(a_Position, 0.0, 1.0);
    v_UV = a_UV;
    v_Color = a_Color;
}
GLSL

FRAGMENT_SHADER_SOURCE :: #string GLSL
#version 300 es
precision mediump float;

in vec2 v_UV;
in vec4 v_Color;

uniform sampler2D u_Texture;

out vec4 FragColor;

void main() {
    FragColor = v_Color * texture(u_Texture, v_UV);
}
GLSL

create_shader :: (vert_source: string, frag_source: string) -> u32 {
    // Compile vertex shader
    vert := glCreateShader(GL_VERTEX_SHADER);
    vert_src := vert_source.data;
    vert_len := cast(s32) vert_source.count;
    glShaderSource(vert, 1, *vert_src, *vert_len);
    glCompileShader(vert);
    check_shader_compile(vert, "vertex");
    
    // Compile fragment shader
    frag := glCreateShader(GL_FRAGMENT_SHADER);
    frag_src := frag_source.data;
    frag_len := cast(s32) frag_source.count;
    glShaderSource(frag, 1, *frag_src, *frag_len);
    glCompileShader(frag);
    check_shader_compile(frag, "fragment");
    
    // Link program
    program := glCreateProgram();
    glAttachShader(program, vert);
    glAttachShader(program, frag);
    glLinkProgram(program);
    check_program_link(program);
    
    glDeleteShader(vert);
    glDeleteShader(frag);
    
    return program;
}

check_shader_compile :: (shader: u32, name: string) {
    success: s32;
    glGetShaderiv(shader, GL_COMPILE_STATUS, *success);
    if !success {
        info_log: [512] u8;
        glGetShaderInfoLog(shader, 512, null, info_log.data);
        log("ERROR: % shader compilation failed: %", name, to_string(info_log.data));
    }
}

check_program_link :: (program: u32) {
    success: s32;
    glGetProgramiv(program, GL_LINK_STATUS, *success);
    if !success {
        info_log: [512] u8;
        glGetProgramInfoLog(program, 512, null, info_log.data);
        log("ERROR: Shader program linking failed: %", to_string(info_log.data));
    }
}

create_white_texture :: () -> u32 {
    tex: u32;
    glGenTextures(1, *tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    
    white_pixel: [4] u8 = .[255, 255, 255, 255];
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, white_pixel.data);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    
    return tex;
}

// ============================================================================
// MATRIX HELPERS
// ============================================================================

orthographic_projection :: (left: float, right: float, top: float, bottom: float, near: float, far: float) -> Matrix4 {
    m: Matrix4;
    
    m.m[0][0] = 2.0 / (right - left);
    m.m[1][1] = 2.0 / (top - bottom);
    m.m[2][2] = -2.0 / (far - near);
    m.m[3][0] = -(right + left) / (right - left);
    m.m[3][1] = -(top + bottom) / (top - bottom);
    m.m[3][2] = -(far + near) / (far - near);
    m.m[3][3] = 1.0;
    
    return m;
}

translation_matrix :: (x: float, y: float, z: float) -> Matrix4 {
    m := Matrix4_Identity;
    m.m[3][0] = x;
    m.m[3][1] = y;
    m.m[3][2] = z;
    return m;
}
