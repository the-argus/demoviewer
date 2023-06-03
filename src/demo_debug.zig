const std = @import("std");
const valve_types = @import("valve_types.zig");

pub const DemoReadError = error{
    BadHeader,
    Corruption,
    EarlyTermination,
    InvalidDemoMessage,
    NotEnoughMemory,
    FileDoesNotMatchPromised,
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
        \\
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

pub fn print_packet(packet: valve_types.Packet) void {
    std.debug.print(
        \\Found packet:
        \\  cmd_type: {any}
        \\  unknown: {any}
        \\  tickcount: {any}
        \\  size_of_packet: {any}
        \\  buffer pointer: {any}
        \\
    , .{
        packet.cmd_type,
        packet.unknown,
        packet.tickcount,
        packet.size_of_packet,
        packet.buffer,
    });
}

pub fn assert_header_good(header: valve_types.DemoHeader, allocator: std.mem.Allocator) !void {
    const hsize = header.header.len;
    const control_header = try allocator.alloc(u8, hsize);
    defer allocator.free(control_header);

    @memcpy(control_header, "HL2DEMO0");
    control_header[hsize - 1] = 0; // add null byte

    for (header.header, control_header) |header_char, control_char| {
        if (header_char != control_char) {
            return DemoReadError.BadHeader;
        }
    }
}
