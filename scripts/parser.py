#!/usr/bin/python3

# Exit codes:
#   0: this script executed successfully
#   1: the configuration file could not be found
#   2: an argument expected a value but had none
#   3: the function name passed as argument is invalid
#   4: script was executed with invalid arguments [VALUES]
#   5: no config file path was passed

from sys import exit as sysexit                         # exit script
from sys import argv                                    # handle script args
from pathlib import Path                                # get file paths
from configparser import ConfigParser                   # parse ini file

exit_code = 0                                           # exit code to stderr

script_path = Path(__file__).resolve().parent           # this script's path

config = ConfigParser()
config_path = ""


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


def get_all_nested_sections_str(arg_vars: str):
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
    
    for elem in config.sections():
        if arg_vars['--pattern'] in elem:
            print(elem)


def validate_arg(argv: list, arg_vars: dict, arg):
    if (i + 1 < len(argv)):
        if (argv[i + 1] in arg_vars.keys()):
            print('Missing argument:', arg)
            sysexit(2)
    else:
        print(f'Missing argument: {arg}')
        sysexit(2)


def set_exit_code(num: int):
    """
    Sets this script's error code.

    Parameters:
        num (int): The number to set as error code
    """

    global exit_code
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


def get_root_sections(section: dict):
    """Gets sections without any nested sections
    """

    for elem in config.sections():
        if not '/' in elem:
            print(elem)

def usage():
    print("""parser.py [OPTION]
parser.py [OPTIONS] [VALUES]

This script is intended parses an initialization file and outputs results
to stdout.

To learn more about what each option does and arguments it requires,
use the help flag with it.

Example: parser.py --value --help

Options:
    -h, --help                                  this page
        --root-sections                         gets the parent sections
        --search-section [pattern]              search for sections with regex
        --value [section] [key]                 gets the value from a given section and key
        --version                               outputs version information and exit

Values:
        --pattern                               parent of nested sections
        --section                               definite section to use
        --file                                  target initialization file to parse
""",
          end='')
    set_exit_code(0)


# call usage if no arguments were passed
if len(argv) == 1:
    usage()
    sysexit(get_exit_code())

# let script execution call functions based on the script argv
arg_vars = {
    '--debug': '',
    '--file': '',
    '--pattern': '',
    '--section': '',
}

# we create a hard copy of argv to avoid manipulating it
process_argv = argv.copy()
# remove file name in arr
process_argv.pop(0)

# stores the identifier to invoke a given function at a later point when all
# arguments have been parsed
skip_arg = False

for i, arg in enumerate(process_argv):
    if not skip_arg:
        match arg:
            # match functions
            case '-h' | '--help':
                usage()
            case '--root-sections':
                execute_function = get_root_sections
            case '--search-section':
                execute_function = get_all_nested_sections_str
            case '--value':
                execute_function = get_value

            # match arguments
            case '--debug':
                if i + 1 < len(argv):
                    next_arg = argv[i + 1]
                    if next_arg in arg_vars.keys():
                        if next_arg != True or False:
                            print(f'Argument {arg} requires argument True or False')
                            sysexit(2)

                arg_vars['--debug'] = process_argv[i + 1]
                skip_arg = True

            case '--file':
                validate_arg(process_argv, arg_vars, arg)
                arg_vars['--file'] = process_argv[i + 1]
                skip_arg = True
            case '--pattern':
                validate_arg(process_argv, arg_vars, arg)
                arg_vars['--pattern'] = process_argv[i + 1]
                skip_arg = True
            case '--section':
                validate_arg(process_argv, arg_vars, arg)
                arg_vars['--section'] = process_argv[i + 1]
                skip_arg = True
    else:
        skip_arg = False

# read the config file
read_configs = config.read(arg_vars['--file'])

# if config file was unsuccessfully read, then exit the program
if len(read_configs) == 0:
    print('No configuration file was passed')
    sysexit(5)

try:
    execute_function(arg_vars)
except NameError:
    print(f'{argv[0]}: No actions to execute. Use \'{argv[0]} --help\' for a list of commands')

sysexit(get_exit_code())
