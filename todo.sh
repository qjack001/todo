#!/bin/bash
#### `todo` is a command-line to-do list app. Run `sh todo.sh install`
####  to install, and `todo help` for a list of available commands. 
####  Lists are stored locally as TODO.md files, based on our spec for 
####  [Markdown Tasks](https://github.com/GoodbyteCo/Markdown-Tasks).
#### 
####  Copyright (c) 2021 by Jack Guinane
####  This code is licensed under the MIT license

PROGRAM="todo"
VERSION="0.2"
SOURCE_URL="https://raw.githubusercontent.com/qjack001/todo/main/todo.sh"



####  Global variables
TODO_ITEMS=()   # item text
IS_DONE=()      # item status
DONE_ITEMS=()   # finished items
LIST_PATH=""    # path to file

####  Mission control for handling input & deciding which function to run.
function handle_input
{
	if [ "$#" -lt "1" ];                   then list_todos
	elif input "$1" "did";                 then list_done
	elif input "$1" "help" "h";            then show_help
	elif input "$1" "shortform" "short";   then show_short
	elif input "$1" "version" "v";         then print_version
	elif input "$1" "update" "upgrade";    then update
	elif input "$1" "install";             then install
	else show_help
	fi
}

####  Prints the program's Help page, listing the availible commands and 
####  their functions.
function show_help
{
	echo
	print_hr
	echo "  ${PROGRAM} v${VERSION}  --  Help"
	print_hr
	printf "\n  ${PROGRAM} [command] \t description \n\n"
	printf "  did     \t\t See all completed todos \n"
	printf "  short   \t\t See list of command short-forms \n"
	printf "  update  \t\t Update to the latest version \n"
	printf "  version \t\t Print the version \n"
	printf "\n\n"
}

####  Prints the short-form versions of the availible commands.
function show_short
{
	echo
	print_hr
	echo "  ${PROGRAM} v${VERSION}  --  Short-Form Commands"
	print_hr
	printf "\n  [command] \t\t [short-form] \n\n"
	printf "  version \t\t v \n"
	printf "\n\n"
}

####  Sets the global LIST_PATH variable to the location of the TODO.md 
####  file, falling back on the global file if no local one is found.
function get_list_path
{
	if [[ -f "TODO.md" ]]; then
		LIST_PATH="TODO.md"
	else
		echo "No TODO.md found in working directory, using global TODO.md instead."
		printf "Run 'todo create' to add a list to this folder. \n\n"
		cd ~
		touch "TODO.md"
		LIST_PATH="TODO.md"
	fi
}

####  Gets tasks from file and pushes them into TODO_ITEMS and DONE_ITEMS arrays.
function parse_todos
{
	get_list_path
	while read -r line; do
		## if it is a valid todo item, add to todos and and IS_DONE status
		is_valid "$line" && TODO_ITEMS+=("$(get_text "$line")") && IS_DONE+=(false)
		## if it is a valid, completed todo, add to the done-list
		is_valid_done "$line" && DONE_ITEMS+=("$line")
	done < $LIST_PATH
}

####  Returns 0 if argument is a valid (unfinished) todo.
function is_valid
{
	if [[ "$1" == "- [ ] "* ]]; then
		return 0
	fi
	return 1
}

####  Returns 0 if argument is a valid (finished) todo.
function is_valid_done
{
	if [[ "$1" == "- [x] "* ]]; then
		return 0
	fi
	return 1
}

####  Returns (prints) the text portion of the given todo.
####  Note: expects valid Markdown Task syntax-ed item.
function get_text
{
	echo $(cut -d "]" -f2- <<< "$1")
}

