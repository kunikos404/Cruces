const std = @import("std");
pub extern fn run_app() void;
extern fn version() [*c]const u8;
pub fn getVersion() !std.SemanticVersion {
    const version_length = std.mem.len(version());
    return try std.SemanticVersion.parse(version()[0..version_length]);
}
