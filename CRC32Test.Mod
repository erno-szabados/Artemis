(** CRC32Test.Mod - Tests for CRC32.Mod.

Copyright (C) 2025

Released under The 3-Clause BSD License.
*)
MODULE CRC32Test;
IMPORT CRC32, Tests, Files;

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
  
  (* Test ToString with zero *)
  CRC32.ToString(0, hexStr);
  expected := "00000000";
  Tests.ExpectedString(expected, hexStr, "CRC32.ToString for zero incorrect", pass);
  
  (* Test ToString with all 1s *)
  CRC32.ToString(0FFFFFFFFH, hexStr);
  expected := "ffffffff";
  Tests.ExpectedString(expected, hexStr, "CRC32.ToString for 0xFFFFFFFF incorrect", pass);
  
  RETURN pass
END TestToString;

PROCEDURE TestEmptyString*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  result: INTEGER;
BEGIN
  pass := TRUE;
  
  (* Test CRC32 for empty string - expected: 0 *)
  result := CRC32.CalculateString("");
  Tests.ExpectedInt(0, result, "CRC32 for empty string incorrect", pass);
  
  RETURN pass
END TestEmptyString;

PROCEDURE TestLongString*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  result: INTEGER;
BEGIN
  pass := TRUE;
  
  (* Test CRC32 for pangram - expected: 0414FA339H *)
  result := CRC32.CalculateString("The quick brown fox jumps over the lazy dog");
  Tests.ExpectedInt(0414FA339H, result, "CRC32 for pangram incorrect", pass);
  
  RETURN pass
END TestLongString;

PROCEDURE TestCalculatorIncremental*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  calc: CRC32.Calculator;
  result, directResult: INTEGER;
BEGIN
  pass := TRUE;
  
  (* Test incremental calculation vs direct calculation *)
  calc := CRC32.NewCalculator();
  CRC32.Init(calc);
  CRC32.UpdateByte(calc, ORD("a"));
  CRC32.UpdateByte(calc, ORD("b"));
  CRC32.UpdateByte(calc, ORD("c"));
  result := CRC32.Finalize(calc);
  
  directResult := CRC32.CalculateString("abc");
  Tests.ExpectedInt(directResult, result, "Incremental calculation mismatch", pass);
  
  RETURN pass
END TestCalculatorIncremental;

PROCEDURE TestCalculatorReset*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  calc: CRC32.Calculator;
  result1, result2: INTEGER;
BEGIN
  pass := TRUE;
  
  (* Test calculator can be reused *)
  calc := CRC32.NewCalculator();
  
  (* First calculation *)
  CRC32.Init(calc);
  CRC32.UpdateByte(calc, ORD("a"));
  result1 := CRC32.Finalize(calc);
  
  (* Reset and second calculation *)
  CRC32.Init(calc);
  CRC32.UpdateByte(calc, ORD("a"));
  result2 := CRC32.Finalize(calc);
  
  Tests.ExpectedInt(result1, result2, "Calculator reset failed", pass);
  Tests.ExpectedInt(0E8B7BE43H, result1, "Calculator reuse first result incorrect", pass);
  Tests.ExpectedInt(0E8B7BE43H, result2, "Calculator reuse second result incorrect", pass);
  
  RETURN pass
END TestCalculatorReset;

PROCEDURE TestUpdateBuffer*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  calc: CRC32.Calculator;
  buffer: ARRAY 5 OF BYTE;
  result, directResult: INTEGER;
BEGIN
  pass := TRUE;
  
  (* Test UpdateBuffer vs individual UpdateByte calls *)
  buffer[0] := ORD("a");
  buffer[1] := ORD("b");
  buffer[2] := ORD("c");
  
  calc := CRC32.NewCalculator();
  CRC32.Init(calc);
  CRC32.UpdateBuffer(calc, buffer, 3);
  result := CRC32.Finalize(calc);
  
  directResult := CRC32.CalculateString("abc");
  Tests.ExpectedInt(directResult, result, "UpdateBuffer calculation mismatch", pass);
  
  RETURN pass
END TestUpdateBuffer;

PROCEDURE TestBinaryData*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  calc: CRC32.Calculator;
  buffer: ARRAY 5 OF BYTE;
  result: INTEGER;
BEGIN
  pass := TRUE;
  
  (* Test with binary data: 00 01 02 03 FF *)
  buffer[0] := 0;
  buffer[1] := 1;
  buffer[2] := 2;
  buffer[3] := 3;
  buffer[4] := 255;
  
  calc := CRC32.NewCalculator();
  CRC32.Init(calc);
  CRC32.UpdateBuffer(calc, buffer, 5);
  result := CRC32.Finalize(calc);
  
  (* Expected: 07B35F858H *)
  Tests.ExpectedInt(07B35F858H, result, "CRC32 for binary data incorrect", pass);
  
  RETURN pass
END TestBinaryData;

