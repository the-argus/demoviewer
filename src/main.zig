const std = @import("std");
const read_dem = @import("read_dem.zig").read_dem;
const dem_io = @import("read_dem.zig");
const read_bsp = @import("bsp/read_bsp.zig").read_bsp;
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

const Input = struct {
    print_only_header: bool,
    print_only_map_info: bool,
    map_file: ?[]const u8,
    demo_file: ?[]const u8,
    tf_path: ?[]const u8,
};

const default_tf_path = "~/.steam/steam/steamapps/common/Team Fortress 2/tf";

pub fn main() !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help                Display this help and exit.
        \\-p, --printheader         Print only the header of the specified demo file and exit.
        \\-m, --mapfile <str>       Override the map specified by the demo file.
        \\-b, --bspinfo             Print the information of the selected map and exit.
        \\-t, --tfpath <str>        Path to your tf folder.
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

    // print help and exit if asked for
    if (parsed_args.args.help > 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var input: Input = .{
        .print_only_header = false,
        .print_only_map_info = false,
        .map_file = null,
        .demo_file = null,
        .tf_path = default_tf_path,
    };

    input.print_only_header = parsed_args.args.printheader > 0;
    input.print_only_map_info = parsed_args.args.bspinfo > 0;

    if (parsed_args.positionals.len > 0) {
        input.demo_file = parsed_args.positionals[0];
    } else if (!input.print_only_map_info) {
        log.err("No positional arguments provided. Need demo file.", .{});
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    // resolve where the map is
    if (parsed_args.args.mapfile) |mapfile| {
        input.map_file = mapfile;
    } else {
        if (parsed_args.args.tfpath) |tfpath| {
            input.tf_path = tfpath;
        }

        const demo_file = try dem_io.open_demo(input.demo_file.?);
        const header = try dem_io.read_header(demo_file);
        const map_name_from_header = header.map_name;

        const map_file_abs_path = try std.fs.path.join(allocator, &[_][]const u8{ input.tf_path.?, &map_name_from_header });
        const map_file = std.fs.openFileAbsolute(map_file_abs_path, .{ .mode = .read_only }) catch {
            log.err("Failed to open mapfile {s}", .{map_file_abs_path});
            log.info("If the attempted path looks wrong, try passing in --tfpath or --mapfile", .{});
            return;
        };
        // don't free the map file abs path so we can pass it around
        input.map_file = map_file_abs_path;
        map_file.close();
    }

    // actual program execution based on input
    if (input.print_only_map_info) {
        return read_bsp(input.map_file.?);
    }

    if (input.print_only_header) {
        return print_header(input.demo_file.?);
    }

    return read_full_demo(allocator, input.demo_file.?);
}

fn read_full_demo(allocator: std.mem.Allocator, filename: []const u8) !void {
    try read_dem(filename, allocator);
}

fn print_header(filename: []const u8) !void {
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
