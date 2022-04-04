#pragma once

enum CMERROR_SOCKET {
    CMRC_SOCKET_COULD_NOT_FIND_SUITABLE_WINSOCK_DLL = -103399,
    CMRC_SOCKET_WSASTARTUP_MUST_BE_CALLED = -103398,
    CMRC_SOCKET_ADDRESS_FAMILER_NOT_SUPPORTED = -103397,
    CMRC_SOCKET_BLOCK_WINDOWS_1_1_CALL_IS_IN_PROGRESS = -103396,
    CMRC_SOCKET_NO_MORE_SOCKET_DESCRIPTORS_ARE_AVAILABLE = -103395,
    CMRC_SOCKET_NO_BUFFER_SPACE_AVAILABLE = -103394,
    CMRC_SOCKET_PROTOCOL_NOT_SUPPORTED = -103393,
    CMRC_SOCKET_INVALID_PROTOCOL_TYPE_FOR_SOCKET = -103392,
    CMRC_SOCKET_INVALID_SOCKET_TYPE_FOR_ADDRESS_FAMILY = -103391,
    CMRC_SOCKET_ADDRESS_ALREADY_IN_USE = -103390,
    CMRC_SOCKET_ADDRESS_NOT_AVAILABLE = -103389,
    CMRC_SOCKET_ALREADY_BOUND_TO_AN_ADDRESS = -103388,
    CMRC_SOCKET_INVALID_SOCKET_DESCRIPTOR = -103387,
    CMRC_SOCKET_ALREADY_CONNECTED = -103386,
    CMRC_SOCKET_LISTENING_NOT_SUPPORTED = -103385,
    CMRC_SOCKET_TEMPORARY_FAILURE_IN_NAME_RESOLUTION = -103384,
    CMRC_SOCKET_NONRECOVERABLE_FAILURE_IN_NAME_RESOLUTION = -103383,
    CMRC_SOCKET_NO_ADDRESS_ASSOCIATED_WITH_HOST_NAME = -103382,
    CMRC_SOCKET_HOST_NOT_FOUND = -103381,
    CMRC_SOCKET_TYPE_NOT_FOUND = -103380,
    CMRC_SOCKET_CLOSE_SOCKET_FAILED = -103379,
    CMRC_SOCKET_ALREADY_CANCELLED = -103378,
    CMRC_SOCKET_WOULD_BLOCK = -103377,
    CMRC_SOCKET_MUST_BE_IN_LISTENING_STATE = -103376,
    CMRC_SOCKET_INVALID_PORT_OR_SERVICE = -103375,
    CMRC_SOCKET_CONNECTION_HAS_TIMED_OUT = -103374,
    CMRC_SOCKET_THE_OPTION_IS_UNKNOWN_OR_UNSUPPORTED = -103373,
    CMRC_SOCKET_NOT_CONNECTED = -103372,
    CMRC_SOCKET_FAULT = -103371,
    CMRC_SOCKET_CONNECTION_FAILED = -103370,
    CMRC_SOCKET_CONNECTION_CLOSED = -103369,
    CMRC_SOCKET_CONNECTION_ABORTED = -103368,
    CMRC_SOCKET_CONNECTION_RESET = -103367,
    CMRC_SOCKET_SHUTDOWN = -103366,
    CMRC_SOCKET_CONNECTION_REFUSED = -103365,
    CMRC_SOCKET_NETWORK_DOWN = -103364,
    CMRC_SOCKET_NO_PROTOCOL_AVAILABLE = -103363,
    CMRC_SOCKET_SHUTDOWN_FAILED = -103362,
    CMRC_SOCKET_NO_MORE_DATA = -103361,
    CMRC_SOCKET_CALL_TO_GETNAMEINFO_FAILED = -103360,
    CMRC_SOCKET_CALL_TO_GETSOCKNAME_FAILED = -103359,
    CMRC_SOCKET_CALL_TO_GETPEERNAME_FAILED = -103358,
    CMRC_SOCKET_CALL_TO_GETSOCKOPT_FAILED = -103357,
    CMRC_SOCKET_CALL_TO_SETSOCKOPT_FAILED = -103356,
    CMRC_SOCKET_CALL_TO_SOCKET_FAILED = -103355,
    CMRC_SOCKET_CALL_TO_BIND_FAILED = -103354,
    CMRC_SOCKET_CALL_TO_LISTEN_FAILED = -103353,
    CMRC_SOCKET_CALL_TO_GETADDRINFO_FAILED = -103352,
    CMRC_SOCKET_CALL_TO_SEND_FAILED = -103351,
    CMRC_SOCKET_CALL_TO_RECV_FAILED = -103350,
    CMRCEND_SOCKET = -103400,
};
