(** CRC32Test.Mod - Tests for CRC32.Mod.

Copyright (C) 2025

Released under The 3-Clause BSD License.
*)
MODULE CRC32Test;
IMPORT CRC32, Tests;

VAR
  ts: Tests.TestSet;

PROCEDURE TestStringCRC32Simple*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  result: INTEGER;
BEGIN
  pass := TRUE;
  
  (* Test CRC32 for "a" - expected: 0E8B7BE43H *)
  result := CRC32.CalculateString("a");
  Tests.ExpectedInt(0E8B7BE43H, result, "CRC32 for 'a' incorrect", pass);
  
  RETURN pass
END TestStringCRC32Simple;

PROCEDURE TestStringCRC32Multiple*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  result: INTEGER;
BEGIN
  pass := TRUE;
  
  (* Test CRC32 for "abc" - expected: 0352441C2H *)
  result := CRC32.CalculateString("abc");
  Tests.ExpectedInt(0352441C2H, result, "CRC32 for 'abc' incorrect", pass);
  
  (* Test CRC32 for "message digest" - expected: 020159D7FH *)
  result := CRC32.CalculateString("message digest");
  Tests.ExpectedInt(020159D7FH, result, "CRC32 for 'message digest' incorrect", pass);
  
  RETURN pass
END TestStringCRC32Multiple;

PROCEDURE TestCalculatorBasic*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  calc: CRC32.Calculator;
  result: INTEGER;
BEGIN
  pass := TRUE;
  
  (* Test using Calculator directly *)
  calc := CRC32.NewCalculator();
  CRC32.Init(calc);
  CRC32.UpdateByte(calc, ORD("a"));
  result := CRC32.Finalize(calc);
  Tests.ExpectedInt(0E8B7BE43H, result, "CRC32 Calculator for 'a' incorrect", pass);
  
  RETURN pass
END TestCalculatorBasic;

PROCEDURE TestToString*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  hexStr: ARRAY 16 OF CHAR;
  expected: ARRAY 16 OF CHAR;
BEGIN
  pass := TRUE;
  
  (* Test ToString conversion *)
  CRC32.ToString(0E8B7BE43H, hexStr);
  expected := "e8b7be43";
  Tests.ExpectedString(expected, hexStr, "CRC32.ToString incorrect", pass);
  
  RETURN pass
END TestToString;

BEGIN
  Tests.Init(ts, "CRC32 Tests");
  Tests.Add(ts, TestStringCRC32Simple);
  Tests.Add(ts, TestStringCRC32Multiple);
  Tests.Add(ts, TestCalculatorBasic);
  Tests.Add(ts, TestToString);
  ASSERT(Tests.Run(ts))
END CRC32Test.
