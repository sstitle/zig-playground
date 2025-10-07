const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zig_playground",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Use system GLFW instead of bundled version
    exe.linkSystemLibrary("glfw");
    exe.linkLibC();

    // Add system frameworks for macOS
    if (target.result.os.tag == .macos) {
        // Add Homebrew paths
        exe.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/glfw/lib" });
        exe.addIncludePath(.{ .cwd_relative = "/usr/local/opt/glfw/include" });

        // Add SDK framework paths - check both Nix and system locations
        const sdk_path = "/nix/store/5gfsv5n8zhpnl9yhggjpxrxg0jyflwja-apple-sdk-11.3/Platforms/MacOSX.platform/Developer/SDKs/MacOSX11.3.sdk";
        const framework_path = b.fmt("{s}/System/Library/Frameworks", .{sdk_path});
        exe.addFrameworkPath(.{ .cwd_relative = framework_path });

        exe.linkFramework("Cocoa");
        exe.linkFramework("IOKit");
        exe.linkFramework("CoreVideo");
        exe.linkFramework("OpenGL");
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
