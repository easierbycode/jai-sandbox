// ============================================================================
// INPUT HANDLING
// ============================================================================
// Handles both Android touch input and desktop keyboard input
// Touch: Virtual D-pad on left, jump button on right
// ============================================================================

Input_State :: struct {
    // Movement (-1 to 1)
    move_x: float;
    move_y: float;
    
    // Actions (press = just pressed this frame, held = currently pressed)
    jump_pressed: bool;
    jump_held: bool;
    
    pause_pressed: bool;
    start_pressed: bool;
    
    quit_requested: bool;
    
    // Touch tracking
    touch_left: Touch_Info;
    touch_right: Touch_Info;
    
    // Previous frame state (for detecting presses)
    prev_jump_held: bool;
}

Touch_Info :: struct {
    active: bool;
    pointer_id: int;
    start_x, start_y: float;
    current_x, current_y: float;
}

// Virtual button layout (proportional to screen)
DPAD_CENTER_X  :: 0.15;   // 15% from left
DPAD_CENTER_Y  :: 0.75;   // 75% from top
DPAD_RADIUS    :: 0.12;   // 12% of screen width

JUMP_CENTER_X  :: 0.85;   // 85% from left
JUMP_CENTER_Y  :: 0.75;   // 75% from top
JUMP_RADIUS    :: 0.10;   // 10% of screen width

// ============================================================================
// ANDROID TOUCH INPUT
// ============================================================================

#if OS == .ANDROID {

process_input :: (input: *Input_State, app: *android_app) {
    // Store previous state
    input.prev_jump_held = input.jump_held;
    
    // Reset press states
    input.jump_pressed = false;
    input.pause_pressed = false;
    input.start_pressed = false;
    
    // Process all pending input events
    event: *AInputEvent;
    while AInputQueue_getEvent(app.inputQueue, *event) >= 0 {
        if AInputQueue_preDispatchEvent(app.inputQueue, event) {
            continue;
        }
        
        handled := handle_input_event(input, event, app);
        AInputQueue_finishEvent(app.inputQueue, event, handled);
    }
    
    // Calculate movement from touch
    calculate_touch_movement(input, app);
    
    // Detect jump press
    if input.jump_held && !input.prev_jump_held {
        input.jump_pressed = true;
    }
}

handle_input_event :: (input: *Input_State, event: *AInputEvent, app: *android_app) -> s32 {
    event_type := AInputEvent_getType(event);
    
    if event_type == AINPUT_EVENT_TYPE_MOTION {
        action := AMotionEvent_getAction(event);
        action_type := action & AMOTION_EVENT_ACTION_MASK;
        
        pointer_count := AMotionEvent_getPointerCount(event);
        
        screen_width := cast(float) ANativeWindow_getWidth(app.window);
        screen_height := cast(float) ANativeWindow_getHeight(app.window);
        
        if action_type == {
            case AMOTION_EVENT_ACTION_DOWN; #through;
            case AMOTION_EVENT_ACTION_POINTER_DOWN;
                // New touch
                pointer_index := (action & AMOTION_EVENT_ACTION_POINTER_INDEX_MASK) >> 8;
                pointer_id := AMotionEvent_getPointerId(event, pointer_index);
                
                x := AMotionEvent_getX(event, pointer_index) / screen_width;
                y := AMotionEvent_getY(event, pointer_index) / screen_height;
                
                // Determine if left or right side
                if x < 0.5 {
                    // Left side - D-pad
                    input.touch_left.active = true;
                    input.touch_left.pointer_id = pointer_id;
                    input.touch_left.start_x = x;
                    input.touch_left.start_y = y;
                    input.touch_left.current_x = x;
                    input.touch_left.current_y = y;
                } else {
                    // Right side - Jump
                    input.touch_right.active = true;
                    input.touch_right.pointer_id = pointer_id;
                    input.jump_held = true;
                    input.start_pressed = true;  // Any touch can start game
                }
                
            case AMOTION_EVENT_ACTION_MOVE;
                // Update active touches
                for i: 0..pointer_count-1 {
                    pointer_id := AMotionEvent_getPointerId(event, i);
                    x := AMotionEvent_getX(event, i) / screen_width;
                    y := AMotionEvent_getY(event, i) / screen_height;
                    
                    if input.touch_left.active && input.touch_left.pointer_id == pointer_id {
                        input.touch_left.current_x = x;
                        input.touch_left.current_y = y;
                    }
                    if input.touch_right.active && input.touch_right.pointer_id == pointer_id {
                        input.touch_right.current_x = x;
                        input.touch_right.current_y = y;
                    }
                }
                
            case AMOTION_EVENT_ACTION_UP; #through;
            case AMOTION_EVENT_ACTION_POINTER_UP; #through;
            case AMOTION_EVENT_ACTION_CANCEL;
                // Touch released
                pointer_index := (action & AMOTION_EVENT_ACTION_POINTER_INDEX_MASK) >> 8;
                pointer_id := AMotionEvent_getPointerId(event, pointer_index);
                
                if input.touch_left.active && input.touch_left.pointer_id == pointer_id {
                    input.touch_left.active = false;
                    input.move_x = 0;
                    input.move_y = 0;
                }
                if input.touch_right.active && input.touch_right.pointer_id == pointer_id {
                    input.touch_right.active = false;
                    input.jump_held = false;
                }
        }
        
        return 1;  // Handled
        
    } else if event_type == AINPUT_EVENT_TYPE_KEY {
        keycode := AKeyEvent_getKeyCode(event);
        action := AKeyEvent_getAction(event);
        
        // Back button = pause
        if keycode == AKEYCODE_BACK {
            if action == AKEY_EVENT_ACTION_DOWN {
                input.pause_pressed = true;
            }
            return 1;  // Consume back button
        }
    }
    
    return 0;  // Not handled
}

