#pragma once

enum CMERROR_UNICODE {
    CMRC_UNICODE_INVALID_CODE_PAGE = -102799,
    CMRC_UNICODE_CODE_PAGES_WITH_LEAD_BYTES_BELOW_128_NOT_SUPPORTED = -102798,
    CMRC_UNICODE_CODE_PAGES_WITH_UNDEFINED_CHARACTERS_BELOW_128_NOT_SUPPORTED = -102797,
    CMRC_UNICODE_CODE_PAGES_WITH_TRANSLATED_CHARACTERS_BELOW_128_NOT_SUPPORTED = -102796,
    CMRC_UNICODE_CODE_PAGES_WITH_SURROGATES_NOT_SUPPORTED = -102795,
    CMRC_UNICODE_IMCOMPLETE_UTF8_CHARACTER = -102794,
    CMRC_UNICODE_CODE_PAGE_FILENAME_NOT_SET = -102793,
    CMRC_UNICODE_INVALID_CODEPAGE_FILE = -102792,
    CMRC_UNICODE_ERROR_READING_CODEPAGE_FILE = -102791,
    CMRC_UNICODE_CODE_PAGE_NOT_FOUND = -102790,
    CMRC_UNICODE_CODE_PAGE_NOT_LOADED = -102789,
    CMRC_UNICODE_INVALID_ENCODING = -102788,
    CMRCEND_UNICODE = -102800,
};
