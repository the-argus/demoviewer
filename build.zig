const std = @import("std");
const builtin = @import("builtin");
const app_name = "demoviewer";

pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = app_name,
        .optimize = mode,
        .target = target,
        .root_source_file = std.Build.FileSource.relative("src/main.zig"),
    });

    switch (target.getOsTag()) {
        .windows => {
            exe.linkSystemLibrary("winmm");
            exe.linkSystemLibrary("gdi32");
            exe.linkSystemLibrary("opengl32");
        },
        //dunno why but macos target needs sometimes 2 tries to build
        .macos => {
            exe.linkSystemLibrary("Foundation");
            exe.linkSystemLibrary("Cocoa");
            exe.linkSystemLibrary("OpenGL");
            exe.linkSystemLibrary("CoreAudio");
            exe.linkSystemLibrary("CoreVideo");
            exe.linkSystemLibrary("IOKit");
        },
        .linux => {
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("rt");
            exe.linkSystemLibrary("dl");
            exe.linkSystemLibrary("m");
            exe.linkSystemLibrary("X11");
        },
        else => {},
    }

    const clap = b.createModule(.{
        .source_file = .{ .path = "./libs/zig-clap/clap.zig" },
        .dependencies = &.{},
    });

    exe.addModule("clap", clap);

    b.installArtifact(exe);
}
