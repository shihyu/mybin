#pragma once

enum VSMSGDEFS_SOCK {
    SOCK_GENERAL_ERROR_RC = -100,
    SOCK_INIT_FAILED_RC = -101,
    SOCK_NOT_INIT_RC = -102,
    SOCK_BAD_HOST_RC = -103,
    SOCK_NO_MORE_SOCKETS_RC = -104,
    SOCK_TIMED_OUT_RC = -105,
    SOCK_BAD_PORT_RC = -106,
    SOCK_BAD_SOCKET_RC = -107,
    SOCK_SOCKET_NOT_CONNECTED_RC = -108,
    SOCK_WOULD_BLOCK_RC = -109,
    SOCK_NET_DOWN_RC = -110,
    SOCK_NOT_ENOUGH_MEMORY_RC = -111,
    SOCK_SIZE_ERROR_RC = -112,
    SOCK_NO_MORE_DATA_RC = -113,
    SOCK_ADDR_NOT_AVAILABLE_RC = -114,
    SOCK_NOT_LISTENING_RC = -115,
    SOCK_NO_CONN_PENDING_RC = -116,
    SOCK_CONN_ABORTED_RC = -117,
    SOCK_CONN_RESET_RC = -118,
    SOCK_SHUTDOWN_RC = -119,
    SOCK_CONNECTION_CLOSED_RC = -120,
    SOCK_NO_PROTOCOL_RC = -121,
    SOCK_CONN_REFUSED_RC = -122,
    SOCK_TRY_AGAIN_RC = -123,
    SOCK_NO_RECOVERY_RC = -124,
    SOCK_IN_USE_RC = -125,
};
