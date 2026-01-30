// ============================================================================
// JAI SUPER MEAT BOY STYLE PLATFORMER - ANDROID ARM64
// ============================================================================
// A tight, responsive 2D platformer with:
// - Wall jumping, wall sliding
// - Tight air control
// - Instant death/respawn
// - JSON level loading
// ============================================================================

#import "Basic";
#import "Math";
#import "File";
#import "String";
#import "JSON";

#if OS == .ANDROID {
    #import "Android";
    #import "Android_Functions";
    Android_Functions :: #import "Android_Functions";
}

#import "GL";
#import "Input";

#load "game.jai";
#load "player.jai";
#load "level.jai";
#load "renderer.jai";
#load "physics.jai";
#load "input_handler.jai";

// ============================================================================
// GLOBAL STATE
// ============================================================================

game_state: Game_State;
renderer: Renderer;
input_state: Input_State;

WINDOW_WIDTH  :: 1920;
WINDOW_HEIGHT :: 1080;
TARGET_FPS    :: 60;
FIXED_DT      :: 1.0 / TARGET_FPS;

// ============================================================================
// ANDROID NATIVE ACTIVITY ENTRY
// ============================================================================

#if OS == .ANDROID {
    
    #program_export
    ANativeActivity_onCreate :: (activity: *ANativeActivity, saved_state: *void, saved_state_size: u64) #c_call {
        push_context {
            android_main(activity);
        }
    }
    
    android_main :: (activity: *ANativeActivity) {
        log("=== JAI MEATBOY PLATFORMER STARTING ===");
        log("Platform: Android ARM64");
        
        // Initialize Android app
        app := android_app_create(activity);
        defer android_app_destroy(app);
        
        // Request permissions
        request_permissions(activity);
        
        // Initialize game systems
        init_game();
        
        // Main loop
        running := true;
        last_time := get_time();
        accumulator := 0.0;
        
        while running {
            // Process Android events
            events: s32;
            source: *android_poll_source;
            
            while ALooper_pollAll(0, null, *events, cast(**void) *source) >= 0 {
                if source {
                    source.process(app, source);
                }
                if app.destroyRequested {
                    running = false;
                }
            }
            
            if app.window {
                current_time := get_time();
                frame_time := current_time - last_time;
                last_time = current_time;
                
                accumulator += frame_time;
                
                // Fixed timestep updates
                while accumulator >= FIXED_DT {
                    process_input(*input_state, app);
                    update_game(*game_state, *input_state, FIXED_DT);
                    accumulator -= FIXED_DT;
                }
                
                // Render
                render_game(*renderer, *game_state);
                eglSwapBuffers(app.display, app.surface);
            }
        }
        
        shutdown_game();
        log("=== GAME SHUTDOWN COMPLETE ===");
    }
    
    request_permissions :: (activity: *ANativeActivity) {
        // Internet and file system permissions are declared in manifest
        // Runtime permissions for external storage if needed
        log("Permissions configured via AndroidManifest.xml");
    }

} else {
    
    // ========================================================================
    // DESKTOP ENTRY (for testing)
    // ========================================================================
    
    main :: () {
        print("=== JAI MEATBOY PLATFORMER (Desktop) ===\n");
        
        // Create window
        window := create_window(WINDOW_WIDTH, WINDOW_HEIGHT, "Meatboy Platformer");
        if !window {
            print("Failed to create window!\n");
            return;
        }
        
        init_game();
        
        running := true;
        last_time := get_time();
        accumulator := 0.0;
        
        while running && !window_should_close(window) {
            current_time := get_time();
            frame_time := current_time - last_time;
            last_time = current_time;
            
            accumulator += frame_time;
            
            // Fixed timestep
            while accumulator >= FIXED_DT {
                process_desktop_input(*input_state, window);
                update_game(*game_state, *input_state, FIXED_DT);
                accumulator -= FIXED_DT;
            }
            
            render_game(*renderer, *game_state);
            swap_buffers(window);
            poll_events();
            
            if input_state.quit_requested {
                running = false;
            }
        }
        
        shutdown_game();
        destroy_window(window);
        print("Goodbye!\n");
    }
}

// ============================================================================
// GAME INITIALIZATION
// ============================================================================

init_game :: () {
    log("Initializing game systems...");
    
    // Initialize renderer
    init_renderer(*renderer, WINDOW_WIDTH, WINDOW_HEIGHT);
    
    // Initialize game state
    game_state = .{};
    game_state.state = .MENU;
    
    // Load level 1
    success := load_level(*game_state, "assets/levels/level1.json");
    if !success {
        log("WARNING: Failed to load level1.json, using default level");
        create_default_level(*game_state);
    }
    
    // Initialize player at spawn point
    spawn_player(*game_state);
    
    game_state.state = .PLAYING;
    log("Game initialized successfully!");
}

shutdown_game :: () {
    log("Shutting down game...");
    shutdown_renderer(*renderer);
    log("Shutdown complete");
}

// ============================================================================
// UTILITY
// ============================================================================

log :: (fmt: string, args: .. Any) {
    #if OS == .ANDROID {
        // Use Android logcat
        message := tprint(fmt, ..args);
        __android_log_print(ANDROID_LOG_INFO, "JaiMeatboy", "%s", message.data);
    } else {
        print(fmt, ..args);
        print("\n");
    }
}

get_time :: () -> float64 {
    #if OS == .ANDROID {
        ts: timespec;
        clock_gettime(CLOCK_MONOTONIC, *ts);
        return cast(float64) ts.tv_sec + cast(float64) ts.tv_nsec / 1_000_000_000.0;
    } else {
        return seconds_since_init();
    }
}
