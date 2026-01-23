const ubuntu_libs = [./lib/ubuntu/libluajit.a ./lib/ubuntu/libluv.a ./lib/ubuntu/libuv.a]
const darwin_libs = [./lib/darwin/libluajit.a ./lib/darwin/libluv.a ./lib/darwin/libuv.a]
const posix_deps = [-lm]
const windows_libs = [./lib/windows/luv.lib ./lib/windows/libuv.lib ./lib/windows/luajit.lib]
const windows_deps = [-lws2_32 -liphlpapi -ladvapi32 -luser32 -lshell32 -lole32 -ldbghelp -luserenv]

const out_dir = (path self . | path join build)
const windows_out = $out_dir | path join "main.exe"
const posix_out = $out_dir | path join "main"

def compiler [] {
	let cenv = $env | get -o CC | default "clang"
	if $cenv =~ "clang" {
		$cenv
	} else {
		"clang"
	}
}

def compile [out, libs, deps] {
	mkdir $out_dir
	let c = compiler
	run-external $c ./main.c '-o' $out ...$libs ...$deps
}

export def main [] {
	match (sys host | get name) {
		"Windows" => (compile $windows_out $windows_libs $windows_deps)
		"Ubuntu" => (compile $posix_out $ubuntu_libs $posix_deps)
		"Darwin" if (^uname -m) == arm64 => (compile $posix_out $darwin_libs $posix_deps)
		_ => (error make 'unknown target')
	}
}
