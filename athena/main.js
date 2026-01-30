// ============================================================================
// JAI MEATBOY - AthenaEnv v4 Port
// Super Meat Boy-style 2D Platformer for PlayStation 2
// ============================================================================

// Import game modules
import { Game, GameState } from './game.js';
import { Input } from './input.js';
import { Renderer } from './renderer.js';
import { loadLevel } from './level.js';

// ============================================================================
// CONSTANTS
// ============================================================================

const SCREEN_WIDTH = 640;
const SCREEN_HEIGHT = 448;
const TARGET_FPS = 60;
const FRAME_TIME = 1000 / TARGET_FPS;

// ============================================================================
// GLOBAL STATE
// ============================================================================

let game = null;
let input = null;
let renderer = null;
let lastTime = 0;

// ============================================================================
// INITIALIZATION
// ============================================================================

function init() {
    console.log("JAI MEATBOY - AthenaEnv v4");
    console.log("Initializing...");

    // Initialize subsystems
    input = new Input();
    renderer = new Renderer(SCREEN_WIDTH, SCREEN_HEIGHT);
    game = new Game();

    // Load first level
    const levelData = std.loadFile("assets/levels/level1.json");
    if (levelData) {
        const level = loadLevel(levelData);
        if (level) {
            game.setLevel(level);
        } else {
            console.log("Failed to parse level, using default");
            game.createDefaultLevel();
        }
    } else {
        console.log("Failed to load level file, using default");
        game.createDefaultLevel();
    }

    // Spawn player at level start
    game.spawnPlayer();

    console.log("Initialization complete!");
}

// ============================================================================
// MAIN LOOP
// ============================================================================

function mainLoop() {
    // Calculate delta time
    const currentTime = Timer.getTime(timer);
    const dt = Math.min((currentTime - lastTime) / 1000, 0.1); // Cap at 100ms
    lastTime = currentTime;

    // Update input
    input.update();

    // Update game
    game.update(input, dt);

    // Render
    renderer.render(game);
}

// ============================================================================
// ENTRY POINT
// ============================================================================

// Create timer for delta time
const timer = Timer.new();

// Initialize game
init();

// Get initial time
lastTime = Timer.getTime(timer);

// Configure screen
Screen.setMode({
    width: SCREEN_WIDTH,
    height: SCREEN_HEIGHT,
    psm: 0,  // 32-bit color
    zsm: 0,
    interlace: true,
    field: false
});

// Disable depth testing for 2D
Screen.setParam(Screen.DEPTH_TEST_ENABLE, false);

// Main game loop using Screen.display
Screen.display(() => {
    mainLoop();
});
