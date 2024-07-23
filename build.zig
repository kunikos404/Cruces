const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zon_file = "build.zig.zon";
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const file_data = readFile(&allocator, zon_file) catch {
        std.log.err("[build.build] unable to read data from file: {s}", .{zon_file});
        std.process.exit(1);
    };
    defer allocator.free(file_data);
    const version = getVersion(&allocator, file_data) catch {
        std.log.err("[build.build] unable to read version from data: {s}", .{file_data});
        std.process.exit(1);
    };
    defer allocator.free(version);

    const lib = b.addStaticLibrary(.{
        .name = "cruces",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const options = b.addOptions();
    options.addOption([]const u8, "version", version);
    lib.root_module.addOptions("config", options);

    const path = std.Build.LazyPath{ .cwd_relative = "/usr/include" };

    lib.addIncludePath(path);

    lib.linkLibC();
    lib.linkSystemLibrary("X11");
    lib.linkSystemLibrary("Xcomposite");
    lib.linkSystemLibrary("xfixes");
    lib.linkSystemLibrary("Xrandr");

    b.installArtifact(lib);

    b.installFile("src/cruces.zig", "include/cruses.zig");

    const exe = b.addExecutable(.{
        .name = "cruces",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addAnonymousImport("cruces", .{ .root_source_file = b.path("src/cruces.zig") });

    exe.linkLibrary(lib);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn readFile(allocator: *const std.mem.Allocator, file_name: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();
    const file_info = try file.stat();
    return try file.readToEndAlloc(allocator.*, file_info.size);
}

fn getVersion(allocator: *const std.mem.Allocator, string_data: []const u8) ![]const u8 {
    const start_pattern = ".version = \"";
    const end_pattern = "\"";

    const start_index = std.mem.indexOf(u8, string_data, start_pattern) orelse 0;
    const version_start = start_index + start_pattern.len;

    const end_index = std.mem.indexOf(u8, string_data[version_start..], end_pattern) orelse 0;
    const version_end = version_start + end_index;

    const version_len = version_end - version_start;
    const version_alloc = try allocator.alloc(u8, version_len);

    std.mem.copyForwards(u8, version_alloc, string_data[version_start..version_end]);
    return version_alloc;
}

const PackageInfo = struct {
    name: []const u8,
    version: []const u8,
    dependencies: std.StringHashMap(Dependency),
    paths: [][]const u8,
};
const Dependency = struct {
    url: []const u8,
    hash: []const u8,
    path: []const u8,
    lazy: bool,
};
