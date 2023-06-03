const std = @import("std");
const valve_types = @import("valve_types.zig");

const demo_debug = @import("demo_debug.zig");
const print_packet = demo_debug.print_packet;
const DemoReadError = demo_debug.DemoReadError;

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
