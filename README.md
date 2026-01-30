# Jai Meatboy - Super Meat Boy Style Platformer

A tight, responsive 2D platformer written in Jai, targeting Android ARM64.

## Features

- **Super Meat Boy-style controls**
  - Instant acceleration (no floaty movement)
  - High air control
  - Wall sliding and wall jumping
  - Variable jump height (release to cut jump short)
  - Coyote time (jump grace period after leaving platform)
  - Jump buffering (queue jump before landing)

- **Android ARM64 native**
  - Pure NativeActivity (no Java)
  - OpenGL ES 3.0 rendering
  - Touch controls with virtual D-pad
  - Internet and file system permissions

- **JSON level loading**
  - Tile-based collision
  - Hazards (instant death)
  - Spawn points and goals
  - Easily create new levels

## Project Structure

```
jai-meatboy-android/
├── src/
│   ├── main.jai           # Entry point, Android setup
│   ├── game.jai           # Game state, core logic
│   ├── player.jai         # Player controller (SMB-style)
│   ├── level.jai          # Level loading from JSON
│   ├── renderer.jai       # OpenGL ES 3.0 batch renderer
│   ├── physics.jai        # Collision utilities
│   └── input_handler.jai  # Touch & keyboard input
├── assets/
│   └── levels/
│       └── level1.json    # First level
├── android/
│   └── AndroidManifest.xml
├── build.jai              # Build configuration
├── package_apk.sh         # APK packaging script
└── README.md
```

## Prerequisites

### For Desktop Testing
- Jai compiler (beta access required)
- OpenGL 3.3+ capable GPU

### For Android
- Jai compiler with cross-compilation support
- Android NDK r21+ (for ARM64)
- Android SDK with build-tools 34+
- Java JDK (for APK signing)

## Building

### Desktop (for testing)

```bash
# Debug build
jai build.jai

# Release build
jai build.jai - release

# Run
./build/desktop/meatboy
```

### Android ARM64

```bash
# Build native library
jai build.jai - android

# Package APK
chmod +x package_apk.sh
./package_apk.sh

# Install on device
adb install -r build/output/JaiMeatboy.apk
```

## Level Format

Levels are JSON files in `assets/levels/`:

```json
{
    "name": "Level Name",
    "par_time": 15.0,
    "width": 40,
    "height": 23,
    
    "spawn": { "x": 3, "y": 19 },
    "goal": { "x": 36, "y": 3, "width": 2, "height": 3 },
    
    "background_color": [25, 25, 40],
    
    "tiles": [
        [1, 1, 1, ...],  // 1 = solid, 0 = empty
        ...
    ],
    
    "hazards": [
        { "x": 6, "y": 20, "width": 3, "height": 1 },
        ...
    ]
}
```

### Tile Types
- `0` - Empty (air)
- `1` - Solid (collision)
- `2` - One-way platform (planned)

## Controls

### Desktop
- **Arrow Keys / WASD** - Move
- **Space / Z / Up** - Jump
- **Escape** - Pause
- **Ctrl+Q** - Quit

### Android (Touch)
- **Left side** - Virtual D-pad (drag to move)
- **Right side** - Jump button
- **Back button** - Pause

## Game Mechanics

### Movement
| Parameter | Value | Description |
|-----------|-------|-------------|
| Move Speed | 280 | Horizontal velocity |
| Jump Force | 420 | Initial jump velocity |
| Gravity | 1200 | Base gravity |
| Fast Fall | 1.5x | Gravity multiplier when falling |
| Max Fall | 600 | Terminal velocity |

### Wall Mechanics
| Parameter | Value | Description |
|-----------|-------|-------------|
| Wall Slide Speed | 80 | Max slide velocity |
| Wall Jump X | 320 | Horizontal boost |
| Wall Jump Y | 380 | Vertical boost |
| Wall Cooldown | 0.15s | Time before re-grab |

### Timing Helpers
| Feature | Window | Description |
|---------|--------|-------------|
| Coyote Time | 80ms | Jump after leaving edge |
| Jump Buffer | 100ms | Queue jump before landing |
| Respawn Time | 500ms | Death to respawn |

## Android Permissions

The app requests:
- **INTERNET** - For future online features
- **READ/WRITE_EXTERNAL_STORAGE** - Save files, custom levels
- **WAKE_LOCK** - Keep screen on during play

## Architecture Notes

### Why Jai?
- Zero-cost abstractions
- Compile-time execution
- No garbage collector
- Direct memory control
- Fast iteration times

### Rendering
- Batch renderer for efficiency
- Single draw call per frame (typically)
- Colored quads (no textures yet)
- Camera with smooth follow and screen shake

### Physics
- Fixed timestep (60 FPS)
- Tile-based collision
- AABB overlap detection
- Sweep collision for tunneling prevention

## TODO

- [ ] Sprite-based rendering
- [ ] Particle effects polish
- [ ] Sound effects
- [ ] Music
- [ ] More levels
- [ ] Level editor
- [ ] Leaderboards
- [ ] Replays

## License

MIT License - See LICENSE file

## Credits

Inspired by:
- Super Meat Boy (Team Meat)
- Celeste (Matt Makes Games)
- N++ (Metanet Software)
