const std = @import("std");
const valve_types = @import("valve_types.zig");

const DemoReadError = error{
    TooSmall,
    BadHeader,
    EarlyTermination,
    InvalidDemoMessage,
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

    std.debug.print("header length: {any}, control_header length: {any}\n", .{ header.header.len, control_header.len });
    for (header.header, control_header) |header_char, control_char| {
        if (header_char != control_char) {
            return DemoReadError.BadHeader;
        }
    }
}

pub fn read_command_header(file: std.fs.File, cmd: *valve_types.demo_messages, tick: *i32) !void {
    // first read into cmd
    {
        var buf: [1]u8 = undefined;
        const bytes_read = try file.read(cmd);

        // handle i/o failure
        if (bytes_read <= 0) {
            std.debug.warn("Missing end tag in demo file.\n");
            cmd.* = .dem_stop;
            return;
        }

        // get actual demo value
        var valid_demo_message = false;
        for (std.enums.values(valve_types.demo_messages)) |message_type| {
            if (buf[0] == @enumToInt(message_type)) {
                cmd.* = message_type;
                valid_demo_message = true;
                break;
            }
        }
        // err on failure
        if (!valid_demo_message) {
            return DemoReadError.InvalidDemoMessage;
        }
    }

    // now read the tick
    var buf: [@sizeOf(i32)]u8 = undefined;
    const bytes_read = file.read(&buf);
    if (bytes_read <= 0) {
        return DemoReadError.EarlyTermination;
    }
    tick.* = @bitCast(i32, buf);
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

    // const info : valve_types.DemoCommandInfo = undefined;
    process_demo: while (true) {
        var tick: i32 = 0;
        var cmd: [1]u8 = undefined;
        swallowing_messages: while (true) {
            try read_command_header(demo_file, &cmd, &tick);

            switch (cmd) {
                .dem_synctick => {
                    break;
                },
                .dem_stop => {
                    break :process_demo;
                },
                .dem_consolecmd => {
                    // TODO: read console command
                },
                .dem_datatables => {
                    // TODO: read network data tables (basically jus a seek)
                },
                .dem_usercmd => {
                    // TODO: readnetworkdatatables (also just a seek)
                },
                else => {
                    break :swallowing_messages;
                },
            }
        }

        // TODO: implement the smoothing reading stuff (basically the default case)
    }
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
