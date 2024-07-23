const std = @import("std");
const cruces = @import("cruces");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const version = try cruces.getVersion();

    try stdout.print("Cruces: Version: {}\n", .{version});
    try bw.flush();

    cruces.run_app();
}
