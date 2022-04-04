////////////////////////////////////////////////////////////////////////////////
// Copyright 2021 SlickEdit Inc.
////////////////////////////////////////////////////////////////////////////////
// File:          SENumber.h
// Description:   Declaration of class to represent high-preciion numbers.
////////////////////////////////////////////////////////////////////////////////
#pragma once
#include "vsdecl.h"
#include "slickedit/SEString.h"
#include "slickedit/SESharedPointer.h"

// forward declarations
struct sinumber_t;

namespace slickedit {

/** 
 * This class respresents a high-precision floating point number. 
 */
class VSDLLEXPORT SENumber
{
public:
   /**
    * Default constructor (will construct a null instance)
    */
   SENumber();

   /**
    * Simple constructor
    */
   SENumber(const int i);
   SENumber(const VSINT64 i);
   SENumber(const double d);
   SENumber(const sinumber_t &num);

   /**
    * Copy constructor
    */
   SENumber(const SENumber& src);

   /**
    * Move constructor
    */
   SENumber(SENumber&& src);

   /**
    * Destructor
    */
   virtual ~SENumber();

   /**
    * Assignment operator
    */
   SENumber &operator = (const SENumber &src);
   /**
    * Move assignment operator
    */
   SENumber &operator = (SENumber &&src);

   /**
    * Simple assign to a number value.
    */
   SENumber &operator = (const int i);
   SENumber &operator = (const VSINT64 i);
   SENumber &operator = (const double i);
   SENumber &operator = (const sinumber_t &num);

   /**
    * Hash function,used by SEHashSet
    */
   unsigned int hash() const;

   /**
    * Clear the contents of this symbol (set's it to zero)
    */
   void setZero();
   /**
    * @return 
    * Return {@code true} if this object is zero. 
    * For this case, null is considered as zero. 
    */
   const bool isZero() const;
   /**
    * @return Return {@code true} if this object is null.
    */
   const bool isNull() const;
   /**
    * Make this instance null, that is the same state as it is in 
    * after it is initially constructed. 
    */
   void setNull();

   /**
    * Return reference to underlying number representation.
    */
   const struct sinumber_t &getAsNumber() const;

private:

   // Pointer to private implementation
   SESharedPointer<struct SEPrivateNumberImpl> mpNumber;

};

} // namespace slickedit


extern unsigned cmHashKey(const slickedit::SENumber &cm);

