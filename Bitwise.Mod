(*
 * Copyright (c) 2025 Your Name
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *)

MODULE Bitwise;

(** This module implements bitwise operations for the INTEGER and BYTE types.
    
    This is a portable implementation using Oberon-07 SET operations.
    While functional, it has some performance overhead due to type conversions.
    
    PERFORMANCE NOTE: For better performance, consider using ArtBitwise module
    which provides the same interface with optimized C implementations.
    
    PORTABILITY: This module should work on any compliant Oberon-07 system.
    The ArtBitwise module requires C compilation and is not portable.
*)
IMPORT SYSTEM;

PROCEDURE And8*(a, b: BYTE): BYTE;
(** Perform bitwise AND operation on two bytes. *)
VAR result: SET;
BEGIN
    result := SYSTEM.VAL(SET, a) * SYSTEM.VAL(SET, b);
    RETURN SYSTEM.VAL(BYTE, result)
END And8;

PROCEDURE And*(a, b: INTEGER): INTEGER;
(** Perform bitwise AND operation on two integers. *)
VAR result: SET;
BEGIN
    result := SYSTEM.VAL(SET, a) * SYSTEM.VAL(SET, b);
    RETURN SYSTEM.VAL(INTEGER, result)
END And;

PROCEDURE Or8*(a, b: BYTE): BYTE;
(** Perform bitwise OR operation on two bytes. *)
VAR result: SET;
BEGIN
    result := SYSTEM.VAL(SET, a) + SYSTEM.VAL(SET, b);
    RETURN SYSTEM.VAL(BYTE, result)
END Or8;

PROCEDURE Or*(a, b: INTEGER): INTEGER;
(** Perform bitwise OR operation on two integers. *)
VAR result: SET;
BEGIN
    result := SYSTEM.VAL(SET, a) + SYSTEM.VAL(SET, b);
    RETURN SYSTEM.VAL(INTEGER, result)
END Or;

PROCEDURE Xor8*(a, b: BYTE): BYTE;
(** Perform bitwise XOR operation on two bytes. *)
VAR result: SET;
BEGIN   
    result := SYSTEM.VAL(SET, a) / SYSTEM.VAL(SET, b);
    RETURN SYSTEM.VAL(BYTE, result)
END Xor8;

PROCEDURE Xor*(a, b: INTEGER): INTEGER;
(** Perform bitwise XOR operation on two integers. *)
VAR result: SET;
BEGIN   
    result := SYSTEM.VAL(SET, a) / SYSTEM.VAL(SET, b);
    RETURN SYSTEM.VAL(INTEGER, result)
END Xor;

PROCEDURE Not8*(a: BYTE): BYTE;
(** Perform bitwise NOT operation on a byte. *)
VAR result: SET;
BEGIN
    result := SYSTEM.VAL(SET, 0FFH) - SYSTEM.VAL(SET, a);
    RETURN SYSTEM.VAL(BYTE, result)
END Not8;

PROCEDURE Not*(a: INTEGER): INTEGER;
(** Perform bitwise NOT operation on an integer. *)
VAR result: SET;
BEGIN
    result := SYSTEM.VAL(SET, 0FFFFFFFFH) - SYSTEM.VAL(SET, a);
    RETURN SYSTEM.VAL(INTEGER, result)
END Not;

PROCEDURE ShiftLeft8*(a: BYTE; n: INTEGER): BYTE;
(** Perform shift left operation on a byte. *)
VAR 
    temp: INTEGER;
    result: INTEGER;
BEGIN
    temp := a;
    IF n >= 8 THEN
        result := 0
    ELSIF n < 0 THEN
        result := a
    ELSE
        result := LSL(temp, n) MOD 256
    END;
    RETURN SYSTEM.VAL(BYTE, result)
END ShiftLeft8;

PROCEDURE ShiftRight8*(a: BYTE; n: INTEGER): BYTE;
(** Perform logical shift right operation on a byte. *)
VAR 
    temp: INTEGER;
    result: INTEGER;
