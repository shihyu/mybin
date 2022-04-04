////////////////////////////////////////////////////////////////////////////////////
// Copyright 2021 SlickEdit Inc. 
// You may modify, copy, and distribute the Slick-C Code (modified or unmodified) 
// only if all of the following conditions are met: 
//   (1) You do not include the Slick-C Code in any product or application 
//       designed to run independently of SlickEdit software programs; 
//   (2) You do not use the SlickEdit name, logos or other SlickEdit 
//       trademarks to market Your application; 
//   (3) You provide a copy of this license with the Slick-C Code; and 
//   (4) You agree to indemnify, hold harmless and defend SlickEdit from and 
//       against any loss, damage, claims or lawsuits, including attorney's fees, 
//       that arise or result from the use or distribution of Your application.
////////////////////////////////////////////////////////////////////////////////////
#pragma option(pedantic,on)
#include "slick.sh"
#include "math.sh"

/**
 * The "sc.math" namespace contains functions mirroring the functions 
 * found in the C math library, as well as some useful numeric constants, 
 * computed to 80 or 81 digits.
 */
namespace sc.math;


/**
 * Pi calculated to 80 digits.
 */
const Pi = 3.141592653589793238462643383279502884197169399375105820974944592307816406286209;

/**
 * Phi - golden ratio
 */
const Phi = 1.618033988749894848204586834365638117720309179805762862135448622705260462818902;

/**
 * e - Euler's number
 */
const Euler = 2.718281828459045235360287471352662497757247093699959574966967627724076630353548;

/**
 * sqrt(2) - Square root of 2
 */
const Sqrt2 = 1.414213562373095048801688724209698078569671875376948073176679737990732478462107;

/**
 * log(2)
 */
const Log2 = 0.6931471805599453094172321214581765680755001343602552541206800094933936219696947;

/**
 * log(10)
 */
const Log10 = 2.302585092994045684017991454684364207601101488628772976033327900967572609677352;

/**
 * Gauß’s constant (Guass's constant)
 */
const G = 0.8346268416740731862814297327990468089939930134903470024498273701036819927095264;

/**
 * Laplace limit
 */
const Laplace = 0.6627434193491815809747420971092529070562335491150224175203925349909718530865113;


/**
 * Huge value, to represent results that approach infinity.
 */
const HUGE_VAL = 999999999999999999999999999999999999999999999999999999999999999999999999999999999e+9999;

/**
 * Tiny value, to represent results that approach an infitessimal.
 */
const TINY_VAL = 1e-9999;


/**
 * Default precision of Slick-C large number math routines.
 */
const MAX_PRECISION = 80;
/**
 * Approximate number of digits precision of standard C fast double-precision math. 
 */
const LOW_PRECISION = 16;


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

/**
 * The modf() function breaks down the floating-point value x into fractional 
 * and integral parts. The signed fractional portion of {@code x} is returned. 
 * The integer portion is stored as a double value in {@code i}. 
 * Both the fractional and integral parts are given the same sign as x.
 * 
 * @param x      number to decompos
 * @param i      (output) set to integer part of {@code x}
 * 
 * @return 
 * Returns the fractional part of (@code x} 
 */
extern double modf(double x, double &i);

/** 
 * @return
 * Compute and return the square root of the given number. 
 * 
 * @param number     number to calculate root of 
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @note 
 * There is a constant in {@code math.sh} for {@code sqrt(2)} 
 *  
 * @categories Miscellaneous_Functions
 */
extern double sqrt(double number, int precision=sc.math.MAX_PRECISION);

/** 
 * @return
 * Compute and return the n'th root of the given number. 
 * 
 * @param x          number to calculate root of 
 * @param n          n'th root, for example, 2 for square root 
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
extern double nroot(double x, double n, int precision=sc.math.MAX_PRECISION);

/**
 * @return 
 * Return {@literal e} to the raised to the power of {@code x} 
 *  
 * @param x          power to exponentiate to (can be a floating point number)
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @note 
 * There is a constant ({@code Euler}) for {@literal e}.
 *  
 * @categories Miscellaneous_Functions
 */
extern double exp(double x, int precision=sc.math.MAX_PRECISION);

