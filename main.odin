package main

import "base:runtime"
import "core:c"
import "core:c/libc"
import "core:fmt"
import "core:mem"
import "core:os"
import "deps/luajit"
import "deps/luv"

lua_allocator :: proc "c" (ud: rawptr, ptr: rawptr, osize, nsize: c.size_t) -> (buf: rawptr) {
	old_size := int(osize)
	new_size := int(nsize)
	context = (^runtime.Context)(ud)^

	if ptr == nil {
		data, err := runtime.mem_alloc(new_size)
		return raw_data(data) if err == .None else nil
	} else {
		if nsize > 0 {
			data, err := runtime.mem_resize(ptr, old_size, new_size)
			return raw_data(data) if err == .None else nil
		} else {
			runtime.mem_free(ptr)
			return
		}
	}
}

lua_preload_library :: proc(state: ^luajit.State, name: cstring, open_proc: luajit.CFunction) {
	luajit.getglobal(state, "package")
	luajit.getfield(state, -1, "preload")
	luajit.pushcfunction(state, open_proc)
	luajit.setfield(state, -2, name)
	luajit.pop(state, 2)
}

lua_run :: proc(src: cstring = "main.lua") {
	_context := context
	state := luajit.newstate(lua_allocator, &_context)
	ensure(state != nil)
	defer luajit.close(state)

	luajit.L_openlibs(state)
	lua_preload_library(state, "luv", luv.luaopen_luv)

	if (luajit.L_dofile(state, cstring(src)) != 0) {
		fmt.println(luajit.tostring(state, -1))
		luajit.pop(state, 1)
		os.exit(1)
	}
}

when ODIN_DEBUG {
	track: mem.Tracking_Allocator
	report_allocations :: proc() {
		fmt.println("exit")
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

	lua_run()
}
