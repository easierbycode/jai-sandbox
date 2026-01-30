// ============================================================================
// GAME STATE & CORE LOGIC
// ============================================================================

import { Player, PLAYER_WIDTH, PLAYER_HEIGHT } from './player.js';
import { TILE_SIZE, isSolidTile, createDefaultLevel } from './level.js';

// ============================================================================
// GAME STATES
// ============================================================================

export const GameState = {
    MENU: 0,
    PLAYING: 1,
    PAUSED: 2,
    DEAD: 3,
    LEVEL_COMPLETE: 4
};

// ============================================================================
// CAMERA
// ============================================================================

class Camera {
    constructor() {
        this.x = 0;
        this.y = 0;
        this.targetX = 0;
        this.targetY = 0;
        this.zoom = 1.0;
        this.shakeAmount = 0;
        this.shakeTimer = 0;

        // Smooth follow params
        this.FOLLOW_SPEED = 8.0;
        this.LOOK_AHEAD = 50.0;
    }

    update(player, dt) {
        // Target position with look-ahead
        const lookAhead = player.facingRight ? this.LOOK_AHEAD : -this.LOOK_AHEAD;
        this.targetX = player.x + lookAhead;
        this.targetY = player.y;

        // Smooth follow
        this.x += (this.targetX - this.x) * this.FOLLOW_SPEED * dt;
        this.y += (this.targetY - this.y) * this.FOLLOW_SPEED * dt;

        // Shake
        if (this.shakeTimer > 0) {
            this.shakeTimer -= dt;
            const shakeX = (Math.random() * 2 - 1) * this.shakeAmount;
            const shakeY = (Math.random() * 2 - 1) * this.shakeAmount;
            this.x += shakeX;
            this.y += shakeY;
            this.shakeAmount *= 0.9; // Decay
        }
    }
}

// ============================================================================
// PARTICLE
// ============================================================================

class Particle {
    constructor(x, y) {
        this.x = x;
        this.y = y;

        // Random velocity burst
        const angle = Math.random() * Math.PI * 2;
        const speed = 100 + Math.random() * 200;
        this.vx = Math.cos(angle) * speed;
        this.vy = Math.sin(angle) * speed;

        this.life = 0.3 + Math.random() * 0.5;
        this.maxLife = this.life;
        this.size = 3 + Math.random() * 5;

        // Meaty red color
        this.r = 230;
        this.g = 50;
        this.b = 25;
        this.a = 255;
    }

    update(dt) {
        const GRAVITY = 500.0;

        this.life -= dt;
        if (this.life <= 0) {
            return false; // Dead
        }

        // Physics
        this.vy += GRAVITY * dt;
        this.x += this.vx * dt;
        this.y += this.vy * dt;

        // Fade out
        this.a = Math.floor((this.life / this.maxLife) * 255);

        return true; // Still alive
    }
}

// ============================================================================
// GAME CLASS
// ============================================================================

export class Game {
    constructor() {
        this.state = GameState.MENU;

        // Player
        this.player = new Player();

        // Level
        this.level = null;
        this.currentLevelIndex = 0;

        // Timing
        this.levelTime = 0;
        this.deathCount = 0;
        this.totalTime = 0;

        // Death/respawn
        this.deathTimer = 0;
        this.DEATH_RESPAWN_TIME = 0.5;

        // Camera
        this.camera = new Camera();

        // Particles
        this.particles = [];
    }

    setLevel(level) {
        this.level = level;
    }

    createDefaultLevel() {
        this.level = createDefaultLevel();
    }

    // ========================================================================
    // GAME UPDATE
    // ========================================================================

    update(input, dt) {
        switch (this.state) {
            case GameState.MENU:
                this.updateMenu(input);
                break;

            case GameState.PLAYING:
                this.updatePlaying(input, dt);
                break;

            case GameState.DEAD:
                this.updateDead(dt);
                break;

            case GameState.LEVEL_COMPLETE:
                this.updateLevelComplete(input);
                break;

            case GameState.PAUSED:
                if (input.pausePressed) {
                    this.state = GameState.PLAYING;
                }
                break;
        }

        // Always update particles
        this.updateParticles(dt);
    }

