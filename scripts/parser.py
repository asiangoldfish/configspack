#!/usr/bin/python3
# File: parser.py
# This script is a library of functions parsing initialize (INI) files and is
# intended for usage in shell scripts. To call a function, execute the script
# and pass the function name as the first and section name as the second argument.
# Example: /file/path/parser.py get_value section_name

# Exit codes:
#   0: this script executed successfully
#   1: the configuration file could not be found
#   2: an argument expected a value but had none
#   3: the function name passed as argument is invalid
#   4: script was executed with invalid arguments [VALUES]


from sys import exit as sysexit                         # exit script
from sys import argv                                    # handle script args
from pathlib import Path                                # get file paths
from configparser import ConfigParser                   # parse ini file

exit_code = str()                                       # exit code to stderr

script_path = Path(__file__).resolve().parent           # this script's path
config_path = f'{script_path}/../configs/config.ini'

if not Path(config_path).is_file():                     # check if config exists
    sysexit(1)

config = ConfigParser()
config.read(f'{script_path}/../configs/config.ini')     # parse the config file


def check_missing_value(arg: str):
    """
    Checks if a string's value is missing

    If the value is missing, then print an error
    message

    Parameters:
        arg (str): argument to parse
    Returns:
        [str, int]: (modified arg string as array, error code)
    """

    # arg and value is split
    arg = arg.split('=', 1)
    if len(arg) == 2 and arg[1] != "":
        return [arg[1], 0]
    else:
        return [0, 2]


def get_all_nested_sections_str(parent: str):
    """
    Gets all nested sections in one line of string

    Based on a parent name, gets all nested sections.
    Example: func_name('foo_parent/bar_subparent')

    Parameters:
        parent (str): Parent sections to base the
                      search on
    Returns:
        str: All nested sections based on the given
             parameters
    """

    for elem in get_all_sections_arr():
        print(elem)


def get_all_sections_arr():
    """
    Gets all sections of the config file

    Returns:
        str[]: All sections of the config file
    """

    set_exit_code(0)
    return config.sections()


def get_all_sections_str():
    """
    Gets all sections of the config file formatted as a string

    Returns:
        str: All sections of the config file
    """

    set_exit_code(0)
    return ', '.join(str(x) for x in config.sections())


def set_exit_code(num: int):
    """
    Sets this script's error code.

    Parameters:
        num (int): The number to set as error code
    """

    exit_code = num


def get_exit_code():
    """
    Gets the exit code

    Returns:
        int: Exit code
    """

    return exit_code


def get_value(section: str, key: str):
    """
    Gets a the value of a given key in a section.

    Parameters:
        - section (str): section to search for the key in
        - key (str): key to look up
    Return:
        str: Value based on section and key
    """

    set_exit_code(0)
    return config.get(section, key)


def usage():
    print("""parser.py [OPTION]
parser.py [OPTIONS] [VALUES]

This script is intended for use in shell scripts and parses an
initialization (INI) file. Call functions in the script by
adding its function name as the first argument to the script.

Example: parser.py get_value Default name

Options:
    get_all_sections_arr            gets all sections in the config and formats
                                    the output as an array
    get_all_sections_str            gets all sections in the config and formats
                                    the output as string
    get_value [section] [key]       gets the value from a given section and key
    help                            this page
""", end='')
    set_exit_code(0)


# call usage if no arguments were passed
if len(argv) == 1:
    usage()
    sysexit(get_exit_code())

# let script execution call functions based on the script argv
func_name = str()
parent = str()
section = str()
value = str()

process_argv = argv.copy()
# Remove file name in arr
process_argv.pop(0)

# for each argument in argv,
for arg in process_argv:
    check = check_missing_value(arg)
    arg_split = arg.split('=', 1)
    match arg_split[0]:
        case 'func_name':
            func_name = check[0]
            set_exit_code(check[1])
            break
        case 'parent':
            parent = check[0]
            set_exit_code(check[1])
            if check[1]: break
        case 'section':
            section = check[0]
            set_exit_code(check[1])
            print(check[1])
            if check[1]: break
        case 'value':
            value = check[0]
            set_exit_code(check[1])

            if check[1]: break
        case _:
            print(f'Argument \'{arg_split}\' is not valid')
            set_exit_code(4)
            if check[1]: break

print(exit_code)

if get_exit_code() != 0:                                  # Only proceed if error code is 0
    if get_exit_code() == 2:
        print(f'Argument \'{arg[0]}\' expected a value, but received none')
        sysexit(get_exit_code())

print("continue")
if func_name != "":
    match func_name:
        case 'get_all_nested_sections_str':
            print(get_all_nested_sections_str())
        case 'get_all_sections_arr':
            print(get_all_sections_arr())
        case 'get_all_sections_str':
            print(get_all_sections_str())
        case 'get_value':
            print(get_value(section, key))
        case 'usage':
            usage()

        # Default case
        case _:
            print(f'{func_name} is an invalid function')
            set_exit_code(3)

sysexit(get_exit_code())
