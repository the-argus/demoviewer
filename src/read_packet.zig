//
// This code is ripped from engine/cl_demo.cpp in the tf2 source code
// Basically it reads a section of a demo which is of unknown size
// (hence the while loop)
//

const std = @import("std");
const valve_types = @import("valve_types.zig");
const reads = @import("demo_sections.zig");

pub const NetPacketReadError = error{
    StopPacket,
};

pub fn read_packet(file: std.fs.File) !valve_types.NetPacket {
    var last_command_header: valve_types.CommandHeader = undefined;

    while (true) {
        const header_read = try reads.read_command_header(file);
        last_command_header = header_read.unwrap();
        // normally here there are checks for a bunch of member variables of
        // CDemoPlayer. in this case I don't want to allow for configuring the
        // reading of packets via state in a type, I would prefer an "options"
        // input to this function.

        if (!try perform_reads(file, last_command_header.message)) {
            break;
        }
    }

    _ = try reads.read_command_info(file, null);
    try reads.read_sequence_info(file, null, null);

    // FIXME: undefined behavior!! not all fields of packets are initialized
    var packet: valve_types.NetPacket = undefined;
    // TODO: figure out time in zig, fill recieved field
    // packet.received = (try std.time.Instant.now()).timestamp;
    packet.size = try reads.read_raw_data(file, null);

    return packet;
}

/// based on a demo command, return whether or not you should continue reading.
fn perform_reads(file: std.fs.File, cmd: valve_types.demo_messages) !bool {
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
            try reads.read_console_command(file, null);
        },
        .dem_datatables => {
            _ = try reads.read_network_datatables(file);
        },
        .dem_stringtables => {
            _ = try reads.read_raw_data(file, null);
        },
        .dem_usercmd => {
            _ = try reads.read_user_cmd(file, null);
        },
        else => {
            return false;
        },
    }
    return true;
}
