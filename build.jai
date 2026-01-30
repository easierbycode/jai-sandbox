// ============================================================================
// BUILD CONFIGURATION FOR JAI MEATBOY PLATFORMER
// ============================================================================
// Run with: jai build.jai
// Or for Android: jai build.jai - android
// ============================================================================

#import "Basic";
#import "Compiler";
#import "File";
#import "String";
#import "Process";

#run build();

build :: () {
    // Check command line for target
    args := get_build_options().compile_time_command_line;
    
    build_android := false;
    build_debug := true;
    
    for arg: args {
        if arg == "android" build_android = true;
        if arg == "release" build_debug = false;
    }
    
    if build_android {
        build_for_android(build_debug);
    } else {
        build_for_desktop(build_debug);
    }
}

// ============================================================================
// DESKTOP BUILD
// ============================================================================

build_for_desktop :: (debug: bool) {
    print("=== Building for Desktop ===\n");
    
    w := compiler_create_workspace("Desktop Build");
    
    options := get_build_options(w);
    options.output_executable_name = "meatboy";
    options.output_path = "build/desktop/";
    
    if debug {
        options.backend = .X64;  // Faster compilation
        set_optimization(*options, .DEBUG);
    } else {
        options.backend = .LLVM;
        set_optimization(*options, .OPTIMIZED);
    }
    
    // Add source files
    import_paths: [..] string;
    array_add(*import_paths, "src");
    options.import_path = import_paths;
    
    set_build_options(options, w);
    
    // Main entry point
    add_build_file("src/main.jai", w);
    
    print("Desktop build configured. Output: build/desktop/meatboy\n");
}

// ============================================================================
// ANDROID ARM64 BUILD
// ============================================================================

build_for_android :: (debug: bool) {
    print("=== Building for Android ARM64 ===\n");
    
    w := compiler_create_workspace("Android Build");
    
    options := get_build_options(w);
    options.output_executable_name = "libjaimeatboy";
    options.output_path = "build/android/lib/arm64-v8a/";
    options.output_type = .DYNAMIC_LIBRARY;
    
    // ARM64 cross-compilation
    options.backend = .LLVM;
    options.os_target = .ANDROID;
    options.cpu_target = .ARM64;
    
    if debug {
        set_optimization(*options, .DEBUG);
    } else {
        set_optimization(*options, .OPTIMIZED);
        options.llvm_options.code_gen_optimization_level = 3;
    }
    
    // Android NDK paths (adjust these to your NDK location)
    NDK_PATH :: "/opt/android-ndk";  // Or use environment variable
    API_LEVEL :: "24";
    
    // Add Android-specific import paths
    import_paths: [..] string;
    array_add(*import_paths, "src");
    options.import_path = import_paths;
    
    // Linker flags for Android
    options.additional_linker_arguments = .[
        "-llog",       // Android logging
        "-landroid",   // Native activity
        "-lEGL",       // EGL for OpenGL context
        "-lGLESv3",    // OpenGL ES 3.0
        "-lm",         // Math library
        "-lc",         // C standard library
        "--sysroot", tprint("%/toolchains/llvm/prebuilt/linux-x86_64/sysroot", NDK_PATH),
        "-L", tprint("%/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/%", NDK_PATH, API_LEVEL),
    ];
    
    set_build_options(options, w);
    
    // Main entry point
    add_build_file("src/main.jai", w);
    
    print("Android build configured.\n");
    print("Output: build/android/lib/arm64-v8a/libjaimeatboy.so\n");
    print("\nAfter building, run: ./package_apk.sh\n");
}

// ============================================================================
// HELPER TO SET OPTIMIZATION LEVEL
// ============================================================================

set_optimization :: (options: *Build_Options, level: enum { DEBUG; OPTIMIZED; }) {
    if level == .DEBUG {
        options.optimization_level = .DEBUG;
        options.array_bounds_check = .ON;
        options.cast_bounds_check = .FATAL;
        options.null_pointer_check = .ON;
        options.enable_backtrace = true;
    } else {
        options.optimization_level = .RELEASE;
        options.array_bounds_check = .OFF;
        options.cast_bounds_check = .OFF;
        options.null_pointer_check = .OFF;
        options.enable_backtrace = false;
    }
}
