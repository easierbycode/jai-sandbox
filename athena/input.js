// ============================================================================
// INPUT HANDLING - PS2 Controller via AthenaEnv Pads Module
// ============================================================================

// ============================================================================
// INPUT CLASS
// ============================================================================

export class Input {
    constructor() {
        // Movement (-1 to 1)
        this.moveX = 0;
        this.moveY = 0;

        // Actions
        this.jumpPressed = false;  // Just pressed this frame
        this.jumpHeld = false;     // Currently held

        this.pausePressed = false;
        this.startPressed = false;

        // Previous frame state
        this.prevJumpHeld = false;
        this.prevStartHeld = false;
        this.prevPauseHeld = false;

        // Analog stick dead zone
        this.DEAD_ZONE = 30;
    }

    update() {
        // Store previous state
        this.prevJumpHeld = this.jumpHeld;
        this.prevStartHeld = this.startPressed;
        this.prevPauseHeld = this.pausePressed;

        // Reset press states
        this.jumpPressed = false;
        this.pausePressed = false;
        this.startPressed = false;

        // Get pad state for player 1 (port 0)
        const pad = Pads.get(0);

        // Update pad data
        pad.update();

        // ====================================================================
        // MOVEMENT - D-Pad and Left Analog Stick
        // ====================================================================

        this.moveX = 0;
        this.moveY = 0;

        // D-Pad (discrete)
        if (pad.pressed(Pads.LEFT)) {
            this.moveX = -1;
        } else if (pad.pressed(Pads.RIGHT)) {
            this.moveX = 1;
        }

        if (pad.pressed(Pads.UP)) {
            this.moveY = -1;
        } else if (pad.pressed(Pads.DOWN)) {
            this.moveY = 1;
        }

        // Left analog stick (if D-Pad not pressed)
        // Analog values are 0-255, with 128 being center
        if (this.moveX === 0) {
            const lx = pad.lx - 128; // Convert to -128 to 127
            if (Math.abs(lx) > this.DEAD_ZONE) {
                this.moveX = lx / 128;
            }
        }

        if (this.moveY === 0) {
            const ly = pad.ly - 128;
            if (Math.abs(ly) > this.DEAD_ZONE) {
                this.moveY = ly / 128;
            }
        }

        // ====================================================================
        // JUMP - Cross (X) button, also R1, R2
        // ====================================================================

        this.jumpHeld = pad.pressed(Pads.CROSS) ||
                        pad.pressed(Pads.R1) ||
                        pad.pressed(Pads.R2);

        // Detect just pressed
        if (this.jumpHeld && !this.prevJumpHeld) {
            this.jumpPressed = true;
        }

        // ====================================================================
        // START / PAUSE
        // ====================================================================

        const startHeld = pad.pressed(Pads.START);
        if (startHeld && !this.prevStartHeld) {
            this.startPressed = true;
            this.pausePressed = true; // START also acts as pause toggle
        }

        // SELECT can also pause
        const selectHeld = pad.pressed(Pads.SELECT);
        if (selectHeld && !this.prevPauseHeld) {
            this.pausePressed = true;
        }
    }
}
