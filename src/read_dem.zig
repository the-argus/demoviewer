const std = @import("std");
const valve_types = @import("valve_types.zig");

const demo_debug = @import("demo_debug.zig");
const DemoReadError = demo_debug.DemoReadError;
const assert_header_good = demo_debug.assert_header_good;
const print_demo_header = demo_debug.print_demo_header;

const read_packet = @import("read_packet.zig").read_packet;

const log = std.log.scoped(.demoviewer);

pub fn read_dem(relative_path: []const u8, allocator: std.mem.Allocator) !void {
    const demo_file = try open_demo(relative_path);
    const header = try read_header(demo_file);
    try assert_header_good(header, allocator);
    print_demo_header(header);
    try read_all_packets(demo_file);
}

pub fn open_demo(relative_path: []const u8) !std.fs.File {
    return std.fs.cwd().openFile(relative_path, .{});
}

pub fn read_header(file: std.fs.File) !valve_types.DemoHeader {
    const header_size = @sizeOf(valve_types.DemoHeader);
    var header: [header_size]u8 = undefined;
    const bytes_read_for_header = try file.read(&header);
    if (bytes_read_for_header != header_size) {
        return DemoReadError.EarlyTermination;
    }

    return @bitCast(valve_types.DemoHeader, header);
}

pub fn get_slice_from_cstring(cstr: []const u8) []const u8 {
    const nullbyte = std.mem.indexOfScalar(u8, cstr, 0);
    if (nullbyte) |index| {
        return cstr[0..index];
    }
    return cstr;
}

pub fn read_all_packets(file: std.fs.File) !void {
    while (true) {
        _ = try read_packet(file);
    }
}