/**
 * @return 
 * Returns the natural logarithm (base {@literal e} logarithm) of {@code x}. 
 *  
 * @param x          number to calculate natural log of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @note 
 * There is a constant ({@code Euler}) for {@literal e}.
 *  
 * @categories Miscellaneous_Functions
 */
extern double ln(double x, int precision=sc.math.MAX_PRECISION);

/** 
 * @return 
 * Returns the base {@literal 2} logarithm of {@code x}.
 * 
 * @param x          number to calculate base 2 log of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions 
 *  
 * @note 
 * There is a constant ({@code Log2}) for the natural log of {@literal 2}.
 */
extern double log2(double x, int precision=sc.math.MAX_PRECISION);

/** 
 * @return 
 * Returns the common logarithm (base-10 logarithm) of {@code x}.
 * 
 * @param x          number to calculate base 10 log of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions 
 *  
 * @note 
 * There is a constant ({@code Log10}) for the natural log of {@literal 10}.
 */
extern double log10(double x, int precision=sc.math.MAX_PRECISION);

/** 
 * @return 
 * Returns the logarithm of {@code x} for the given {@code base}.
 * 
 * @param x          number to calculate base 'n' log of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions 
 */
extern double log(double x, int base, int precision=sc.math.MAX_PRECISION);

/**
 * @return 
 * Returns {@code x} raised to the {@code n}'th power. 
 * 
 * @param x         base (may be floating point)
 * @param n         exponent (may be floating point)
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions 
 */
extern double power(double x, double n, int precision=sc.math.MAX_PRECISION);

/** 
 * @return
 * Compute and return the factorial of {@code number}.
 * 
 * @param number     number to calculate factoral of
 *  
 * @categories Miscellaneous_Functions
 */
extern double fact(int number);

/** 
 * @return
 * Compute and return the n'th Bernoulli number (Bn).
 * 
 * @param number     number to calculate Bernoulli number corresponding to
 *  
 * @categories Miscellaneous_Functions 
 *  
 * @note 
 * For {@code n &gt; 150}, this starts to get innaccurate due to the 
 * limited precision of the Slick-C math routines. 
 */
extern double bernoulli(int number);

/** 
 * @return
 * Compute and return the n'th number in the Euler sequence (En).
 * 
 * @param number     number to calculate Euler number corresponding to
 *  
 * @categories Miscellaneous_Functions
 */
extern double euler(int number);

/** 
 * @return
 * Compute and return the n'th Bernoulli number as a rational number.
 * 
 * @param number        number to calculate Bernoulli number corresponding to 
 * @param numerator     (output) top part of ratio 
 * @param denominator   (output) bottom part of ratio
 *  
 * @categories Miscellaneous_Functions
 */
extern void bernoulli_ratio(int number, double &numerator, double &denominator);

/** 
 * @return 
 * Compute the greatest common divisor between two integers. 
 * If either number is zero, return the other number.
 * 
 * @param a      must be integer, otherwise returns 1
 * @param b      must be integer, otherwise returns 1
 *  
 * @categories Miscellaneous_Functions
 */
extern double gcd(double a, double b);

/** 
 * @return 
 * Compute the least common multiple between two integers. 
 * 
 * @param a      must be integer
 * @param b      must be integer
 *  
 * @categories Miscellaneous_Functions
 */
extern double lcm(double a, double b);


/**
 * The frexp() function breaks down the floating-point value x into a term 
 * {@code m} for the mantissa and another term {@code n} for the exponent. 
 * It is done such that {@code x = m * 2^n}, and the absolute value of 
 * {@code m} is greater than or equal to {@literal 0.5} and less than 
 * {@literal 1.0} or equal to {@literal 0}. 
 *  
 * The frexp() function stores the integer exponent {@code n} in the
 * second parameter and returns the mantissa {@code m}.
 * 
 * @param x          number to break down
 * @param exponent   (output) set to base 2 exponent for mantissa returned
 * 
 * @return double 
 * Returns the mantissa [@code m} as described above.
 */
extern double frexp(double x, int &exponent);

/** 
 * @return
 * The ldexp() function returns the value of {@code x * 2^n)}. 
 * 
 * @param x        mantissa (number base)
 * @param exponent base 2 exponent
 */
extern double ldexp(double x, int exponent);

