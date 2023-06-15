const std = @import("std");
const read_dem = @import("read_dem.zig").read_dem;
const dem_io = @import("read_dem.zig");
const read_bsp = @import("bsp/read_bsp.zig").read_bsp;
const demo_debug = @import("demo_debug.zig");
const builtin = @import("builtin");

const cli = @import("cli.zig");

pub const std_options = struct {
    // log level depends on build mode
    pub const log_level = if (builtin.mode == .Debug) .debug else .info;
    // Define logFn to override the std implementation
    pub const logFn = @import("logging.zig").demoviewer_logger;
};

pub fn main() !void {
    // allocator which will be used for the whole program
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cli_interface = try cli.initialize_cli();
    defer cli_interface.deinit(allocator); // allocator will be used on it later
    try cli_interface.print_help_if_needed();
    try cli_interface.stage1();

    // most obvious first exit point, requires the least info
    if (cli_interface.input.?.print_only_header) {
        return print_header(cli_interface.input.?.demo_file.?);
    }

    try cli_interface.stage2(allocator);

    if (cli_interface.input.?.print_only_map_info) {
        return read_bsp(allocator, cli_interface.input.?.map_file.?);
    }

    return try read_dem(cli_interface.input.?.demo_file.?, allocator);
}

fn print_header(filename: []const u8) !void {
    const demo_file = try dem_io.open_demo(filename);
    const header = try dem_io.read_header(demo_file);
    demo_debug.print_demo_header(header);
}
