const std = @import("std");
const valve_types = @import("valve_types.zig");

const demo_debug = @import("demo_debug");
const DemoReadError = demo_debug.DemoReadError;
const assert_header_good = demo_debug.assert_header_good;
const print_demo_header = demo_debug.print_demo_header;

const demo_sections = @import("demo_sections");
const read_command_header = demo_sections.read_command_header;
const read_console_command = demo_sections.read_console_command;
const read_network_datatables = demo_sections.read_network_datatables;
const read_user_cmd = demo_sections.read_user_cmd;
const read_command_info = demo_sections.read_command_info;
const read_sequence_info = demo_sections.read_sequence_info;
const read_raw_data = demo_sections.read_raw_data;

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
