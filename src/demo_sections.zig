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

const demoviewer_io = @import("io.zig");
const readObject = demoviewer_io.readObject;
const readObjectDirectOut = demoviewer_io.readObjectDirectOut;

const log = std.log.scoped(.demoviewer);

/// Reads the command that sits after the demo header and every packet, saying what comes next
pub fn read_command_header(file: std.fs.File) !valve_types.CommandHeader {
    log.debug("Reading command header...", .{});
    var result: valve_types.CommandHeader = undefined;
    result.tick = 0;
    result.message = .dem_signon;
    // first read into cmd
    {
        const buf = try readObject(file, [1]u8);

        // get actual demo value
        var valid_demo_message = false;
        // NOTE: this could be @intToEnum. it would be much
        // faster, although it would cause the program to panic when reading
        // invalid demos.
        for (std.enums.values(valve_types.demo_messages)) |message_type| {
            if (buf[0] == @enumToInt(message_type)) {
                result.message = message_type;
                valid_demo_message = true;
                break;
            }
        }
        if (result.message == .dem_stop) {
            log.info("Demo stopping code reached, exiting.", .{});
            std.os.exit(0);
        }
        // err on failure
        if (!valid_demo_message) {
            return DemoReadError.InvalidDemoMessage;
        }
    }

    // now read the tick
    result.tick = try readObject(file, i32);
    return result;
}

/// Recieve a file and read an amount into the buffer. return amount read
pub fn read_raw_data(file: std.fs.File, allocator: std.mem.Allocator) ![]u8 {
    log.debug("Reading raw data...", .{});
    // first get the size of the data packet
    // FIXME: low-prio, but there could be bugs/buffer overwrite if there is
    // integer overflow when reading the size from the heading of the raw data
    const size = try readObject(file, i32);

    log.debug("Raw data expected size: {any}", .{size});
    if (size < 0) {
        return DemoReadError.Corruption;
    }

    var buf = try allocator.alloc(u8, @intCast(usize, size));
    const bytes_read = try file.read(buf);
    if (bytes_read != buf.len) {
        allocator.free(buf);
        return DemoReadError.FileDoesNotMatchPromised;
    }
    log.debug("Bytes of raw data read match expected.", .{});

    return buf;
}

/// Equivalent to read_raw_data, at least for now
pub fn read_console_command(file: std.fs.File, allocator: std.mem.Allocator) ![]u8 {
    log.debug("Reading console command...", .{});
    return try read_raw_data(file, allocator);
}

pub const SequenceInfo = struct {
    sequence_number_in: i32,
    sequence_number_out: i32,
};
pub fn read_sequence_info(file: std.fs.File) !SequenceInfo {
    log.debug("Reading sequence info...", .{});

    var result: SequenceInfo = undefined;
    result.sequence_number_in = try readObject(file, i32);
    result.sequence_number_out = try readObject(file, i32);
    return result;
}

pub fn read_command_info(file: std.fs.File) !valve_types.DemoCommandInfo {
    log.debug("Reading command info...", .{});
    return try readObject(file, valve_types.DemoCommandInfo);
}

pub fn read_network_datatables(file: std.fs.File, allocator: std.mem.Allocator) ![]u8 {
    log.debug("Reading network data tables...", .{});
    var data_table_length = block: {
        const int_size = try .payloadreadObject(file, i32);
        if (int_size < 0) {
            return DemoReadError.Corruption;
        }
        const casted_size = @intCast(usize, int_size);
        log.debug(
            \\Read expected size {any} bytes from network datatables header
            \\Coerced to usize of {any}
            \\
        , .{ int_size, casted_size });
        break :block casted_size;
    };

    const result = try allocator.alloc(u8, data_table_length);
    const bytes_read = try file.read(result);
    if (bytes_read != data_table_length) {
        return DemoReadError.EarlyTermination;
    }

    return result;
}

pub const UserCommand = struct {
    outgoing_sequence: i32,
    command: []u8,
    pub fn free_with(self: @This(), allocator: std.mem.Allocator) void {
        allocator.free(self.command);
    }
};

pub fn read_user_cmd(file: std.fs.File, allocator: std.mem.Allocator) !UserCommand {
    log.debug("Reading user command...", .{});
    var result: UserCommand = undefined;
    result.outgoing_sequence = try readObject(file, i32);
    result.command = try read_raw_data(file, allocator);
    return result;
}