/** 
 * @return
 * Returns the sine of a radian angle {@code x}.
 * 
 * @param x          number to calculate sin() of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
extern double sin(double x, int precision=sc.math.MAX_PRECISION);

/** 
 * @return 
 * Returns the cosine of a radian angle {@code x}. 
 * 
 * @param x          number to calculate cos() of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
extern double cos(double x, int precision=sc.math.MAX_PRECISION);

/** 
 * @return 
 * Returns the tangent of a radian angle {@code x}. 
 * 
 * @param x          number to calculate tan() of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions 
 *  
 * @note 
 * {@code tan(x)} is equivalent to {@code sin(x) / cos(x)}. 
 */
extern double tan(double x, int precision=sc.math.MAX_PRECISION);

/** 
 * @return
 * Returns the hyperbolic sine of a radian angle {@code x}.
 * 
 * @param x          number to calculate sinh() of (between -pi and pi)
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
extern double sinh(double x, int precision=sc.math.MAX_PRECISION);

/** 
 * @return 
 * Returns the hyberbolic cosine of a radian angle {@code x}. 
 * 
 * @param x          number to calculate cosh() of (between -pi and pi)
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
extern double cosh(double x, int precision=sc.math.MAX_PRECISION);

/** 
 * @return 
 * Returns the hyberbolic tangent of a radian angle {@code x}. 
 * 
 * @param x          number to calculate tanh() of (between -pi and pi)
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
extern double tanh(double x, int precision=sc.math.MAX_PRECISION);

/** 
 * @return
 * Returns the radian angle for the inverse sine of {@code x}.
 * 
 * @param x          number from sin() curve between -1 .. 1
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
extern double asin(double x, int precision=sc.math.MAX_PRECISION);

/** 
 * @return 
 * Returns the radian angle for the inverse cosine of {@code x}.
 * 
 * @param x          number from cos() curve between -1 .. 1
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
extern double acos(double x, int precision=sc.math.MAX_PRECISION);

/** 
 * @return 
 * Returns the radian angle for the inverse tangent of {@code x}.
 * 
 * @param x          number from tan() curve
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions 
 */
extern double atan(double x, int precision=sc.math.MAX_PRECISION);

/** 
 * @return 
 * Returns the arc tangent in radians of {@code y} / {@code x} based on the 
 * signs of both values to determine the correct quadrant. 
 * 
 * @param x          number from tan() curve
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions 
 */
extern double atan2(double x, double y, int precision=sc.math.MAX_PRECISION);


/**
 * @return 
 * Returns an angle converted from degrees to radians. 
 *  
 * @param deg    angle in degrees (0 .. 360)
 *  
 * @categories Miscellaneous_Functions
 */
double deg2rad(double deg) {
   rad := (deg / 180);
   rad *= Pi;
   return rad;
}

/**
 * @return 
 * Returns an angle converted from radians to degrees
 *  
 * @param rad    angle in radians (0 .. 2*Pi)
 *  
 * @categories Miscellaneous_Functions
 */
double rad2deg(double rad) {
   deg := rad * 180;
   deg /= Pi;
   return deg;
}

/** 
 * @return 
 * Returns the secant of a radian angle {@code x}. 
 * 
 * @param x          number to calculate secant() of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions 
 *  
 * @note 
 * {@code secant(x)} is equivalent to {@code 1 / sin(x)}. 
 */
double secant(double x, int precision=sc.math.MAX_PRECISION) {
   v := cos(x, precision);
   if (abs(v) <= TINY_VAL) {
      return (v < 0)? HUGE_VAL : -HUGE_VAL;
   }
   return (1.0 / v);
}

/** 
 * @return 
 * Returns the cosecant of a radian angle {@code x}. 
 * 
 * @param x          number to calculate cosecant() of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions 
 *  
 * @note 
 * {@code cosecant(x)} is equivalent to {@code 1 / cos(x)}. 
 */
double cosecant(double x, int precision=sc.math.MAX_PRECISION) {
   v := sin(x, precision);
   if (abs(v) <= TINY_VAL) {
      return (v < 0)? HUGE_VAL : -HUGE_VAL;
   }
   return (1.0 / v);
}

