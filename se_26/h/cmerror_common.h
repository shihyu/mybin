#pragma once

enum CMERROR_COMMON {
    CMRC_EOF = -102699,
    CMRC_FILE_NOT_FOUND_1ARG = -102698,
    CMRC_PATH_NOT_FOUND_1ARG = -102697,
    CMRC_TOO_MANY_OPEN_FILES = -102696,
    CMRC_ACCESS_DENIED_1ARG = -102695,
    CMRC_INVALID_HANDLE = -102694,
    CMRC_MEMORY_CONTROL_BLOCKS = -102693,
    CMRC_INSUFFICIENT_MEMORY = -102692,
    CMRC_INVALID_DRIVE = -102691,
    CMRC_CURRENT_DIRECTORY_CAN_NOT_BE_REMOVED = -102690,
    CMRC_ERROR_READING_FILE_1ARG = -102689,
    CMRC_ERROR_WRITING_FILE_1ARG = -102688,
    CMRC_ERROR_CLOSING_FILE_1ARG = -102687,
    CMRC_ERROR_OPENING_FILE_1ARG = -102686,
    CMRC_NO_MORE_FILES = -102685,
    CMRC_FINDOPEN_NOT_CALLED = -102684,
    CMRC_INSUFFICIENT_DISK_SPACE = -102683,
    CMRC_ERROR_SEEKING_IN_FILE_1ARG = -102682,
    CMRC_MEDIA_IS_WRITE_PROTECTED = -102681,
    CMRC_ERROR_TRUNCATING_FILE_1ARG = -102680,
    CMRC_INVALID_FILENAME = -102679,
    CMRC_WRITING_TO_FILES_OF_THIS_TYPE_NOT_SUPPORTED = -102678,
    CMRC_ERROR_CREATING_DIRECTORY_1ARG = -102677,
    CMRC_DEVICE_NOT_READY = -102676,
    CMRC_BAD_COMMAND = -102675,
    CMRC_ERROR_CRC = -102674,
    CMRC_BAD_LENGTH = -102673,
    CMRC_SECTOR_NOT_FOUND = -102672,
    CMRC_OUT_OF_PAPER = -102671,
    CMRC_DISK_FULL = -102670,
    CMRC_PRINT_CANCALLED = -102669,
    CMRC_IO_ERROR = -102668,
    CMRC_NOT_A_DIRECTORY = -102667,
    CMRC_BUFFER_TOO_SMALL = -102666,
    CMRC_INVALID_NAME = -102665,
    CMRC_ERROR_CHANGING_PERMISSIONS_OF_FILE_1ARG = -102664,
    CMRC_ERROR_CHANGING_OWNER_OF_FILE_1ARG = -102663,
    CMRC_ERROR_DELETING_FILE_1ARG = -102662,
    CMRC_ERROR_SETTING_FILE_DATE_1ARG = -102661,
    CMRC_ERROR_OPENING_STANDARD_FILE = -102660,
    CMRC_INVALID_ARGUMENT = -102659,
    CMRC_DUPLICATE_KEY = -102658,
    CMRC_KEY_NOT_FOUND = -102657,
    CMRC_INVALID_ARGUMENT_1ARG = -102656,
    CMRC_CALL_FAILED_2ARG = -102655,
    CMRC_INVALID_DATE_ARGUMENT_1ARG = -102654,
    CMRC_INVALID_ZIP_OR_JAR_FILE_1ARG = -102653,
    CMRC_FILE_LISTING_NOT_SUPPORTED = -102652,
    CMRC_FILE_OPERATION_NOT_SUPPORTED = -102651,
    CMRC_ZIP_OR_JAR_DECOMPRESSION_FAILED_1ARG = -102650,
    CMRC_ERROR_READING_ZIP_OR_JAR_ITEM_1ARG = -102649,
    CMRC_TREE_CORRUPT_CHILD_NODE_MISSING_PARENT = -102648,
    CMRC_NO_PROCESS_TO_WAIT_ON = -102647,
    CMRC_ERROR_STARTING_PROCESS = -102646,
    CMRC_ERROR_GETTING_EXIT_CODE = -102645,
    CMRC_NO_PROCESS_RUNNING = -102644,
    CMRC_INVALID_FIND_OPTION_SPECIFIED = -102643,
    CMRC_EOL1 = -102642,
    CMRC_EOL2 = -102641,
    CMRC_EOL0 = -102640,
    CMRC_INVALID_PERMISSION_STRING_1ARG = -102639,
    CMRC_ERROR_SETTING_FILE_PERMISSIONS_1ARG = -102638,
    CMRC_STARTINDEX_CANNOT_BE_LARGER_THAN_LENGTH = -102637,
    CMRC_INDEX_AND_LENGTH_MUST_BE_WITHIN_STRING = -102636,
    CMRC_INDEX_AND_LENGTH_MUST_BE_WITHIN_ARRAY = -102635,
    CMRC_LENGTH_TOO_LARGE = -102634,
    CMRC_ADDING_AFTER_OR_BEFORE_NODE_NOT_IN_LIST = -102633,
    CMRC_REMOVE_CALLED_WHEN_LIST_IS_EMPTY = -102632,
    CMRC_DEQUEUE_CALLED_WHEN_QUEUE_IS_EMPTY = -102631,
    CMRC_DLL_SYMBOL_NOT_FOUND_1ARG = -102630,
    CMRC_TIMEOUT = -102629,
    CMRC_INVALID_FILE_DESCRIPTOR = -102628,
    CMRC_NETWORK_IS_UNREACHABLE = -102627,
    CMRC_FINDFILE_NOT_SUPPORTED_FOR_FILES_OF_THIS_TYPE = -102626,
    CMRC_MAKEDIR_NOT_SUPPORTED_FOR_FILES_OF_THIS_TYPE_ARG1 = -102625,
    CMRC_INVALID_PORT_ADDRESS_ARG1 = -102624,
    CMRC_ERROR_REMOVING_DIRECTORY_1ARG = -102623,
    CMRC_INVALID_OPTION = -102622,
    CMRC_OPERATION_CANCELLED = -102621,
    CMRC_POTENTIAL_DEADLOCK_DETECTED = -102620,
    CMRC_THREAD_STILL_RUNNING = -102619,
    CMRC_INFINITE_LOOP_DETECTED_IN_COMMAND_2ARG = -102618,
    CMRC_RANGE_CHECK_CANCEL = -102617,
    CMRC_INVALID_TAR_FILE_1ARG = -102616,
    CMRC_ERROR_READING_TAR_ITEM_1ARG = -102615,
    CMRC_GZIP_PROGRAM_NOT_FOUND = -102614,
    CMRC_ERROR_READING_GZIP_FILE = -102613,
    CMRC_XZ_PROGRAM_NOT_FOUND = -102612,
    CMRC_INVALID_CPIO_FILE_1ARG = -102611,
    CMRC_ERROR_READING_CPIO_ITEM_1ARG = -102610,
    CMRC_BZIP2_PROGRAM_NOT_FOUND = -102609,
    CMRC_MOVE_DESTINATION_ALREADY_EXISTS_1ARG = -102608,
    CMRCEND_COMMON = -102700,
};
