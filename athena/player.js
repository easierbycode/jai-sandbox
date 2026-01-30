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

import { TILE_SIZE, isSolidTile } from './level.js';

export const PLAYER_WIDTH = 16.0;
export const PLAYER_HEIGHT = 16.0;

// ============================================================================
// MOVEMENT CONSTANTS - TUNED FOR TIGHT CONTROLS
// ============================================================================

const MOVE_SPEED = 280.0;       // Horizontal speed
const GRAVITY = 1200.0;         // Base gravity
const FAST_FALL_MULT = 1.5;     // Gravity multiplier when falling
const JUMP_FORCE = 420.0;       // Initial jump velocity
const JUMP_CUT_MULT = 0.4;      // Velocity multiplier when releasing jump
const MAX_FALL_SPEED = 600.0;   // Terminal velocity

// Wall mechanics
const WALL_SLIDE_SPEED = 80.0;    // Max slide speed on wall
const WALL_JUMP_FORCE_X = 320.0;  // Horizontal wall jump boost
const WALL_JUMP_FORCE_Y = 380.0;  // Vertical wall jump force
const WALL_JUMP_COOLDOWN = 0.15;  // Time before can grab wall again

// Air control
const AIR_CONTROL = 0.9;          // High air control (SMB style)

// Timing
const COYOTE_TIME = 0.08;         // Jump grace period after leaving ground
const JUMP_BUFFER_TIME = 0.1;     // Queue jump input before landing

// ============================================================================
// PLAYER CLASS
// ============================================================================

export class Player {
    constructor() {
        this.reset();
    }

    reset() {
        // Position
        this.x = 0;
        this.y = 0;
        this.width = PLAYER_WIDTH;
        this.height = PLAYER_HEIGHT;

        // Velocity
        this.vx = 0;
        this.vy = 0;

        // State
        this.grounded = false;
        this.wallSliding = false;
        this.wallDirection = 0; // -1 = left wall, 1 = right wall
        this.facingRight = true;

        // Jump state
        this.jumpHeld = false;
        this.canVariableJump = false; // Can still cut jump short

        // Coyote time
        this.coyoteTimer = 0;

        // Jump buffer
        this.jumpBufferTimer = 0;

        // Wall jump cooldown
        this.wallJumpCooldown = 0;

        // Animation
        this.runTimer = 0;
        this.squashStretch = 1.0;
    }

    // ========================================================================
    // PLAYER UPDATE
    // ========================================================================

    update(input, level, dt) {
        // Store previous state
        const wasGrounded = this.grounded;

        // Update timers
        this.updateTimers(dt);

        // Horizontal movement
        this.handleHorizontalMovement(input, dt);

        // Wall detection
        this.handleWallDetection(input, level);

        // Jumping
        this.handleJumping(input);

        // Apply gravity
        this.applyGravity(dt);

        // Apply velocity
        this.x += this.vx * dt;
        this.y += this.vy * dt;

        // Collision resolution
        this.resolveCollisions(level);

        // Landing effects
        if (this.grounded && !wasGrounded) {
            this.onLand();
        }

        // Update facing direction
        if (this.vx > 10) {
            this.facingRight = true;
        } else if (this.vx < -10) {
            this.facingRight = false;
        }

        // Animation
        this.updateAnimation(dt);
    }

    // ========================================================================
    // MOVEMENT
    // ========================================================================

    handleHorizontalMovement(input, dt) {
        const targetVx = input.moveX * MOVE_SPEED;

        if (this.grounded) {
            // Instant acceleration on ground
            this.vx = targetVx;
        } else if (!this.wallSliding) {
            // High air control
            if (input.moveX !== 0) {
                this.vx = this.lerp(this.vx, targetVx, AIR_CONTROL);
            }
        }
    }

    handleWallDetection(input, level) {
        this.wallSliding = false;
        this.wallDirection = 0;

        // Can't wall slide during cooldown
        if (this.wallJumpCooldown > 0) return;

        // Must be airborne and falling
        if (this.grounded) return;
        if (this.vy < 0) return; // Only when falling

        // Check for walls
        const leftWall = this.checkWallCollision(level, -1);
        const rightWall = this.checkWallCollision(level, 1);

        // Wall slide if pressing toward wall
        if (leftWall && input.moveX < -0.1) {
            this.wallSliding = true;
            this.wallDirection = -1;
        } else if (rightWall && input.moveX > 0.1) {
            this.wallSliding = true;
            this.wallDirection = 1;
        }
    }

    // ========================================================================
    // JUMPING
    // ========================================================================

    handleJumping(input) {
        // Buffer jump input
        if (input.jumpPressed) {
            this.jumpBufferTimer = JUMP_BUFFER_TIME;
        }

        // Track if jump is held
        this.jumpHeld = input.jumpHeld;

        // Check if can jump
        const canGroundJump = this.grounded || this.coyoteTimer > 0;
        const canWallJump = this.wallSliding;
        const wantToJump = this.jumpBufferTimer > 0;

        if (wantToJump) {
            if (canWallJump) {
                // Wall jump!
                this.wallJump();
                this.jumpBufferTimer = 0;
            } else if (canGroundJump) {
                // Normal jump
                this.groundJump();
                this.jumpBufferTimer = 0;
            }
        }

        // Variable jump height - cut jump short when releasing
        if (!this.jumpHeld && this.canVariableJump && this.vy < 0) {
            this.vy *= JUMP_CUT_MULT;
            this.canVariableJump = false;
        }
    }

