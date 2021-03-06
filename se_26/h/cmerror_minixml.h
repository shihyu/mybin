#pragma once

enum CMERROR_MINIXML {
    CMRC_MINIXML_INVALID_COMMENT = -102999,
    CMRC_MINIXML_EXPECTING_ELEMENT_NAME = -102998,
    CMRC_MINIXML_UNTERMINATED_END_TAG = -102997,
    CMRC_MINIXML_XML_DECLARATION_INCORRECTLY_TERMINATED = -102996,
    CMRC_MINIXML_START_TAG_INCORRECTLY_TERMINATED = -102995,
    CMRC_MINIXML_UNEXPECTED_END_OF_FILE = -102994,
    CMRC_MINIXML_INVALID_BINARY_CHARACTER = -102993,
    CMRC_MINIXML_MISSING_ATTRIBUTE_NAME = -102992,
    CMRC_MINIXML_EXPECTING_EQUAL_SIGN = -102991,
    CMRC_MINIXML_EXPECTING_QUOTED_STRING = -102990,
    CMRC_MINIXML_QUOTED_STRING_NOT_TERMINATED = -102989,
    CMRC_MINIXML_UNTERMINATED_PROCESSING_INSTRUCTION = -102988,
    CMRC_MINIXML_UNTERMINATED_COMMMENT = -102987,
    CMRC_MINIXML_UNTERMINATED_CDATA = -102986,
    CMRC_MINIXML_NO_ROOT_ELEMENT_IN_DOCTYPE = -102985,
    CMRC_MINIXML_EXPECTING_SYSTEM_OR_PUBLIC_ID = -102984,
    CMRC_MINIXML_UNTERMINATED_DOCTYPE_DECLARATION = -102983,
    CMRC_MINIXML_TOO_MANY_END_TAGS = -102982,
    CMRC_MINIXML_MISMATCHED_END_TAG = -102981,
    CMRC_MINIXML_MISSING_END_TAG = -102980,
    CMRC_MINIXML_INVALID_XML_DECLARATION = -102979,
    CMRC_MINIXML_XML_DECLARATION_MUST_BE_FIRST = -102978,
    CMRC_XPATH_INVALID_CHARACTER = -102977,
    CMRC_XPATH_STRING_NOT_TERMINATED = -102976,
    CMRC_XPATH_ITEM_COULD_NOT_BE_CONVERTED_TO_NUMBER = -102975,
    CMRC_XPATH_STRING_COULD_NOT_BE_CONVERTED_TO_NUMBER = -102974,
    CMRC_XPATH_STRING_COULD_NOT_BE_CONVERTED_TO_BOOLEAN = -102973,
    CMRC_XPATH_CONVERTING_SEQUENCE_LIST_TO_NUMBER_NOT_SUPPORTED = -102972,
    CMRC_XPATH_CONVERTING_SEQUENCE_LIST_TO_BOOLEAN_NOT_SUPPORTED = -102971,
    CMRC_XPATH_CONVERTING_SEQUENCE_LIST_TO_STRING_NOT_SUPPORTED = -102970,
    CMRC_XPATH_LIST_WITH_MORE_THAN_ONE_ITEM_CAN_NOT_BE_CONVERTED_TO_STRING = -102969,
    CMRC_XPATH_BOOLEAN_ARGUMENT_SPECIFIED_EXPECTING_STRING_ARGUMENT = -102968,
    CMRC_XPATH_INTEGER_ARGUMENT_SPECIFIED_EXPECTING_STRING_ARGUMENT = -102967,
    CMRC_XPATH_EXPRESSION_MUST_BE_COMPILED_BEFORE_EVALUATION = -102966,
    CMRC_XPATH_EXPRESSION_DOES_NOT_EVALUATE_TO_A_SINGLE_NODE = -102965,
    CMRC_XPATH_EXPRESSION_TOO_COMPLEX = -102964,
    CMRC_XPATH_EXPECTING_CLOSE_BRACKET = -102963,
    CMRC_XPATH_SEARCHING_FOR_A_LOCAL_NAME_WITHIN_A_NAMESPACE_NOT_SUPPORTED = -102962,
    CMRC_XPATH_INVALID_AXIS_NAME_1ARG = -102961,
    CMRC_INVALID_UNKNOWN_FUNCTION_1ARG = -102960,
    CMRC_XPATH_EXPECTING_PROCESSING_INSTRUCTION_NAME = -102959,
    CMRC_XPATH_EXPECTING_CLOSE_PAREN = -102958,
    CMRC_XPATH_PREDICATE_EXPRESSIONS_NOT_YET_SUPPORTED_AFTER_PAREN = -102957,
    CMRC_XPATH_BINARY_OPERATOR_NOT_YET_SUPPORTED = -102956,
    CMRC_XPATH_EXPECTING_NODE_TEST = -102955,
    CMRC_XPATH_INVALID_OR_UNSUPPORTED_EXPRESSION = -102954,
    CMRC_XPATH_UNARY_MINUS_ONLY_SUPPORTED_FOR_CONSTANT_INTEGER = -102953,
    CMRC_XPATH_NOT_ENOUGH_ARGUMENTS = -102952,
    CMRC_XPATH_TOO_MANY_ARGUMENTS = -102951,
    CMRC_XPATH_ERROR_PARSING_FUNCTION_ARGUMENTS = -102950,
    CMRC_XPATH_EXPRESSION_DOES_NOT_EVALUATE_TO_A_SEQUENCE = -102949,
    CMRC_XPATH_EXTRA_CHARACTERS = -102948,
    CMRCEND_MINIXML = -103000,
};
