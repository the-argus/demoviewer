const std = @import("std");
const read_dem = @import("read_dem.zig").read_dem;
const dem_io = @import("read_dem.zig");
const demo_debug = @import("demo_debug.zig");
const builtin = @import("builtin");
const clap = @import("clap");
const log = std.log.scoped(.demoviewer);

pub const std_options = struct {
    // log level depends on build mode
    pub const log_level = if (builtin.mode == .Debug) .debug else .info;
    // Define logFn to override the std implementation
    pub const logFn = @import("logging.zig").demoviewer_logger;
};

pub fn main() !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help                Display this help and exit.
        \\-p, --printheader         Print only the header of the specified demo file and exit.
        \\<str>...
        \\
    );

    var diag: clap.Diagnostic = .{};
    var parse_options: clap.ParseOptions = .{};
    if (builtin.mode == .Debug) {
        diag = clap.Diagnostic{};
        parse_options = .{ .diagnostic = &diag };
    }

    var parsed_args = clap.parse(clap.Help, &params, clap.parsers.default, parse_options) catch |err| {
        return badarg(err, &params, &diag);
    };
    defer parsed_args.deinit();

    var program = &read_full_demo;

    if (parsed_args.args.help > 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    if (parsed_args.args.printheader > 0) {
        program = read_only_header;
    }

    for (parsed_args.positionals) |positional_arg| {
        return program(positional_arg);
    }
}

fn read_full_demo(filename: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try read_dem(filename, allocator);
}

fn read_only_header(filename: []const u8) !void {
    const demo_file = try dem_io.open_demo(filename);
    const header = try dem_io.read_header(demo_file);
    demo_debug.print_demo_header(header);
}

/// When building in debug mode, handle arguments that cannot be parsed in this way
fn badarg(err: anyerror, params: anytype, diag: *clap.Diagnostic) !void {
    if (builtin.mode == .Debug) {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    } else {
        log.err("Unable to parse command line arguments.", .{});
        return clap.help(std.io.getStdErr().writer(), clap.Help, params, .{});
    }
}
