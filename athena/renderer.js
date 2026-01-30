// ============================================================================
// RENDERER - AthenaEnv Draw API
// ============================================================================
// Renders the game using PS2's Graphics Synthesizer via AthenaEnv
// ============================================================================

import { GameState } from './game.js';
import { TILE_SIZE, TileType, getTile } from './level.js';

// ============================================================================
// COLORS (AthenaEnv Color.new format: r, g, b, a)
// ============================================================================

const COLORS = {
    TILE: null,      // Gray
    HAZARD: null,    // Red
    PLAYER: null,    // Meaty pink
    GOAL: null,      // Green (will pulse)
    WALL_SLIDE: null // White semi-transparent
};

function initColors() {
    COLORS.TILE = Color.new(102, 102, 128, 255);      // 0.4, 0.4, 0.5
    COLORS.HAZARD = Color.new(230, 51, 51, 255);     // 0.9, 0.2, 0.2
    COLORS.PLAYER = Color.new(230, 102, 89, 255);   // 0.9, 0.4, 0.35
    COLORS.WALL_SLIDE = Color.new(255, 255, 255, 128);
}

// ============================================================================
// RENDERER CLASS
// ============================================================================

export class Renderer {
    constructor(screenWidth, screenHeight) {
        this.screenWidth = screenWidth;
        this.screenHeight = screenHeight;

        // Half dimensions for centering
        this.halfWidth = screenWidth / 2;
        this.halfHeight = screenHeight / 2;

        // Initialize colors
        initColors();

        // Animation timer
        this.time = 0;

        // Font for UI text
        this.font = new Font("default");
        this.font.scale = 0.8;

        console.log(`Renderer initialized: ${screenWidth}x${screenHeight}`);
    }

    // ========================================================================
    // MAIN RENDER
    // ========================================================================

    render(game) {
        this.time += 1/60; // Approximate time

        // Clear screen with background color
        const bg = game.level.backgroundColor;
        Screen.clear(Color.new(bg.r, bg.g, bg.b, 255));

        // Calculate camera offset (center on camera position)
        const camOffsetX = this.halfWidth - game.camera.x;
        const camOffsetY = this.halfHeight - game.camera.y;

        // Render world-space elements
        this.renderLevel(game.level, camOffsetX, camOffsetY);
        this.renderGoal(game.level, camOffsetX, camOffsetY);
        this.renderHazards(game.level, camOffsetX, camOffsetY);

        // Render player (if alive)
        if (game.state !== GameState.DEAD) {
            this.renderPlayer(game.player, camOffsetX, camOffsetY);
        }

        // Render particles
        this.renderParticles(game.particles, camOffsetX, camOffsetY);

        // Render UI (screen space)
        this.renderUI(game);

        // Flip the screen buffer
        Screen.flip();
    }

    // ========================================================================
    // LEVEL RENDERING
    // ========================================================================

    renderLevel(level, offsetX, offsetY) {
        // Only render visible tiles for performance
        const startX = Math.max(0, Math.floor((-offsetX) / TILE_SIZE));
        const startY = Math.max(0, Math.floor((-offsetY) / TILE_SIZE));
        const endX = Math.min(level.width, Math.ceil((this.screenWidth - offsetX) / TILE_SIZE));
        const endY = Math.min(level.height, Math.ceil((this.screenHeight - offsetY) / TILE_SIZE));

        for (let y = startY; y < endY; y++) {
            for (let x = startX; x < endX; x++) {
                const tile = getTile(level, x, y);
                if (tile === TileType.EMPTY) continue;

                const px = x * TILE_SIZE + offsetX;
                const py = y * TILE_SIZE + offsetY;

                Draw.rect(px, py, TILE_SIZE, TILE_SIZE, COLORS.TILE);
            }
        }
    }

    renderGoal(level, offsetX, offsetY) {
        // Pulsing goal indicator
        const pulse = 0.5 + Math.sin(this.time * 5.0) * 0.5;
        const intensity = Math.floor(50 + pulse * 155);

        const goalColor = Color.new(
            Math.floor(51 * pulse),   // 0.2 * pulse
            intensity,                 // 0.3 to 0.8
            Math.floor(76 * pulse),   // 0.3 * pulse
            255
        );

        const g = level.goalRect;
        Draw.rect(
            g.x + offsetX,
            g.y + offsetY,
            g.width,
            g.height,
            goalColor
        );
    }

    renderHazards(level, offsetX, offsetY) {
        for (const hazard of level.hazards) {
            Draw.rect(
                hazard.x + offsetX,
                hazard.y + offsetY,
                hazard.width,
                hazard.height,
                COLORS.HAZARD
            );
        }
    }

    // ========================================================================
    // PLAYER RENDERING
    // ========================================================================

