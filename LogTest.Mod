(** LogTest.Mod - Test module for Log

Copyright (C) 2025 Artemis Project

Released under The 3-Clause BSD License.
See https://opensource.org/licenses/BSD-3-Clause

This module tests the Log module functionality and demonstrates
proper usage of the opaque Logger type.
*)
MODULE LogTest;

IMPORT T := Tests, Log, Chars;

CONST 
  OVERLONG_MSG_LEN = Chars.MAXSTR + 10;

VAR 
  ts: T.TestSet;

PROCEDURE TestLoggerCreation(): BOOLEAN;
VAR 
  test: BOOLEAN;
  logger: Log.Logger;
  level, destination: INTEGER;
  timestampEnabled: BOOLEAN;
BEGIN
  test := TRUE;
  
  (* Test creating a console logger *)
  logger := Log.New(Log.INFO, Log.CONSOLE, "");
  T.ExpectedBool(logger # NIL, TRUE, "Logger created successfully", test);
  
  (* Test accessor procedures - information hiding in action *)
  level := Log.GetLevel(logger);
  T.ExpectedInt(Log.INFO, level, "GetLevel returns correct value", test);
  
  destination := Log.GetDestination(logger);
  T.ExpectedInt(Log.CONSOLE, destination, "GetDestination returns correct value", test);
  
  timestampEnabled := Log.GetTimestamp(logger);
  T.ExpectedBool(TRUE, timestampEnabled, "Timestamp enabled by default", test);
  
  (* Test setting properties *)
  Log.SetLevel(logger, Log.WARNING);
  level := Log.GetLevel(logger);
  T.ExpectedInt(Log.WARNING, level, "SetLevel updates correctly", test);
  
  Log.SetTimestamp(logger, FALSE);
  timestampEnabled := Log.GetTimestamp(logger);
  T.ExpectedBool(FALSE, timestampEnabled, "SetTimestamp updates correctly", test);
  
  Log.Close(logger);
  
  RETURN test
END TestLoggerCreation;

PROCEDURE TestLogLevels(): BOOLEAN;
VAR 
  test: BOOLEAN;
  logger: Log.Logger;
BEGIN
  test := TRUE;
  
  (* Create logger with DEBUG level *)
  logger := Log.New(Log.DEBUG, Log.CONSOLE, "");
  
  (* Test that all levels work *)
  Log.Debug(logger, "Debug message");
  Log.Info(logger, "Info message");
  Log.Warning(logger, "Warning message");
  Log.Error(logger, "Error message");
  
  (* Set higher level and test filtering *)
  Log.SetLevel(logger, Log.ERROR);
  
  (* These should be filtered out (not cause crashes) *)
  Log.Debug(logger, "Should not appear");
  Log.Info(logger, "Should not appear");
  Log.Warning(logger, "Should not appear");
  
  (* This should appear *)
  Log.Error(logger, "This should appear");
  
  Log.Close(logger);
  
  RETURN test
END TestLogLevels;

PROCEDURE TestFileLogging(): BOOLEAN;
VAR 
  test: BOOLEAN;
  logger: Log.Logger;
BEGIN
  test := TRUE;
  
  (* Test file logging - should fallback to console if file creation fails *)
  logger := Log.New(Log.INFO, Log.FILE, "test.log");
  T.ExpectedBool(logger # NIL, TRUE, "File logger created", test);
  
  Log.Debug(logger, "This won't show up");
  Log.Info(logger, "Test file logging message");
  Log.Warning(logger, "Test file logging message");
  Log.Error(logger, "Test file logging message");
  Log.Close(logger);
  
  RETURN test
END TestFileLogging;

PROCEDURE TestTruncation(): BOOLEAN;
VAR
  test: BOOLEAN;
  logger: Log.Logger;
  longMsg: ARRAY OVERLONG_MSG_LEN OF CHAR; (* Longer than MAX_MESSAGE_LEN *)
  i: INTEGER;
BEGIN
  test := TRUE;
  FOR i := 0 TO LEN(longMsg)-2 DO
    longMsg[i] := "A"
  END;
  longMsg[LEN(longMsg)-1] := 0X;

  logger := Log.New(Log.INFO, Log.CONSOLE, "");
  Log.Info(logger, longMsg);
  Log.Close(logger);

  (* Manual check: No crash, output is truncated, string is valid *)
  RETURN test
END TestTruncation;

BEGIN
  T.Init(ts, "Log");
  T.Add(ts, TestLoggerCreation);
  T.Add(ts, TestLogLevels);
  T.Add(ts, TestFileLogging);
  T.Add(ts, TestTruncation);
  ASSERT(T.Run(ts))
END LogTest.