/** 
 * @return 
 * Returns the cotangent of a radian angle {@code x}. 
 * 
 * @param x          number to calculate cotangent() of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions 
 *  
 * @note 
 * {@code cotangent(x)} is equivalent to {@code cos(x) / sin(x)}. 
 */
double cotangent(double x, int precision=sc.math.MAX_PRECISION) {
   u := cos(x, precision);
   v := sin(x, precision);
   if (abs(v) <= TINY_VAL) {
      if ((u < 0 && v <= 0) || (u > 0 && v >= 0)) {
         return HUGE_VAL;
      }
      return -HUGE_VAL;
   }
   return (u / v);
}

/** 
 * @return
 * Returns the sine of an angle {@code deg} expressed in degrees.
 * 
 * @param deg        number to calculate sin() of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
double sind(double deg, int precision=sc.math.MAX_PRECISION) {
   return sin(deg2rad(deg % 360), precision);
}

/** 
 * @return 
 * Returns the cosine of an angle {@code deg} expressed in degrees.
 * 
 * @param deg        number to calculate cos() of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
double cosd(double deg, int precision=sc.math.MAX_PRECISION) {
   return cos(deg2rad(deg % 360), precision);
}

/** 
 * @return 
 * Returns the tangent of an angle {@code deg} expressed in degrees.
 * 
 * @param deg        number to calculate tan() of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
double tand(double deg, int precision=sc.math.MAX_PRECISION) {
   return tan(deg2rad(deg % 180), precision);
}

/** 
 * @return
 * Returns the hyperbolic sine of an angle {@code deg} expressed in degrees.
 * 
 * @param deg        number to calculate sinh() of (between -360 and 360)
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
double sinhd(double deg, int precision=sc.math.MAX_PRECISION) {
   return sinh(deg2rad(deg % 360), precision);
}

/** 
 * @return 
 * Returns the hyperbolic cosine of an angle {@code deg} expressed in degrees.
 * 
 * @param deg        number to calculate cosh() of (between -360 and 360)
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
double coshd(double deg, int precision=sc.math.MAX_PRECISION) {
   return cosh(deg2rad(deg % 360), precision);
}

/** 
 * @return 
 * Returns the hyperbolic tangent of an angle {@code deg} expressed in degrees.
 * 
 * @param deg        number to calculate tanh() of (between -360 and 360)
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
double tanhd(double deg, int precision=sc.math.MAX_PRECISION) {
   return tanh(deg2rad(deg), precision);
}

/** 
 * @return 
 * Returns the secant of an angle {@code deg} expressed in degrees.
 * 
 * @param deg        number to calculate secant() of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
double secantd(double deg, int precision=sc.math.MAX_PRECISION) {
   return secant(deg2rad(deg), precision);
}

/** 
 * @return 
 * Returns the cosecant of an angle {@code deg} expressed in degrees.
 * 
 * @param deg        number to calculate cosecant() of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
double cosecantd(double deg, int precision=sc.math.MAX_PRECISION) {
   return cosecant(deg2rad(deg), precision);
}

/** 
 * @return 
 * Returns the cotangent of an angle {@code deg} expressed in degrees.
 * 
 * @param deg        number to calculate cotangent() of
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
double cotangentd(double deg, int precision=sc.math.MAX_PRECISION) {
   return cotangent(deg2rad(deg), precision);
}

/** 
 * @return
 * Returns the angle in degrees for the inverse sine of {@code x}.
 * 
 * @param x          number from sin() curve between -1 .. 1
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
double asind(double x, int precision=sc.math.MAX_PRECISION) {
   return rad2deg(asin(x, precision));
}

/** 
 * @return 
 * Returns the angle in degrees for the inverse cosine of {@code x}.
 * 
 * @param x          number from cos() curve between -1 .. 1
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions
 */
double acosd(double x, int precision=sc.math.MAX_PRECISION) {
   return rad2deg(acos(x, precision));
}

/** 
 * @return 
 * Returns the angle in degrees for the inverse tangent of {@code x}.
 * 
 * @param x          number from tan() curve
 * @param precision  number of digits of precision to calculate to. 
 *                   If {@literal 16} or less, will use standard
 *                   fast double-precision C math routines
 *  
 * @categories Miscellaneous_Functions 
 */
double atand(double x, int precision=sc.math.MAX_PRECISION) {
   return rad2deg(atan(x, precision));
}

