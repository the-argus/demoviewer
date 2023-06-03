const std = @import("std");
const valve_types = @import("valve_types.zig");

const DemoReadError = error{
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

pub fn read_command_header(file: std.fs.File, cmd: *valve_types.demo_messages, tick: *i32) !void {
    // first read into cmd
    {
        var buf: [1]u8 = undefined;
        const bytes_read = try file.read(&buf);

        // handle i/o failure
        if (bytes_read <= 0) {
            std.debug.print("Missing end tag in demo file.\n", .{});
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
    const bytes_read = try file.read(&buf);
    if (bytes_read <= 0) {
        return DemoReadError.EarlyTermination;
    }
    tick.* = @bitCast(i32, buf);
}

/// Recieve a file and read an amount into the buffer. return amount read
pub fn read_raw_data(file: std.fs.File, opt_buffer: ?*[]u8) !i32 {
    // first get the size of the data packet
    var size_buffer: [@sizeOf(i32)]u8 = undefined;
    var bytes_read = try file.read(&size_buffer);
    if (bytes_read < @sizeOf(i32)) {
        return DemoReadError.EarlyTermination;
    }
    const size = @bitCast(i32, size_buffer);

    // try to read that size into the buffer
    if (opt_buffer) |buffer| {
        if (buffer.len < size) {
            return DemoReadError.NotEnoughMemory;
        }

        bytes_read = try file.read(buffer.*);
        if (bytes_read != size) {
            return DemoReadError.FileDoesNotMatchPromised;
        }
    } else {
        // skip the promised packet
        file.seekBy(size) catch {
            return DemoReadError.EarlyTermination;
        };
    }

    return size;
}

pub fn read_console_command(file: std.fs.File, out: ?*[1024]u8) !void {
    var buf: [1024]u8 = undefined;
    var alt: []u8 = &buf;
    _ = try read_raw_data(file, &alt);
    if (out) |out_ptr| {
        @memcpy(out_ptr, &buf);
    }
}

pub fn read_sequence_info(file: std.fs.File, sequence_number_in: ?*i32, sequence_number_out: ?*i32) !void {
    var buf: [@sizeOf(i32)]u8 = undefined;

    var bytes_read = try file.read(&buf);
    if (bytes_read < buf.len) {
        return DemoReadError.EarlyTermination;
    }
    if (sequence_number_in) |in| {
        in.* = @bitCast(i32, buf);
    }

    bytes_read = try file.read(&buf);
    if (bytes_read < buf.len) {
        return DemoReadError.EarlyTermination;
    }
    if (sequence_number_out) |out| {
        out.* = @bitCast(i32, buf);
    }
}

pub fn read_command_info(file: std.fs.File, command_info: ?*valve_types.DemoCommandInfo) !void {
    var buf: [@sizeOf(valve_types.DemoCommandInfo)]u8 = undefined;
    const bytes_read = try file.read(&buf);
    if (bytes_read < buf.len) {
        return DemoReadError.EarlyTermination;
    }
    if (command_info) |info| {
        info.* = @bitCast(valve_types.DemoCommandInfo, buf);
    }
}

pub fn read_network_datatables(file: std.fs.File) !usize {
    var data: [1024]u8 = undefined;
    var size: usize = undefined;
    {
        var buf: [@sizeOf(i32)]u8 = undefined;
        _ = try file.read(&buf);
        const int_size = @bitCast(i32, buf);
        if (int_size < 0) {
            return DemoReadError.Corruption;
        }
        size = @intCast(usize, int_size);
    }

    while (size > 0) {
        const chunk: usize = std.math.min(size, 1024);
        const slice: []u8 = data[0..chunk];
        _ = try file.read(slice);
        size -= chunk;
        // TODO: add an "out" argument to this function, write to it here.
        // needs to be some sort of IO stream to allow continuous writing.
    }

    return size;
}

pub fn read_user_cmd(file: std.fs.File, opt_buffer: ?*[]u8) !i32 {
    var outgoing_sequence: i32 = undefined;
    {
        var buf: [@sizeOf(i32)]u8 = undefined;
        const bytes_read = try file.read(&buf);
        if (bytes_read < buf.len) {
            return DemoReadError.EarlyTermination;
        }
        outgoing_sequence = @bitCast(i32, buf);
    }
    if (opt_buffer) |buf| {
        _ = try read_raw_data(file, buf);
    }
    return outgoing_sequence;
}

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

    // const info : valve_types.DemoCommandInfo = undefined;
    process_demo: while (true) {
        var tick: i32 = 0;
        var cmd: valve_types.demo_messages = undefined;
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
                    try read_console_command(demo_file, null);
                },
                .dem_datatables => {
                    _ = try read_network_datatables(demo_file);
                },
                .dem_usercmd => {
                    _ = try read_user_cmd(demo_file, null);
                },
                else => {
                    break :swallowing_messages;
                },
            }
        }

        try read_command_info(demo_file, null);
        try read_sequence_info(demo_file, null, null);
        _ = try read_raw_data(demo_file, null);
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
