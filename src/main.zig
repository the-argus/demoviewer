const std = @import("std");
const read_dem = @import("read_dem.zig").read_dem;
const dem_io = @import("read_dem.zig");
const demo_debug = @import("demo_debug.zig");
const builtin = @import("builtin");
const clap = @import("clap");

pub const std_options = struct {
    // log level depends on build mode
    pub const log_level = if (builtin.mode == .Debug) .debug else .info;
    // Define logFn to override the std implementation
    pub const logFn = @import("logging.zig").demoviewer_logger;
};

pub fn main() !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help                Display this help and exit.
        \\-p, --print-header        Print only the header of the specified demo file and exit.
        \\<str>...
        \\
    );
    var diag = clap.Diagnostic{};
    var parsed_args = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
    }) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer parsed_args.deinit();

    var program = read_full_demo;

    for (parsed_args.positionals) |positional_arg| {
        program(positional_arg);
        return;
    }
}

fn read_full_demo(filename: []u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    read_dem(filename, allocator);
}

fn read_only_header(filename: []u8) !void {
    const demo_file = try dem_io.open_demo(filename);
    const header = try dem_io.read_header(demo_file);
    demo_debug.print_demo_header(header);
}
