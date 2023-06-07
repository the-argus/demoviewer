//
// This file contains functions for reading different sections of a demo file.
// TODO: refactor a lot of the shitty "out" reference variables and inconsistent
// return types carried over from copying from the tf2 source code.
//

const std = @import("std");
const builtin = @import("builtin");
const valve_types = @import("valve_types.zig");

const demo_debug = @import("demo_debug.zig");
const print_packet = demo_debug.print_packet;
const DemoReadError = demo_debug.DemoReadError;

const log = std.log.scoped(.demoviewer);

pub fn ReadResults(comptime T: type) type {
    return struct {
        payload: T,
        amount_read: usize,

        pub fn unwrap(self: @This()) T {
            return self.payload;
        }
    };
}

pub fn read_command_header(file: std.fs.File) !ReadResults(valve_types.CommandHeader) {
    log.debug("Reading command header...", .{});
    var res: ReadResults(valve_types.CommandHeader) = undefined;
    res.payload.tick = 0;
    res.amount_read = 0;
    // first read into cmd
    {
        var buf: [1]u8 = undefined;
        const bytes_read = try file.read(&buf);
        res.amount_read += bytes_read;

        // handle i/o failure
        if (bytes_read <= 0) {
            log.warn("Missing end tag in demo file.\n", .{});
            res.payload.message = .dem_stop;
            return res;
        }

        // get actual demo value
        var valid_demo_message = false;
        for (std.enums.values(valve_types.demo_messages)) |message_type| {
            if (buf[0] == @enumToInt(message_type)) {
                res.payload.message = message_type;
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
    res.payload.tick = @bitCast(i32, buf);
    res.amount_read += bytes_read;
    return res;
}

/// Recieve a file and read an amount into the buffer. return amount read
pub fn read_raw_data(file: std.fs.File, allocator: std.mem.Allocator) !ReadResults([]u8) {
    log.debug("Reading raw data...", .{});
    var res: ReadResults([]u8) = undefined;
    res.amount_read = 0;
    // first get the size of the data packet
    // FIXME: low-prio, but there could be bugs/buffer overwrite if there is
    // integer overflow when reading the size from the heading of the raw data
    var size_buffer: [@sizeOf(i32)]u8 = undefined;
    var bytes_read = try file.read(&size_buffer);
    res.amount_read += bytes_read;
    if (bytes_read < @sizeOf(i32)) {
        return DemoReadError.EarlyTermination;
    }
    const size = @bitCast(i32, size_buffer);
    log.debug("Raw data expected size: {any}", .{size});
    if (size < 0) {
        return DemoReadError.Corruption;
    }

    var buf = try allocator.alloc(u8, @intCast(usize, size));
    bytes_read = try file.read(buf);
    res.amount_read += bytes_read;
    if (bytes_read != size) {
        allocator.free(buf);
        return DemoReadError.FileDoesNotMatchPromised;
    }
    log.debug("Bytes of raw data read match expected.", .{});
    res.payload = buf;

    return res;
}

pub fn read_console_command(file: std.fs.File, allocator: std.mem.Allocator) ![]u8 {
    log.debug("Reading console command...", .{});
    const cmd = try read_raw_data(file, allocator);
    return cmd.payload;
}

pub fn read_sequence_info(file: std.fs.File, sequence_number_in: ?*i32, sequence_number_out: ?*i32) !void {
    log.debug("Reading sequence info...", .{});
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
    log.debug("Reading command info...", .{});
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
    log.debug("Reading network data tables...", .{});
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
        log.debug(
            \\Read expected size {any} bytes from network datatables header
            \\Coerced to usize of {any}
            \\
        , .{ int_size, size });
    }

    var bytes_read: usize = 0;
    while (size > 0) {
        const chunk: usize = std.math.min(size, 1024);
        const slice: []u8 = data[0..chunk];
        bytes_read += try file.read(slice);
        size -= chunk;
        // TODO: add an "out" argument to this function, write to it here.
        // needs to be some sort of IO stream to allow continuous writing.
    }
    log.debug("Actual amount of bytes read from network data tables: {any}\n", .{bytes_read});

    return size;
}

pub const UserCommand = struct {
    outgoing_sequence: i32,
    payload: []u8,
};
pub fn read_user_cmd(file: std.fs.File, allocator: std.mem.Allocator) !UserCommand {
    log.debug("Reading user command...", .{});
    var res: UserCommand = undefined;
    {
        var buf: [@sizeOf(i32)]u8 = undefined;
        const bytes_read = try file.read(&buf);
        if (bytes_read < buf.len) {
            return DemoReadError.EarlyTermination;
        }
        res.outgoing_sequence = @bitCast(i32, buf);
    }
    const read_results = try read_raw_data(file, allocator);
    res.payload = read_results.payload;
    return res;
}
