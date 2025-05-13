module main

import os
import os.cmdline

const help = $embed_file('help.txt')

struct Preferences {
mut:
	trace             bool
	no_notes_path     bool
	no_chdir          bool
	grep_raw          bool
	grep_no_color     bool
	grep_no_recursive bool
}

fn main() {
	editor := os.getenv_opt('EDITOR') or { '/usr/bin/vim' }
	mut notes_path := os.getenv('NPATH')
	mut pref := Preferences{}
	argv := arguments()[1..]
	opts := cmdline.only_options(argv)
	for opt in opts {
		match opt {
			'-trace' { pref.trace = true }
			'-no-notes-path' { pref.no_notes_path = true }
			'-no-chdir' { pref.no_chdir = true }
			'-grep-raw' { pref.grep_raw = true }
			'-grep-no-color' { pref.grep_no_color = true }
			'-grep-no-recursive' { pref.grep_no_recursive = true }
			else {}
		}
	}
	args := cmdline.only_non_options(argv)
	if args.len == 0 {
		os.chdir(notes_path)!
		os.execvp(editor, []string{})!
		return
	}
	arg := args[0]
	if notes_path == '' && arg !in ['h', 'help'] {
		eprintln('E: NPATH environment variable is not set')
		eprintln('E: NPATH must contain path to notes dir')
		exit(1)
	}
	match arg {
		'd', 'dir' {
			println(notes_path)
			return
		}
		'o', 'open' {
			if pref.no_notes_path {
				os.execvp('xdg-open', [argv[0]])!
			}
			os.execvp('xdg-open', [os.join_path_single(notes_path, argv[0])])!
			return
		}
		's', 'search' {
			if !pref.no_chdir {
				os.chdir(notes_path)!
			}
			result := os.execute_or_exit("grep --color=always -rni '${argv[1]}'")
			println(result.output.trim_space())
			return
		}
		'g', 'grep' {
			if !pref.no_chdir {
				os.chdir(notes_path)!
			}
			mut pc := os.new_process('/usr/bin/grep')
			mut grep_args := []string{}
			if !pref.grep_raw {
				if !pref.grep_no_color {
					grep_args << '--color=always'
				}
				if !pref.grep_no_recursive {
					grep_args << ['--recursive', '--line-number']
				}
			}
			if arg == 'g' {
				grep_args << argv[argv.index('g') + 1..]
			}
			if arg == 'grep' {
				grep_args << argv[argv.index('grep') + 1..]
			}
			if pref.trace {
				eprintln('I: grep_args: ${grep_args}')
			}
			pc.set_args(grep_args)
			pc.run()
			pc.wait()
			return
		}
		'ls', 'lsf', 'lsd' {
			mut dir := notes_path
			if !pref.no_chdir {
				os.chdir(notes_path)!
				dir = '.'
			}
			cmd := match arg {
				'ls' { 'env LC_ALL=C tree -FC ${dir}' }
				'lsf' { 'find ${dir} -type f' }
				'lsd' { 'find ${dir} -type d' }
				else { '' }
			}
			if pref.trace {
				eprintln('I: command to execute: ${cmd}')
			}
			result := os.execute_or_exit(cmd)
			println(result.output.trim_space())
			return
		}
		'p', 'path' {
			p := os.join_path_single(notes_path, argv[1])
			if os.is_file(p) {
				println(p)
				return
			} else {
				eprintln('E: ${p} is not file or does not exist')
				exit(1)
			}
		}
		'h', 'help' {
			println(help.to_string().trim_space())
			return
		}
		else {
			if arg.starts_with('-') {
				eprintln('E: unrecognized option: ${arg}')
				exit(2)
			}
			if pref.no_notes_path {
				os.execvp(editor, [arg])!
			}
			os.execvp(editor, [os.join_path_single(notes_path, arg)])!
			return
		}
	}
}
