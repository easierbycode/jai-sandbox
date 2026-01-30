// ============================================================================
// LEVEL LOADING & MANAGEMENT
// ============================================================================
// Loads levels from JSON files with the following structure:
// - Tile grid (collision)
// - Hazards (spikes, saws, etc.)
// - Spawn point
// - Goal/exit
// ============================================================================

export const TILE_SIZE = 16.0;

// Tile types
export const TileType = {
    EMPTY: 0,
    SOLID: 1,
    PLATFORM: 2  // One-way platform
};

// ============================================================================
// LEVEL CLASS
// ============================================================================

export class Level {
    constructor() {
        // Dimensions
        this.width = 0;   // In tiles
        this.height = 0;

        // Tile data (flat array, row-major)
        this.tiles = [];

        // Hazards
        this.hazards = [];

        // Spawn point
        this.spawnX = 0;
        this.spawnY = 0;

        // Goal
        this.goalRect = { x: 0, y: 0, width: 0, height: 0 };

        // Visual data
        this.backgroundColor = { r: 25, g: 25, b: 40 };

        // Metadata
        this.name = "Unnamed Level";
        this.parTime = 30.0;
    }

    getTile(x, y) {
        if (x < 0 || x >= this.width) return TileType.SOLID;
        if (y < 0 || y >= this.height) return TileType.EMPTY;

        const index = y * this.width + x;
        return this.tiles[index] || TileType.EMPTY;
    }

    setTile(x, y, tile) {
        if (x < 0 || x >= this.width) return;
        if (y < 0 || y >= this.height) return;

        const index = y * this.width + x;
        this.tiles[index] = tile;
    }
}

// ============================================================================
// LEVEL QUERIES
// ============================================================================

export function isSolidTile(level, x, y) {
    if (x < 0 || x >= level.width) return true;   // Out of bounds = solid (walls)
    if (y < 0) return true;                        // Ceiling
    if (y >= level.height) return false;           // No floor below level

    const index = y * level.width + x;
    return level.tiles[index] === TileType.SOLID;
}

export function getTile(level, x, y) {
    if (x < 0 || x >= level.width) return TileType.SOLID;
    if (y < 0 || y >= level.height) return TileType.EMPTY;

    const index = y * level.width + x;
    return level.tiles[index] || TileType.EMPTY;
}

// ============================================================================
// JSON LEVEL LOADING
// ============================================================================

export function loadLevel(jsonString) {
    try {
        const data = JSON.parse(jsonString);
        const level = new Level();

        // Metadata
        level.name = data.name || "Unnamed Level";
        level.parTime = data.par_time || 30.0;

        // Dimensions
        level.width = data.width || 40;
        level.height = data.height || 23;

        // Allocate tiles (initialize to empty)
        const tileCount = level.width * level.height;
        level.tiles = new Array(tileCount).fill(TileType.EMPTY);

        // Parse tile grid
        if (data.tiles && Array.isArray(data.tiles)) {
            for (let y = 0; y < data.tiles.length && y < level.height; y++) {
                const row = data.tiles[y];
                if (Array.isArray(row)) {
                    for (let x = 0; x < row.length && x < level.width; x++) {
                        const index = y * level.width + x;
                        level.tiles[index] = row[x];
                    }
                }
            }
        }

        // Parse spawn point
        if (data.spawn) {
            level.spawnX = (data.spawn.x || 2) * TILE_SIZE + TILE_SIZE / 2;
            level.spawnY = (data.spawn.y || 2) * TILE_SIZE + TILE_SIZE / 2;
        } else {
            level.spawnX = 2 * TILE_SIZE + TILE_SIZE / 2;
            level.spawnY = 2 * TILE_SIZE + TILE_SIZE / 2;
        }

        // Parse goal
        if (data.goal) {
            level.goalRect = {
                x: (data.goal.x || 38) * TILE_SIZE,
                y: (data.goal.y || 20) * TILE_SIZE,
                width: (data.goal.width || 2) * TILE_SIZE,
                height: (data.goal.height || 2) * TILE_SIZE
            };
        }

        // Parse hazards
        if (data.hazards && Array.isArray(data.hazards)) {
            for (const hazard of data.hazards) {
                level.hazards.push({
                    x: (hazard.x || 0) * TILE_SIZE,
                    y: (hazard.y || 0) * TILE_SIZE,
                    width: (hazard.width || 1) * TILE_SIZE,
                    height: (hazard.height || 1) * TILE_SIZE
                });
            }
        }

        // Background color
        if (data.background_color && Array.isArray(data.background_color) && data.background_color.length >= 3) {
            level.backgroundColor = {
                r: data.background_color[0],
                g: data.background_color[1],
                b: data.background_color[2]
            };
        }

        console.log(`Level loaded: ${level.name} (${level.width}x${level.height})`);
        console.log(`  Spawn: (${level.spawnX}, ${level.spawnY})`);
        console.log(`  Hazards: ${level.hazards.length}`);

        return level;

    } catch (e) {
        console.log("ERROR: Failed to parse level JSON: " + e);
        return null;
    }
}

// ============================================================================
// DEFAULT LEVEL (Fallback if JSON fails)
// ============================================================================

export function createDefaultLevel() {
    const level = new Level();

    level.name = "Default Level";
    level.width = 40;
    level.height = 23;
    level.parTime = 15.0;

    // Allocate tiles
    const tileCount = level.width * level.height;
    level.tiles = new Array(tileCount).fill(TileType.EMPTY);

    // Create floor
    for (let x = 0; x < level.width; x++) {
        level.setTile(x, level.height - 1, TileType.SOLID);
        level.setTile(x, level.height - 2, TileType.SOLID);
    }

    // Create walls
    for (let y = 0; y < level.height; y++) {
        level.setTile(0, y, TileType.SOLID);
        level.setTile(level.width - 1, y, TileType.SOLID);
    }

    // Some platforms
    for (let x = 5; x <= 10; x++) {
        level.setTile(x, 18, TileType.SOLID);
    }
    for (let x = 15; x <= 20; x++) {
        level.setTile(x, 15, TileType.SOLID);
    }
    for (let x = 25; x <= 30; x++) {
        level.setTile(x, 12, TileType.SOLID);
    }

    // Wall for wall jumping
    for (let y = 5; y <= 17; y++) {
        level.setTile(33, y, TileType.SOLID);
    }

    // Spawn
    level.spawnX = 3 * TILE_SIZE + TILE_SIZE / 2;
    level.spawnY = 20 * TILE_SIZE + TILE_SIZE / 2;

    // Goal
    level.goalRect = {
        x: 36 * TILE_SIZE,
        y: 4 * TILE_SIZE,
        width: 2 * TILE_SIZE,
        height: 2 * TILE_SIZE
    };

    // Hazards
    level.hazards.push({
        x: 12 * TILE_SIZE,
        y: 20 * TILE_SIZE,
        width: 3 * TILE_SIZE,
        height: 1 * TILE_SIZE
    });

    level.backgroundColor = { r: 25, g: 25, b: 40 };

    console.log("Created default level");

    return level;
}
