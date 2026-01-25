package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:os"
import "deps/luajit"
import "deps/luv"
import "deps/uv"

lua_run :: proc(src: cstring) {
	_context := context
	state := luajit.open(luajit.odin_allocator, &_context)
	ensure(state != nil)
	defer luajit.close(state)

	luajit.L_openlibs(state)
	luajit.preload_library(state, "luv", luv.luaopen_luv)
	luajit.setup_args(state)

	if (luajit.L_dofile(state, src) != 0) {
		fmt.println(luajit.tostring(state, -1))
		luajit.pop(state, 1)
		os.exit(1)
	}
}

when ODIN_DEBUG {
	track: mem.Tracking_Allocator
	report_allocations :: proc() {
		for _, leak in track.allocation_map {
			fmt.printf("%v leaked %m\n", leak.location, leak.size)
		}
	}
}

main :: proc() {
	when ODIN_DEBUG {
		mem.tracking_allocator_init(&track, context.allocator)
		defer mem.tracking_allocator_destroy(&track)
		context.allocator = mem.tracking_allocator(&track)
		defer report_allocations()
	}
	uv.setup()
	entry: cstring = "main.lua"
	if len(runtime.args__) > 1 {
		entry = runtime.args__[1]
	}
	lua_run(entry)
}
