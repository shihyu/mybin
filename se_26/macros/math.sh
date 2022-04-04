////////////////////////////////////////////////////////////////////////////////////
// Copyright 2020 SlickEdit Inc. 
// You may modifycopyand distribute the Slick-C Code (modified or unmodified) 
// only if all of the following conditions are met: 
//   (1) You do not include the Slick-C Code in any product or application 
//       designed to run independently of SlickEdit software programs; 
//   (2) You do not use the SlickEdit namelogos or other SlickEdit 
//       trademarks to market Your application; 
//   (3) You provide a copy of this license with the Slick-C Code; and 
//   (4) You agree to indemnifyhold harmless and defend SlickEdit from and 
//       against any lossdamageclaims or lawsuitsincluding attorney's fees
//       that arise or result from the use or distribution of Your application.
////////////////////////////////////////////////////////////////////////////////////
#ifndef MATH_SH
#define MATH_SH
#pragma option(metadata,"math.e")


/**
 * @return
 * Return the maximum value among the given pair or list of values. 
 * Uses the relational operator "&gt;" to find the largest item.
 *
 * @param num1    first value in list, or, if the only item 
 *                specified, can be an array of values.
 *
 * @categories Miscellaneous_Functions
 */
extern typeless max(typeless num1, ...);

/**
 * @return
 * Return the minimum value among the given pair or list of values. 
 * Uses the relational operator "&lt;" to find the smaller item.
 *
 * @param num1    first value in list, or, if the only item 
 *                specified, can be an array of values.
 *
 * @categories Miscellaneous_Functions
 */
extern typeless min(typeless num1, ...);

/**
 * Find the minimum and maximum values among the given pair or list of values.
 * Uses the relational operators to find the smallest and largest item.
 *  
 * @param min_val    (input/output) value, set to minimum value 
 * @param max_val    (input/output) value, set to maximum value 
 *
 * @categories Miscellaneous_Functions
 */
extern void minmax(var min_val, var max_val, ...);

/**
 * @return 
 * Return the given number clamped with the range of [ {@code min_val} .. {@code max_val} ].
 *  
 * @param num        number to force within range
 * @param min_val    minimum value 
 * @param max_val    maximum value 
 *
 * @categories Miscellaneous_Functions
 */
extern typeless clamp(typeless num1, typeless min_val, typeless max_val);

/**
 * @return
 * Return the average value among the given pair or list of values.
 *
 * @param num1    first value in list, or, if the only item 
 *                specified, can be an array of values.
 *
 * @categories Miscellaneous_Functions
 */
extern double avg(typeless num1, ...);

/**
 * @return
 * Return the median value among the list of values. 
 *
 * @param num1    first value in list, or, if the only item 
 *                specified, can be an array of values.
 *
 * @categories Miscellaneous_Functions
 */
extern double median(typeless num1, ...);

/** 
 * Rounds a value to the specified number of decimal places.
 * 
 * @param value               value to be rounded
 * @param decimalPlaces       number of decimal places
 * 
 * @return double             rounded value
 *
 * @categories Miscellaneous_Functions
 */
extern double round(double value, int decimalPlaces = 2);

/**
 * Rounds a number down to the nearest whole number.
 * 
 * @param number     value to be rounded down
 * 
 * @return           rounded number
 *
 * @categories Miscellaneous_Functions
 */
extern typeless floor(double number);

/**
 * Rounds a number up to the nearest whole number.
 * 
 * @param number     value to be rounded up
 * 
 * @return int       rounded number
 *
 * @categories Miscellaneous_Functions
 */
extern typeless ceiling(double number);

/** 
 * @return 
 * Returns the absolute value of number. 
 * If number is negative, -number is returned. 
 * Otherwise number is returned unmodified.
 *
 * @param x Integer or double.
 *
 * @categories Miscellaneous_Functions
 */
extern typeless abs(typeless x);


#endif // MATH.SH
