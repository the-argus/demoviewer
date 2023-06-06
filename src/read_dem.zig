const std = @import("std");
const valve_types = @import("valve_types.zig");

const demo_debug = @import("demo_debug.zig");
const DemoReadError = demo_debug.DemoReadError;
const assert_header_good = demo_debug.assert_header_good;
const print_demo_header = demo_debug.print_demo_header;

const read_packet = @import("read_packet.zig").read_packet;

const log = std.log.scoped(.demoviewer);

pub fn read_dem(relative_path: []const u8, allocator: std.mem.Allocator) !void {
    const demo_file = try std.fs.cwd().openFile(relative_path, .{});
    defer demo_file.close();

    const header_size = @sizeOf(valve_types.DemoHeader);
    var header: [header_size]u8 = undefined;
    const bytes_read_for_header = try demo_file.read(&header);
    if (bytes_read_for_header != header_size) {
        return DemoReadError.EarlyTermination;
    }

    const real_header = @bitCast(valve_types.DemoHeader, header);
    try assert_header_good(real_header, allocator);
    print_demo_header(real_header);

    while (true) {
        _ = try read_packet(demo_file);
    }
}