(* Helper to create a test file with given content *)
PROCEDURE CreateTestFile(content: ARRAY OF CHAR; filename: ARRAY OF CHAR; VAR file: Files.File);
VAR writer: Files.Rider; i: INTEGER;
BEGIN
    file := Files.New(filename);
    Files.Set(writer, file, 0);
    i := 0;
    WHILE (i < LEN(content)) & (content[i] # 0X) DO
        Files.Write(writer, ORD(content[i]));
        INC(i)
    END;
    Files.Register(file)
END CreateTestFile;

PROCEDURE TestCalculateFile*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  file: Files.File;
  checksum: INTEGER;
  success: BOOLEAN;
  res: INTEGER;
  content: ARRAY 64 OF CHAR;
BEGIN
  pass := TRUE;
  
  (* Test with simple file content *)
  content := "abc";
  CreateTestFile(content, "test_crc.tmp", file);
  Files.Close(file);
  
  CRC32.CalculateFile("test_crc.tmp", checksum, success);
  Tests.ExpectedBool(TRUE, success, "CalculateFile should succeed", pass);
  Tests.ExpectedInt(0352441C2H, checksum, "File CRC32 for 'abc' incorrect", pass);
  
  (* Clean up *)
  Files.Delete("test_crc.tmp", res);
  
  (* Test with non-existent file *)
  CRC32.CalculateFile("nonexistent.tmp", checksum, success);
  Tests.ExpectedBool(FALSE, success, "CalculateFile should fail for non-existent file", pass);
  
  RETURN pass
END TestCalculateFile;

PROCEDURE TestCalculateRider*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  file: Files.File;
  rider: Files.Rider;
  checksum: INTEGER;
  success: BOOLEAN;
  res: INTEGER;
  content: ARRAY 64 OF CHAR;
BEGIN
  pass := TRUE;
  
  (* Create test file with longer content *)
  content := "The quick brown fox";
  CreateTestFile(content, "test_rider.tmp", file);
  Files.Close(file);
  
  (* Reopen file for reading *)
  file := Files.Old("test_rider.tmp");
  Files.Set(rider, file, 0);
  
  (* Test calculating part of file - first 3 characters "The" *)
  CRC32.CalculateRider(rider, 3, checksum, success);
  Tests.ExpectedBool(TRUE, success, "CalculateRider should succeed", pass);
  
  (* Compare with direct string calculation *)
  Tests.ExpectedInt(CRC32.CalculateString("The"), checksum, "Rider CRC32 for 'The' incorrect", pass);
  
  (* Test calculating rest of file starting from current position *)
  CRC32.CalculateRider(rider, 16, checksum, success); (* " quick brown fox" = 16 chars *)
  Tests.ExpectedBool(TRUE, success, "CalculateRider remainder should succeed", pass);
  Tests.ExpectedInt(CRC32.CalculateString(" quick brown fox"), checksum, "Rider CRC32 for remainder incorrect", pass);
  
  Files.Close(file);
  Files.Delete("test_rider.tmp", res);
  
  RETURN pass
END TestCalculateRider;

PROCEDURE TestExistingTestFile*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  checksum: INTEGER;
  success: BOOLEAN;
BEGIN
  pass := TRUE;
  
  (* Test with an existing file from test_data directory *)
  CRC32.CalculateFile("test_data/empty.ini", checksum, success);
  Tests.ExpectedBool(TRUE, success, "Empty test file should be readable", pass);
  Tests.ExpectedInt(0, checksum, "Empty file CRC32 should be 0", pass);
  
  RETURN pass
END TestExistingTestFile;

PROCEDURE TestEdgeCases*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  calc: CRC32.Calculator;
  result: INTEGER;
BEGIN
  pass := TRUE;
  
  (* Test with single character strings *)
  result := CRC32.CalculateString("0");
  Tests.ExpectedInt(0F4DBDF21H, result, "CRC32 for '0' incorrect", pass);
  
  result := CRC32.CalculateString("1");
  Tests.ExpectedInt(083DCEFB7H, result, "CRC32 for '1' incorrect", pass);
  
  (* Test UpdateBuffer with zero length *)
  calc := CRC32.NewCalculator();
  CRC32.Init(calc);
  result := CRC32.Finalize(calc);
  Tests.ExpectedInt(0, result, "CRC32 for no updates incorrect", pass);
  
  RETURN pass
END TestEdgeCases;

BEGIN
  Tests.Init(ts, "CRC32 Tests");
  Tests.Add(ts, TestStringCRC32Simple);
  Tests.Add(ts, TestStringCRC32Multiple);
  Tests.Add(ts, TestCalculatorBasic);
  Tests.Add(ts, TestToString);
  Tests.Add(ts, TestEmptyString);
  Tests.Add(ts, TestLongString);
  Tests.Add(ts, TestCalculatorIncremental);
  Tests.Add(ts, TestCalculatorReset);
  Tests.Add(ts, TestUpdateBuffer);
  Tests.Add(ts, TestBinaryData);
  Tests.Add(ts, TestCalculateFile);
  Tests.Add(ts, TestCalculateRider);
  Tests.Add(ts, TestExistingTestFile);
  Tests.Add(ts, TestEdgeCases);
  ASSERT(Tests.Run(ts))
END CRC32Test.