    groundJump() {
        this.vy = -JUMP_FORCE;
        this.grounded = false;
        this.coyoteTimer = 0;
        this.canVariableJump = true;

        // Squash and stretch
        this.squashStretch = 0.7;
    }

    wallJump() {
        // Jump away from wall
        this.vx = -this.wallDirection * WALL_JUMP_FORCE_X;
        this.vy = -WALL_JUMP_FORCE_Y;

        this.wallSliding = false;
        this.wallJumpCooldown = WALL_JUMP_COOLDOWN;
        this.canVariableJump = true;

        // Face away from wall
        this.facingRight = this.wallDirection < 0;

        // Squash and stretch
        this.squashStretch = 0.7;
    }

    // ========================================================================
    // GRAVITY
    // ========================================================================

    applyGravity(dt) {
        let gravity = GRAVITY;

        if (this.wallSliding) {
            // Reduced gravity on wall
            if (this.vy > WALL_SLIDE_SPEED) {
                this.vy = WALL_SLIDE_SPEED;
            } else {
                this.vy += gravity * 0.3 * dt;
            }
        } else {
            // Normal gravity, faster when falling
            if (this.vy > 0) {
                gravity *= FAST_FALL_MULT;
            }
            this.vy += gravity * dt;
        }

        // Terminal velocity
        if (this.vy > MAX_FALL_SPEED) {
            this.vy = MAX_FALL_SPEED;
        }
    }

    // ========================================================================
    // COLLISION
    // ========================================================================

    resolveCollisions(level) {
        this.grounded = false;

        // Get player bounds
        const left = this.x - this.width / 2;
        const right = this.x + this.width / 2;
        const top = this.y - this.height / 2;
        const bottom = this.y + this.height / 2;

        // Check each tile the player overlaps
        const tileLeft = Math.floor(left / TILE_SIZE);
        const tileRight = Math.floor(right / TILE_SIZE);
        const tileTop = Math.floor(top / TILE_SIZE);
        const tileBottom = Math.floor(bottom / TILE_SIZE);

        for (let ty = tileTop; ty <= tileBottom; ty++) {
            for (let tx = tileLeft; tx <= tileRight; tx++) {
                if (!isSolidTile(level, tx, ty)) continue;

                // Tile bounds
                const tileX = tx * TILE_SIZE;
                const tileY = ty * TILE_SIZE;

                // Calculate overlap
                const overlapLeft = right - tileX;
                const overlapRight = (tileX + TILE_SIZE) - left;
                const overlapTop = bottom - tileY;
                const overlapBottom = (tileY + TILE_SIZE) - top;

                // Find minimum overlap
                const minOverlapX = overlapLeft < overlapRight ? -overlapLeft : overlapRight;
                const minOverlapY = overlapTop < overlapBottom ? -overlapTop : overlapBottom;

                // Push out along smallest axis
                if (Math.abs(minOverlapX) < Math.abs(minOverlapY)) {
                    this.x += minOverlapX;
                    this.vx = 0;
                } else {
                    this.y += minOverlapY;
                    if (minOverlapY < 0) {
                        // Hit ground
                        this.grounded = true;
                        this.coyoteTimer = COYOTE_TIME;
                    }
                    this.vy = 0;
                }
            }
        }
    }

    checkWallCollision(level, direction) {
        // Check a point to the side of player
        const checkX = this.x + direction * (this.width / 2 + 2);
        const checkY = this.y;

        const tileX = Math.floor(checkX / TILE_SIZE);
        const tileY = Math.floor(checkY / TILE_SIZE);

        return isSolidTile(level, tileX, tileY);
    }

    // ========================================================================
    // TIMERS & ANIMATION
    // ========================================================================

    updateTimers(dt) {
        if (this.coyoteTimer > 0) {
            this.coyoteTimer -= dt;
        }
        if (this.jumpBufferTimer > 0) {
            this.jumpBufferTimer -= dt;
        }
        if (this.wallJumpCooldown > 0) {
            this.wallJumpCooldown -= dt;
        }
    }

    updateAnimation(dt) {
        // Run animation
        if (this.grounded && Math.abs(this.vx) > 10) {
            this.runTimer += dt * Math.abs(this.vx) / 100.0;
        }

        // Squash/stretch recovery
        this.squashStretch = this.lerp(this.squashStretch, 1.0, 10.0 * dt);
    }

    onLand() {
        // Landing squash
        this.squashStretch = 1.3;
        this.coyoteTimer = COYOTE_TIME;
    }

    // ========================================================================
    // UTILITY
    // ========================================================================

    lerp(a, b, t) {
        t = Math.max(0, Math.min(1, t));
        return a + (b - a) * t;
    }
}