    renderPlayer(player, offsetX, offsetY) {
        // Apply squash/stretch
        const stretchY = player.squashStretch;
        const stretchX = 1.0 / stretchY; // Preserve volume

        const width = player.width * stretchX;
        const height = player.height * stretchY;

        // Center position
        let x = player.x - width / 2 + offsetX;
        let y = player.y - height / 2 + offsetY;

        // Offset when stretched (keep feet grounded)
        if (player.grounded) {
            y += (player.height - height) / 2;
        }

        Draw.rect(x, y, width, height, COLORS.PLAYER);

        // Wall slide indicator
        if (player.wallSliding) {
            const indicatorX = player.wallDirection < 0 ? x - 4 : x + width;
            Draw.rect(indicatorX, y + 4, 3, height - 8, COLORS.WALL_SLIDE);
        }
    }

    // ========================================================================
    // PARTICLE RENDERING
    // ========================================================================

    renderParticles(particles, offsetX, offsetY) {
        for (const p of particles) {
            const particleColor = Color.new(p.r, p.g, p.b, p.a);
            Draw.rect(
                p.x - p.size / 2 + offsetX,
                p.y - p.size / 2 + offsetY,
                p.size,
                p.size,
                particleColor
            );
        }
    }

    // ========================================================================
    // UI RENDERING
    // ========================================================================

    renderUI(game) {
        // Death counter (top left) - simple bar
        if (game.deathCount > 0) {
            const barWidth = Math.min(game.deathCount * 5, 200);
            const deathBarColor = Color.new(230, 51, 51, 200);
            Draw.rect(20, 20, barWidth, 10, deathBarColor);

            // Death count text
            this.font.color = Color.new(255, 255, 255, 255);
            this.font.print(22, 8, `Deaths: ${game.deathCount}`);
        }

        // Level time (top right)
        const timeStr = game.levelTime.toFixed(1) + "s";
        this.font.color = Color.new(255, 255, 255, 200);
        this.font.print(this.screenWidth - 80, 8, timeStr);

        // State-specific UI overlays
        switch (game.state) {
            case GameState.MENU:
                this.renderMenuOverlay();
                break;

            case GameState.DEAD:
                this.renderDeathOverlay(game);
                break;

            case GameState.LEVEL_COMPLETE:
                this.renderCompleteOverlay(game);
                break;

            case GameState.PAUSED:
                this.renderPauseOverlay();
                break;
        }
    }

    renderMenuOverlay() {
        // Darken background
        const overlayColor = Color.new(0, 0, 0, 128);
        Draw.rect(0, 0, this.screenWidth, this.screenHeight, overlayColor);

        // Title
        this.font.scale = 1.5;
        this.font.color = Color.new(230, 102, 89, 255);
        this.font.print(this.halfWidth - 100, this.halfHeight - 60, "JAI MEATBOY");

        // Instructions
        this.font.scale = 0.8;
        this.font.color = Color.new(255, 255, 255, 255);
        this.font.print(this.halfWidth - 80, this.halfHeight, "Press X to Start");

        this.font.color = Color.new(200, 200, 200, 200);
        this.font.print(this.halfWidth - 100, this.halfHeight + 40, "D-Pad/Stick: Move");
        this.font.print(this.halfWidth - 100, this.halfHeight + 60, "X/R1/R2: Jump");
    }

    renderDeathOverlay(game) {
        // Flash screen red
        const alpha = Math.floor((game.deathTimer / game.DEATH_RESPAWN_TIME) * 76);
        const flashColor = Color.new(255, 0, 0, alpha);
        Draw.rect(0, 0, this.screenWidth, this.screenHeight, flashColor);
    }

    renderCompleteOverlay(game) {
        // Green overlay
        const overlayColor = Color.new(0, 255, 0, 50);
        Draw.rect(0, 0, this.screenWidth, this.screenHeight, overlayColor);

        // Level complete text
        this.font.scale = 1.2;
        this.font.color = Color.new(50, 255, 100, 255);
        this.font.print(this.halfWidth - 100, this.halfHeight - 40, "LEVEL COMPLETE!");

        // Stats
        this.font.scale = 0.8;
        this.font.color = Color.new(255, 255, 255, 255);
        this.font.print(this.halfWidth - 60, this.halfHeight, `Time: ${game.levelTime.toFixed(2)}s`);
        this.font.print(this.halfWidth - 60, this.halfHeight + 25, `Deaths: ${game.deathCount}`);

        // Continue prompt
        this.font.color = Color.new(200, 200, 200, 200);
        this.font.print(this.halfWidth - 80, this.halfHeight + 60, "Press X to Continue");
    }

    renderPauseOverlay() {
        // Darken background
        const overlayColor = Color.new(0, 0, 0, 150);
        Draw.rect(0, 0, this.screenWidth, this.screenHeight, overlayColor);

        // Pause text
        this.font.scale = 1.2;
        this.font.color = Color.new(255, 255, 255, 255);
        this.font.print(this.halfWidth - 50, this.halfHeight - 20, "PAUSED");

        this.font.scale = 0.8;
        this.font.color = Color.new(200, 200, 200, 200);
        this.font.print(this.halfWidth - 80, this.halfHeight + 20, "Press START to Resume");
    }
}
