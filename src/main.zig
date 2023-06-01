const std = @import("std");
const valve_types = @import("valve_types.zig");

const DemoReadError = error{
    TooSmall,
    BadHeader,
};

pub fn print_demo_header(demo_header: valve_types.DemoHeader) void {
    std.debug.print(
        \\Header: {s}
        \\Protocol: {any}
        \\Network Protocol: {any}
        \\Server Name: {s}
        \\Client Name: {s}
        \\Map Name: {s}
        \\Game Directory: {s}
        \\Playback Time: {any}
        \\Ticks: {any}
        \\Frames: {any}
        \\Signon Length: {any}
    , .{
        demo_header.header,
        demo_header.demo_protocol,
        demo_header.network_protocol,
        demo_header.server_name,
        demo_header.client_name,
        demo_header.map_name,
        demo_header.game_directory,
        demo_header.playback_time,
        demo_header.ticks,
        demo_header.frames,
        demo_header.signon_length,
    });
}

pub fn assert_header_good(header: valve_types.DemoHeader, allocator: std.mem.Allocator) !void {
    const hsize = header.header.len;
    const control_header = try allocator.alloc(u8, hsize);
    defer allocator.free(control_header);

    @memcpy(control_header, "HL2DEMO0");
    control_header[hsize - 1] = 0; // add null byte

    std.debug.print("header length: {any}, control_header length: {any}\n", .{ header.header.len, control_header.len });
    for (header.header, control_header) |header_char, control_char| {
        if (header_char != control_char) {
            return DemoReadError.BadHeader;
        }
    }
}

pub fn read_dem(relative_path: []const u8, allocator: std.mem.Allocator) !void {
    const demo_file = try std.fs.cwd().openFile(relative_path, .{});
    defer demo_file.close();

    const header_size = @sizeOf(valve_types.DemoHeader);
    var header: [header_size]u8 = undefined;
    const bytes_read_for_header = try demo_file.read(&header);
    if (bytes_read_for_header != header_size) {
        return DemoReadError.TooSmall;
    }

    const real_header = @bitCast(valve_types.DemoHeader, header);
    try assert_header_good(real_header, allocator);
    print_demo_header(real_header);

    std.debug.print("{any}\n", .{bytes_read_for_header});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 1) {
        try read_dem(args[1], allocator);
    }
}
