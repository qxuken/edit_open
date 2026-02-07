export def test [--watch (-w)] {
	let cmd =  {lua ./tests/run_all.lua}
	do $cmd
	if $watch {
		watch . --glob **/*.lua --debounce 50ms $cmd
	}
}
export alias "main test" = test
export alias t = test
export alias "main t" = t

export def main [] {
	odin build . -vet
}
