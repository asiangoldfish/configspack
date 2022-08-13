#!/usr/bin/python3

# Exit codes:
#   0: This script executed successfully
#   1: The configuration file could not be found
#   2: An argument expected a value but had none
#   3: The function name passed as argument is invalid
#   4: Script was executed with invalid arguments [VALUES]
#   5: No config file path was passed
#   6: Argument '--value' requires a valid section and key

from sys import exit as sysexit                         # exit script
from sys import argv                                    # handle script args
from pathlib import Path                                # get file paths
from configparser import ConfigParser                   # parse ini file
from configparser import NoSectionError                 

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
    
    found_items = list()
    for item in config.sections():
        if arg_vars['--section'] in item:
            print(item) if arg_vars['--verbose'] == 'True' else 'None'
            found_items.append(item)

    return found_items


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


def get_value(arg_dict: dict):
    """
    Gets a the value of a given key in a section.

    Parameters:
        - arg_dict (dict): dictionary containing section and key to search for
                           value
    Return:
        str: Value based on section and key
    """
    
    try:
        value = config.get(arg_dict['--section'], arg_dict['--key'])
        print(value)
    except NoSectionError:
        print('parser.py: Argument \'--value\' requires valid section and key')
        set_exit_code(6)
        return
    set_exit_code(0)


def get_root_sections(section: dict):
    """Gets sections without any nested sections
    """

    for elem in config.sections():
        if not '/' in elem:
            print(elem)
    set_exit_code(0)


def create_field(arg_dict: dict):
    """ Update an existing key
        
        Parameters:
            - arg_dict (dict): This script's arguments and their values
    """

    # prevent get_all_nested_sections_str to output to stdin
    old_verbose = arg_dict['--verbose']
    arg_dict['--verbose'] = 'False'

    for section in get_all_nested_sections_str(arg_dict):
        # update the config file with the new key-value pair
        config[f'{section}'][arg_dict[f'--key']] = arg_dict['--new-value']

    with open(arg_dict['--file'], 'w') as configfile:
        config.write(configfile)
    
    # restore the user argument for verbose
    arg_dict['--verbose'] = old_verbose


def usage():
    print("""parser.py [OPTION]
parser.py [OPTIONS] [VALUES]

This script is intended parses an initialization file and outputs results
to stdout.

To learn more about what each option does and arguments it requires,
use the help flag with it.

Example: parser.py --value --help

Options:
        --create-field [section] [key] [new value]  create or update a field in specified sections
    -h, --help                                      this page
        --root-sections                             gets the parent sections
        --search-section [section]                  search for sections with regex
        --value [section] [key]                     gets the value from a given section and key
        --version                                   outputs version information and exit

Values:
        --section                                   definite section to use
        --file                                      target initialization file to parse
        --new-value                                 new value to assign to a key
""",
          end='')
    set_exit_code(0)


# call usage if no arguments were passed
if len(argv) == 1:
    usage()
    sysexit(get_exit_code())

# let script execution call functions based on the script argv
arg_funcs = {
    '--create-field': create_field,
    '--root-sections': get_root_sections,
    '--search-section': get_all_nested_sections_str,
    '--value': get_value,
}

# let script execution call functions based on the script argv
arg_vars = {
    '--debug': '',
    '--file': '',
    '--key': '',
    'missing_arg_error': '',
    '--new-value': '',
    '--pattern': '',
    '--section': '',
    '--verbose': '',
}

# we create a hard copy of argv to avoid manipulating it
process_argv = argv.copy()
# remove file name in arr
process_argv.pop(0)

# call the help page
if process_argv[0] == '-h' or process_argv[0] == '--help':
    usage()
    sysexit(0)

skip_arg = False                            # whether to skip the next argument

# iterate all argv for the first found argument for function call
for key in arg_funcs.keys():
    for arg in process_argv:
        if key == arg:
            execute_function = arg_funcs[f'{key}']
    if skip_arg == True:                    # exit loop if the function was found
        break

for key in arg_vars.keys():
    for i, arg in enumerate(process_argv):
        if skip_arg:
            skip_arg = False
            continue

        if key == arg:
            validate_arg(process_argv, arg_vars, key)
            arg_vars[f'{arg}'] = process_argv[i + 1]
            skip_arg = True

# read the config file
read_configs = config.read(arg_vars['--file'])

# if config file was unsuccessfully read, then exit the program
if len(read_configs) == 0:
    print('No configuration file was passed')
    sysexit(5)

execute_function(arg_vars)
#try:
#    execute_function(arg_vars)
#except NameError:
#    print(f'{argv[0]}: No actions to execute. Use \'{argv[0]} --help\' for a list of commands')

sysexit(get_exit_code())
