/*
 * artBitwise.c - Optimized C implementation of bitwise operations
 * 
 * This provides the same interface as Bitwise.Mod but with optimized
 * C implementations for better performance and correctness.
 * 
 * Copyright (C) 2025
 * Released under The 3-Clause BSD License.
 */

#include ".obnc/artBitwise.h"
#include <obnc/OBNC.h>

static int initialized = 0;

unsigned char artBitwise__And8_(unsigned char a_, unsigned char b_)
{
    return a_ & b_;
}

OBNC_INTEGER artBitwise__And_(OBNC_INTEGER a_, OBNC_INTEGER b_)
{
    return a_ & b_;
}

unsigned char artBitwise__Or8_(unsigned char a_, unsigned char b_)
{
    return a_ | b_;
}

OBNC_INTEGER artBitwise__Or_(OBNC_INTEGER a_, OBNC_INTEGER b_)
{
    return a_ | b_;
}

unsigned char artBitwise__Xor8_(unsigned char a_, unsigned char b_)
{
    return a_ ^ b_;
}

OBNC_INTEGER artBitwise__Xor_(OBNC_INTEGER a_, OBNC_INTEGER b_)
{
    return a_ ^ b_;
}

unsigned char artBitwise__Not8_(unsigned char a_)
{
    return ~a_;
}

OBNC_INTEGER artBitwise__Not_(OBNC_INTEGER a_)
{
    return ~a_;
}

unsigned char artBitwise__ShiftLeft8_(unsigned char a_, OBNC_INTEGER n_)
{
    if (n_ >= 8 || n_ < 0) {
        return (n_ < 0) ? a_ : 0;
    }
    return (unsigned char)((a_ << n_) & 0xFF);
}

unsigned char artBitwise__ShiftRight8_(unsigned char a_, OBNC_INTEGER n_)
{
    if (n_ >= 8 || n_ < 0) {
        return (n_ < 0) ? a_ : 0;
    }
    return a_ >> n_;
}

unsigned char artBitwise__RotateLeft8_(unsigned char a_, OBNC_INTEGER n_)
{
    OBNC_INTEGER normalizedN_ = n_ % 8;
    if (normalizedN_ < 0) normalizedN_ += 8;
    if (normalizedN_ == 0) return a_;
    
    return (unsigned char)(((a_ << normalizedN_) | (a_ >> (8 - normalizedN_))) & 0xFF);
}

unsigned char artBitwise__RotateRight8_(unsigned char a_, OBNC_INTEGER n_)
{
    OBNC_INTEGER normalizedN_ = n_ % 8;
    if (normalizedN_ < 0) normalizedN_ += 8;
    if (normalizedN_ == 0) return a_;
    
    return (unsigned char)(((a_ >> normalizedN_) | (a_ << (8 - normalizedN_))) & 0xFF);
}

OBNC_INTEGER artBitwise__ShiftLeft_(OBNC_INTEGER a_, OBNC_INTEGER n_)
{
    if (n_ >= 32 || n_ < 0) {
        return (n_ < 0) ? a_ : 0;
    }
    return a_ << n_;
}

OBNC_INTEGER artBitwise__ShiftRight_(OBNC_INTEGER a_, OBNC_INTEGER n_)
{
    if (n_ >= 32) {
        return (a_ < 0) ? -1 : 0;
    }
    if (n_ < 0) {
        return a_;
    }
    return a_ >> n_;
}

OBNC_INTEGER artBitwise__RotateLeft_(OBNC_INTEGER a_, OBNC_INTEGER n_)
{
    OBNC_INTEGER normalizedN_ = n_ % 32;
    if (normalizedN_ < 0) normalizedN_ += 32;
    if (normalizedN_ == 0) return a_;
    
    return ((unsigned OBNC_INTEGER)a_ << normalizedN_) | ((unsigned OBNC_INTEGER)a_ >> (32 - normalizedN_));
}

OBNC_INTEGER artBitwise__RotateRight_(OBNC_INTEGER a_, OBNC_INTEGER n_)
{
    OBNC_INTEGER normalizedN_ = n_ % 32;
    if (normalizedN_ < 0) normalizedN_ += 32;
    if (normalizedN_ == 0) return a_;
    
    return ((unsigned OBNC_INTEGER)a_ >> normalizedN_) | ((unsigned OBNC_INTEGER)a_ << (32 - normalizedN_));
}

void artBitwise__Init(void)
{
    if (!initialized) {
        initialized = 1;
        /* No initialization needed for this module */
    }
}