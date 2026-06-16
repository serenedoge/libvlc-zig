const std = @import("std");

pub fn build(b: *std.Build) void {
    if (comptime !checkVersion())
        @compileError("Please! Update zig toolchain >= 0.11!");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const examples = b.option(
        []const u8,
        "Example",
        "Build example: [print-version, cliPlayer-(c,cpp,zig)]",
    ) orelse "print-version";

    if (std.mem.eql(u8, examples, "print-version"))
        make_example(b, .{
            .sdl_enabled = false,
            .filetype = .zig,
            .mode = optimize,
            .target = target,
            .name = "print_version",
            .path = "examples/print_version.zig",
        });

    if (std.mem.eql(u8, examples, "cliPlayer-zig"))
        make_example(b, .{
            .sdl_enabled = false,
            .filetype = .zig,
            .mode = optimize,
            .target = target,
            .name = "cliPlayer-zig",
            .path = "examples/cli_player.zig",
        });

    if (std.mem.eql(u8, examples, "cliPlayer-c"))
        make_example(b, .{
            .sdl_enabled = false,
            .filetype = .c,
            .mode = optimize,
            .target = target,
            .name = "cliPlayer-c",
            .path = "c_examples/cli_player.c",
        });

    if (std.mem.eql(u8, examples, "cliPlayer-cpp"))
        make_example(b, .{
            .sdl_enabled = false,
            .filetype = .cpp,
            .mode = optimize,
            .target = target,
            .name = "cliPlayer-cpp",
            .path = "c_examples/cli_player.cpp",
        });
}

fn make_example(b: *std.Build, info: BuildInfo) void {
    const example = switch (info.filetype) {
        .c, .cpp => b.addExecutable(.{
            .name = info.name,
            .root_module = b.createModule(.{
                .target = info.target,
                .optimize = info.mode,
            }),
        }),
        else => b.addExecutable(.{
            .name = info.name,
            .root_module = b.createModule(.{
                .target = info.target,
                .optimize = info.mode,
                .root_source_file = b.path(info.path), // Updated path handling
            }),
        }),
    };

    if (info.mode != .Debug and info.mode != .ReleaseSafe) {
        example.root_module.strip = true;
        example.root_module.sanitize_c = .off;
    }

    // Created module explicitly instead of using anonymous module mapping
    const vlc_mod = b.createModule(.{
        .root_source_file = b.path("src/vlc.zig"),
    });
    // 2. Feed the header search paths directly to the module!
    if (info.target.result.os.tag == .macos) {
        vlc_mod.addIncludePath(.{ .cwd_relative = "/Applications/VLC.app/Contents/MacOS/include" });
        vlc_mod.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
    } else if (info.target.result.os.tag == .windows) {
        vlc_mod.addIncludePath(.{ .cwd_relative = msys2Inc(info.target) });
    }
    example.root_module.addImport("vlc", vlc_mod);

    if (info.filetype == .c or info.filetype == .cpp) {
        example.root_module.addCSourceFile(.{ .file = b.path(info.path), .flags = &.{ "-Wall", "-Werror", "-Wextra" } });
    }

    if (info.sdl_enabled) {
        const libsdl_dep = b.dependency("libsdl", .{
            .target = info.target,
            .optimize = info.mode,
        });
        const libsdl = libsdl_dep.artifact("sdl");
        example.root_module.linkLibrary(libsdl);
    }

    if (info.filetype == .cpp) {
        example.root_module.addIncludePath(b.path("zig-out/include"));
    }

    // Checking OS types requires reading .result.os.tag directly now
    if (info.target.result.os.tag == .macos) {
        example.root_module.addIncludePath(.{ .cwd_relative = "/Applications/VLC.app/Contents/MacOS/include" });
        example.root_module.addLibraryPath(.{ .cwd_relative = "/Applications/VLC.app/Contents/MacOS/lib" });

        example.root_module.linkFramework("Foundation", .{});
        example.root_module.linkFramework("Cocoa", .{});
        example.root_module.linkFramework("IOKit", .{});
        example.root_module.linkSystemLibrary("vlc", .{});
    } else if (info.target.result.os.tag == .windows) {
        example.root_module.addIncludePath(.{ .cwd_relative = msys2Inc(info.target) });
        example.root_module.addLibraryPath(.{ .cwd_relative = msys2Lib(info.target) });
        example.root_module.linkSystemLibrary("vlc.dll", .{});
        example.lto = .none;
    } else {
        example.root_module.linkSystemLibrary("vlc", .{});
    }

    if (info.filetype == .cpp) {
        example.root_module.link_libcpp = true;
    } else {
        example.root_module.link_libc = true;
    }

    b.installArtifact(example);

    const run_cmd = b.addRunArtifact(example);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const descr = b.fmt("Run the {s} example", .{info.name});
    const run_step = b.step("run", descr);
    run_step.dependOn(&run_cmd.step);
}

fn checkVersion() bool {
    const builtin = @import("builtin");
    if (!@hasDecl(builtin, "zig_version")) {
        return false;
    }

    const needed_version = std.SemanticVersion.parse("0.11.0") catch unreachable;
    const version = builtin.zig_version;
    const order = version.order(needed_version);
    return order != .lt;
}

const BuildInfo = struct {
    sdl_enabled: bool,
    filetype: SourceType,
    mode: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget, // Updated Target Struct type
    name: []const u8,
    path: []const u8,
};

const SourceType = enum(u32) {
    zig,
    c,
    cpp,
};

fn msys2Inc(target: std.Build.ResolvedTarget) []const u8 {
    return switch (target.result.cpu.arch) {
        .x86_64 => "D:/msys64/clang64/include",
        .aarch64 => "D:/msys64/clangarm64/include",
        else => "D:/msys64/clang32/include",
    };
}

fn msys2Lib(target: std.Build.ResolvedTarget) []const u8 {
    return switch (target.result.cpu.arch) {
        .x86_64 => "D:/msys64/clang64/lib",
        .aarch64 => "D:/msys64/clangarm64/lib",
        else => "D:/msys64/clang32/lib",
    };
}

pub fn module(b: *std.Build) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path("src/vlc.zig"),
    });
}