calculate_touch_movement :: (input: *Input_State, app: *android_app) {
    if !input.touch_left.active {
        input.move_x = 0;
        input.move_y = 0;
        return;
    }
    
    // Calculate offset from start position
    dx := input.touch_left.current_x - input.touch_left.start_x;
    dy := input.touch_left.current_y - input.touch_left.start_y;
    
    // Dead zone
    DEAD_ZONE :: 0.02;
    if abs(dx) < DEAD_ZONE then dx = 0;
    if abs(dy) < DEAD_ZONE then dy = 0;
    
    // Normalize to -1 to 1 range
    MAX_OFFSET :: 0.1;
    input.move_x = clamp(dx / MAX_OFFSET, -1.0, 1.0);
    input.move_y = clamp(dy / MAX_OFFSET, -1.0, 1.0);
}

} // End Android

// ============================================================================
// DESKTOP KEYBOARD INPUT
// ============================================================================

#if OS != .ANDROID {

process_desktop_input :: (input: *Input_State, window: *Window) {
    // Store previous state
    input.prev_jump_held = input.jump_held;
    
    // Reset press states
    input.jump_pressed = false;
    input.pause_pressed = false;
    input.start_pressed = false;
    
    // Horizontal movement
    left := key_held(window, .ARROW_LEFT) || key_held(window, .A);
    right := key_held(window, .ARROW_RIGHT) || key_held(window, .D);
    
    input.move_x = 0;
    if left then input.move_x -= 1;
    if right then input.move_x += 1;
    
    // Vertical (for menus, etc.)
    up := key_held(window, .ARROW_UP) || key_held(window, .W);
    down := key_held(window, .ARROW_DOWN) || key_held(window, .S);
    
    input.move_y = 0;
    if up then input.move_y -= 1;
    if down then input.move_y += 1;
    
    // Jump (Space, Z, or Up)
    input.jump_held = key_held(window, .SPACE) || 
                       key_held(window, .Z) || 
                       key_held(window, .ARROW_UP);
    
    if input.jump_held && !input.prev_jump_held {
        input.jump_pressed = true;
    }
    
    // Start (Enter)
    if key_pressed(window, .ENTER) {
        input.start_pressed = true;
    }
    
    // Pause (Escape)
    if key_pressed(window, .ESCAPE) {
        input.pause_pressed = true;
    }
    
    // Quit
    if key_pressed(window, .Q) && key_held(window, .CTRL) {
        input.quit_requested = true;
    }
}

} // End Desktop

// ============================================================================
// UTILITY
// ============================================================================

abs :: (x: float) -> float {
    return ifx x < 0 then -x else x;
}
