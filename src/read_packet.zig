//
// This code is ripped from engine/cl_demo.cpp in the tf2 source code
// Basically it reads a section of a demo which is of unknown size
// (hence the while loop)
//

const std = @import("std");
const valve_types = @import("valve_types.zig");
const reads = @import("demo_sections.zig");
const log = std.log.scoped(.demoviewer);

pub const NetPacketReadError = error{
    StopPacket,
};

fn print_vec(str: []const u8, v: valve_types.Vector) void {
    log.info("{s}X: {}\tY: {}\tZ: {}", .{ str, v.x, v.y, v.z });
}

pub fn read_packet(file: std.fs.File) !valve_types.NetPacket {
    var last_command_header: valve_types.CommandHeader = undefined;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    while (true) {
        const header_read = try reads.read_command_header(file);
        last_command_header = header_read.unwrap();
        // normally here there are checks for a bunch of member variables of
        // CDemoPlayer. in this case I don't want to allow for configuring the
        // reading of packets via state in a type, I would prefer an "options"
        // input to this function.

        if (!try perform_reads(file, allocator, last_command_header.message)) {
            break;
        }
    }

    const cmd_info = (try reads.read_command_info(file)).unwrap();
    _ = try reads.read_sequence_info(file);

    print_vec("view origin\t\t", cmd_info.view_origin);
    print_vec("view origin 2\t\t", cmd_info.view_origin_2);
    print_vec("view angles\t\t", cmd_info.view_angles);
    print_vec("view angles 2\t\t", cmd_info.view_angles_2);
    print_vec("local view angles\t", cmd_info.local_view_angles);
    print_vec("local view angles 2\t", cmd_info.local_view_angles_2);

    // FIXME: undefined behavior!! not all fields of packets are initialized
    var packet: valve_types.NetPacket = undefined;
    // TODO: figure out time in zig, fill recieved field
    // packet.received = (try std.time.Instant.now()).timestamp;
    const packet_read_results = try reads.read_raw_data(file, allocator);
    allocator.free(packet_read_results.payload);

    return packet;
}

/// based on a demo command, return whether or not you should continue reading.
fn perform_reads(file: std.fs.File, allocator: std.mem.Allocator, cmd: valve_types.demo_messages) !bool {
    switch (cmd) {
        .dem_synctick => {
            // do NOTHING lol
            // nah this originally was a thing that modified a member variable of
            // CDemoPlayer, but its not relevant to reading packets. might need to
            // be implemented later
        },
        .dem_stop => {
            return NetPacketReadError.StopPacket;
        },
        .dem_consolecmd => {
            const console_command = try reads.read_console_command(file, allocator);
            allocator.free(console_command.unwrap());
        },
        .dem_datatables => {
            const network_datatables = try reads.read_network_datatables(file, allocator);
            allocator.free(network_datatables.unwrap());
        },
        .dem_stringtables => {
            const stringtables = try reads.read_raw_data(file, allocator);
            allocator.free(stringtables.unwrap());
        },
        .dem_usercmd => {
            const user_command = try reads.read_user_cmd(file, allocator);
            user_command.unwrap().free_with(allocator);
        },
        else => {
            return false;
        },
    }
    return true;
}