####  Lists all todo items in an interactive menu.
function list_todos
{
	parse_todos
	selected="${#TODO_ITEMS[@]}"
	
	while true; do
		options=()
		index=0

		## build visual todo item
		for item in "${TODO_ITEMS[@]}"; do
			options+=("$(create_item $index)")
			index=$(($index + 1))
		done

		if [ "${#TODO_ITEMS[@]}" -eq "0" ]; then
			tput setaf 7
			printf " \033[3mNo todo items\033[0m\n"
			tput sgr 0
		fi

		## add other controls
		options+=("\033[2m(+) Add new \033[0m")
		options+=("\n[  DONE  ]")

		## print menu of options
		menu $selected "${options[@]}"
		selected=$?  # get user's selection

		## handle input
		if [ $selected = $((${#options[@]} - 1)) ]; then
			## print all items and exit
			clear
			index=0
			for item in "${TODO_ITEMS[@]}"; do
				create_item $index
				index=$(($index+1))
			done
			printf "\n\n"
			write_to_file # save
			break
		elif [ $selected = $((${#options[@]} - 2)) ]; then
			print_add_screen
			selected=$(($selected+1))
		else
			toggle $selected
		fi
	done
}

####  Lists all completed todo items (not interactive).
####  TODO: add --since feature
function list_done
{
	parse_todos
	echo

	for item in "${DONE_ITEMS[@]}"; do
		printf "\033[2m[\033[0m\033[1;32m✓\033[0m\033[2m]\033[0m "
		get_text "$item"
	done
	echo
}

####  Toggles "done" status of todo item at provided index.
function toggle
{
	if [ "${IS_DONE[$1]}" = true ]; then
		IS_DONE[$1]=false
	else
		IS_DONE[$1]=true
	fi
}

####  Prints the prompt to add a new todo item.
function print_add_screen
{
	clear
	index=0
	for item in "${TODO_ITEMS[@]}"; do
		create_item $index
		index=$(($index+1))
	done
	read -p ">>> " -r
	add_item "$REPLY"
}

####  Adds given text to list of todo items.
function add_item
{
	TODO_ITEMS+=("$1")
	IS_DONE+=(false)
}

####  Prints the todo item at the entered index. 
####  Example output: ` [✓] This item is done `
function create_item
{
	if [[ "${IS_DONE[$1]}" = true ]]; then
		printf "\033[2m[\033[0m\033[1;32m✓\033[0m\033[2m] ${TODO_ITEMS[$index]}\033[0m \n"
	else
		printf "\033[2m[ ]\033[0m ${TODO_ITEMS[$index]} \n"
	fi
}

####  Converts TODO_ITEMS and DONE_ITEMS back to Markdown Task
####  items and (over)writes to TODO.md file.
function write_to_file
{
	date=$(date '+%Y-%m-%d')
	echo >| "$LIST_PATH"  # clear
	index=0

	## add items not yet done
	for item in "${TODO_ITEMS[@]}"; do
		if [ "${IS_DONE[$index]}" = true ]; then
			DONE_ITEMS+=("- [x] (${date}): ${item}")
		else
			echo "- [ ] ${item}" >> "$LIST_PATH"
		fi
		index=$(($index+1))
	done

	echo >> "$LIST_PATH"

	## add done items
	for item in "${DONE_ITEMS[@]}"; do
		echo "${item}" >> "$LIST_PATH" 
	done

	echo >> "$LIST_PATH" # trailing newline
}

####  Removes color codes from inputted string. Add new codes as you 
####  use them to: `(1;32|0|2)`.
function remove_colors
{
	echo "$1" | sed -E "s/[[:cntrl:]]\[(1;32|0|2)m//g"
}

####  Print interactable menu of items. Navigatable with the arrow
####  keys, press <enter> or <space> to select.
####
####  Usage: menu <index> <item 1> <item 2> ... <item n>
####  Where: each <item> is an option & <index> is currently selected
####  Returning: exit code representing the user's selection
function menu
{
	selected="$1"
	length=$(($# - 2))
	shift
	
	while true; do
		
		clear
		index=0

		##  print all items
		for item in "$@"; do

			if [ "$index" = "$selected" ]; then 
				##  invert if selected
				printf "\033[7m$(remove_colors "$item")\033[0m\n"
			else
				printf "${item}\n"
			fi

			index=$(($index+1))
		done

		##  handle input
		while true; do
			read -rsn1 esc
			if [ "$esc" == $'\033' ]; then
				read -sn1 bra
				read -sn1 typ
			elif [ "$esc" == "" ]; then
				##  enter
				return $selected
			fi
			if [ "$esc$bra$typ" == $'\033'[A ]; then
				##  move up
				selected=$(($selected - 1))
				if [ "$selected" -lt "0" ]; then
					##  if at zero, loop around to end
					selected="$length"
				fi
				break
			elif [ "$esc$bra$typ" == $'\033'[B ]; then
				##  move down
				selected=$(($selected + 1))
				if [ "$selected" -gt "$length" ]; then
					##  if at end, loop back around
					selected=0
				fi
				break
			fi
		done
	done
}

####  Handles input command matching.
####  First argument is the user's input, the following arguments are
####  the commands to match it against. Allows you to provide synonymous
####  and short-form command options (i.e. "update", "upgrade" "u"), as 
####  well as optional hyphen-syntax ("u", "-u", "--u").
function input
{
	prefix="-"
	argument="$1"
	shift

	for var in "$@"; do
		if [ "$var" = "$argument" ] ||
		   [ "${prefix}${var}" = "$argument" ] ||
		   [ "${prefix}${prefix}${var}" = "$argument" ]; then 
			return 0
		fi
	done

	return 1
}

####  Prints a horizontal rule (of "=" characters) across the width of
####  the terminal's screen.
function print_hr
{
	printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
}

####  Prints current version of script.
function print_version
{
	echo "${PROGRAM} v${VERSION}"
}

####  Updates program to newest version, pulling the current code directly
####  from the SOURCE_URL (at the top of the file).
function update
{
	echo "Downloading newest version..."
	## curls source with current date added (to avoid old cached versions)
	HTTP_CODE=$(curl --write-out "%{http_code}" -H 'Cache-Control: no-cache' "${SOURCE_URL}?$(date +%s)" -o "${PROGRAM}.sh")
	if [[ ${HTTP_CODE} -lt 200 || ${HTTP_CODE} -gt 299 ]]; then 
		printf "\nDownload failed. Response code = ${HTTP_CODE}\n"
		exit 1
    fi
	printf "\nFinished downloading!\n"
	echo
	print_version
	printf "\nInstall new version in '/usr/local/bin/'?\n"
	read -p "(y/n):  " -r
	if   [[ $REPLY =~ ^[Yy]$ ]]; then install
	elif [[ $REPLY =~ ^[Nn]$ ]]; then echo "Ok, update is downloaded but not installed."
	else echo "Input '${REPLY}' not recognized. Update is downloaded but will not be installed. Run 'sh ${PROGRAM}.sh install' to finish installing."
	fi
}

####  Installs the script as an executable in /usr/local/bin/
function install
{
	echo "Installing at /usr/local/bin/${PROGRAM} ..."
	cp -f "${PROGRAM}.sh" "/usr/local/bin/${PROGRAM}"
	chmod +x "/usr/local/bin/${PROGRAM}"
	echo "Installation complete. Try running '${PROGRAM} version'"
}

handle_input $@