BEGIN
    temp := a;
    IF n >= 8 THEN
        result := 0
    ELSIF n < 0 THEN
        result := a
    ELSE
        (* For bytes, we always want logical shift (no sign extension) *)
        result := temp DIV LSL(1, n)  (* Equivalent to logical shift right *)
    END;
    RETURN SYSTEM.VAL(BYTE, result)
END ShiftRight8;

PROCEDURE RotateLeft8*(a: BYTE; n: INTEGER): BYTE;
(** Perform rotate left operation on a byte. *)
VAR
    normalizedN: INTEGER;
    temp: INTEGER;
    shifted: INTEGER;
    overflow: INTEGER;
    result: INTEGER;
BEGIN
    normalizedN := n MOD 8;
    temp := a;
    
    shifted := LSL(temp, normalizedN) MOD 256;
    overflow := ASR(temp, 8 - normalizedN);
    
    result := Or(shifted, overflow);
    RETURN SYSTEM.VAL(BYTE, result)
END RotateLeft8;

PROCEDURE RotateRight8*(a: BYTE; n: INTEGER): BYTE;
(** Perform rotate right operation on a byte. *)
VAR
    normalizedN: INTEGER;
    temp: INTEGER;
    shifted: INTEGER;
    overflow: INTEGER;
    result: INTEGER;
BEGIN
    normalizedN := n MOD 8;
    temp := a;
    
    shifted := ASR(temp, normalizedN);
    overflow := LSL(temp, 8 - normalizedN) MOD 256;
    
    result := Or(shifted, overflow);
    RETURN SYSTEM.VAL(BYTE, result)
END RotateRight8;

PROCEDURE ShiftLeft*(a: INTEGER; n: INTEGER): INTEGER;
(** Perform shift left operation on an integer. *)
VAR result: INTEGER;
BEGIN
    IF n >= 32 THEN
        result := 0
    ELSIF n < 0 THEN
        result := a
    ELSE
        result := LSL(a, n)
    END;
    RETURN result
END ShiftLeft;

PROCEDURE ShiftRight*(a: INTEGER; n: INTEGER): INTEGER;
(** Perform arithmetic shift right operation on an integer. *)
VAR result: INTEGER;
BEGIN
    IF n >= 32 THEN
        IF a < 0 THEN
            result := -1
        ELSE
            result := 0
        END
    ELSIF n < 0 THEN
        result := a
    ELSE
        result := ASR(a, n)
    END;
    RETURN result
END ShiftRight;

PROCEDURE LogicalShiftRight*(a: INTEGER; n: INTEGER): INTEGER;
(** Perform logical shift right operation on an integer (fills with zeros). *)
VAR 
    result: INTEGER;
    mask: INTEGER;
BEGIN
    IF n >= 32 THEN
        result := 0
    ELSIF n < 0 THEN
        result := a
    ELSE
        (* Use arithmetic shift but clear sign-extended bits for negative numbers *)
        result := ASR(a, n);
        IF a < 0 THEN
            (* Create mask to clear the sign-extended bits *)
            mask := ASR(7FFFFFFFH, n - 1);
            result := And(result, mask)
        END
    END;
    RETURN result
END LogicalShiftRight;

PROCEDURE RotateLeft*(a: INTEGER; n: INTEGER): INTEGER;
(** Perform rotate left operation on an integer. *)
VAR 
    normalizedN: INTEGER;
    result: INTEGER;
BEGIN
    normalizedN := n MOD 32;
    result := ROR(a, 32 - normalizedN);
    RETURN result
END RotateLeft;

PROCEDURE RotateRight*(a: INTEGER; n: INTEGER): INTEGER;
(** Perform rotate right operation on an integer. *)
VAR 
    normalizedN: INTEGER;
    result: INTEGER;
BEGIN
    normalizedN := n MOD 32;
    result := ROR(a, normalizedN);
    RETURN result
END RotateRight;

END Bitwise.