    updateMenu(input) {
        if (input.jumpPressed || input.startPressed) {
            this.state = GameState.PLAYING;
            this.spawnPlayer();
        }
    }

    updatePlaying(input, dt) {
        // Pause
        if (input.pausePressed) {
            this.state = GameState.PAUSED;
            return;
        }

        // Update player
        this.player.update(input, this.level, dt);

        // Check hazards
        if (this.checkHazardCollision()) {
            this.killPlayer();
            return;
        }

        // Check goal
        if (this.checkGoalCollision()) {
            this.completeLevel();
            return;
        }

        // Update camera
        this.camera.update(this.player, dt);

        // Update timer
        this.levelTime += dt;
        this.totalTime += dt;
    }

    updateDead(dt) {
        this.deathTimer -= dt;

        if (this.deathTimer <= 0) {
            this.respawnPlayer();
            this.state = GameState.PLAYING;
        }
    }

    updateLevelComplete(input) {
        if (input.jumpPressed || input.startPressed) {
            // Load next level
            this.currentLevelIndex++;

            // Try to load next level
            const nextLevelPath = `assets/levels/level${this.currentLevelIndex + 1}.json`;
            const levelData = std.loadFile(nextLevelPath);

            if (levelData) {
                const { loadLevel } = require('./level.js');
                const level = loadLevel(levelData);
                if (level) {
                    this.level = level;
                }
            } else {
                // No more levels, restart from beginning
                this.currentLevelIndex = 0;
                const levelData = std.loadFile("assets/levels/level1.json");
                if (levelData) {
                    const { loadLevel } = require('./level.js');
                    const level = loadLevel(levelData);
                    if (level) {
                        this.level = level;
                    }
                }
            }

            this.spawnPlayer();
            this.levelTime = 0;
            this.state = GameState.PLAYING;
        }
    }

    // ========================================================================
    // PLAYER MANAGEMENT
    // ========================================================================

    spawnPlayer() {
        this.player.reset();
        this.player.x = this.level.spawnX;
        this.player.y = this.level.spawnY;
        this.player.width = PLAYER_WIDTH;
        this.player.height = PLAYER_HEIGHT;
        this.player.facingRight = true;

        // Reset camera
        this.camera.x = this.player.x;
        this.camera.y = this.player.y;
        this.camera.targetX = this.player.x;
        this.camera.targetY = this.player.y;
    }

    respawnPlayer() {
        this.spawnPlayer();
    }

    killPlayer() {
        this.state = GameState.DEAD;
        this.deathCount++;
        this.deathTimer = this.DEATH_RESPAWN_TIME;

        // Spawn death particles
        this.spawnDeathParticles(this.player.x, this.player.y);

        // Camera shake
        this.camera.shakeAmount = 5.0;
        this.camera.shakeTimer = 0.3;
    }

    completeLevel() {
        this.state = GameState.LEVEL_COMPLETE;
    }

    // ========================================================================
    // PARTICLES
    // ========================================================================

    spawnDeathParticles(x, y) {
        const PARTICLE_COUNT = 20;

        for (let i = 0; i < PARTICLE_COUNT; i++) {
            this.particles.push(new Particle(x, y));
        }
    }

    updateParticles(dt) {
        // Update and remove dead particles
        this.particles = this.particles.filter(p => p.update(dt));
    }

    // ========================================================================
    // COLLISION CHECKS
    // ========================================================================

    checkHazardCollision() {
        const playerRect = this.getPlayerRect();

        for (const hazard of this.level.hazards) {
            if (this.rectsOverlap(playerRect, hazard)) {
                return true;
            }
        }

        // Also check out of bounds
        if (this.player.y > this.level.height * TILE_SIZE + 100) {
            return true; // Fell off bottom
        }

        return false;
    }

    checkGoalCollision() {
        const playerRect = this.getPlayerRect();
        return this.rectsOverlap(playerRect, this.level.goalRect);
    }

    getPlayerRect() {
        return {
            x: this.player.x - this.player.width / 2,
            y: this.player.y - this.player.height / 2,
            width: this.player.width,
            height: this.player.height
        };
    }

    rectsOverlap(a, b) {
        return a.x < b.x + b.width &&
               a.x + a.width > b.x &&
               a.y < b.y + b.height &&
               a.y + a.height > b.y;
    }
}
