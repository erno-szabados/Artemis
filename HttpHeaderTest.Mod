MODULE HttpHeaderTest;

IMPORT HttpHeader, Tests, DStrings, Out, Chars;

VAR
  ts : Tests.TestSet;

PROCEDURE TestInit*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  h: HttpHeader.Header;
BEGIN
  pass := TRUE;
  HttpHeader.Init(h);
  Tests.ExpectedBool(h # NIL, TRUE, "Header initialized", pass);
  RETURN pass
END TestInit;

PROCEDURE TestSetGet*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  h: HttpHeader.Header;
  value, expected: DStrings.String;
  ok: BOOLEAN;
BEGIN
  pass := TRUE;
  HttpHeader.Init(h);
  ok := HttpHeader.Set(h, "Content-Type", "text/plain");
  ok := HttpHeader.Get(h, "Content-Type", value);
  DStrings.Init("text/plain", expected);
  Tests.ExpectedBool(TRUE, ok, "Get after Set", pass);
  IF ok THEN
    Tests.ExpectedBool(DStrings.Equal(value, expected), TRUE, "Value matches", pass)
  END;
  RETURN pass
END TestSetGet;

PROCEDURE TestRemove*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  h: HttpHeader.Header;
  value: DStrings.String;
  ok: BOOLEAN;
BEGIN
  pass := TRUE;
  HttpHeader.Init(h);
  ok := HttpHeader.Set(h, "X-Test", "foo");
  ok := HttpHeader.Remove(h, "X-Test");
  Tests.ExpectedBool(TRUE, ok, "Remove returns TRUE", pass);
  ok := HttpHeader.Get(h, "X-Test", value);
  Tests.ExpectedBool(FALSE, ok, "Get after Remove returns FALSE", pass);
  RETURN pass
END TestRemove;

PROCEDURE AppendCRLF(VAR s: DStrings.String);
VAR r: DStrings.Rider;
BEGIN
  DStrings.Set(r, s, DStrings.Length(s));
  DStrings.WriteChar(r, Chars.CR);
  DStrings.WriteChar(r, Chars.LF)
END AppendCRLF;

PROCEDURE TestToString*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  h: HttpHeader.Header;
  out, expected: DStrings.String;
  ok: BOOLEAN;
  buf: ARRAY 256 OF CHAR;
  res: INTEGER;
  tmp: DStrings.String;
  r: DStrings.Rider;
  match: BOOLEAN;
BEGIN
  pass := TRUE;
  HttpHeader.Init(h);
  ok := HttpHeader.Set(h, "Content-Type", "text/plain");
  ok := HttpHeader.Set(h, "X-Test", "foo");
  ok := HttpHeader.ToString(h, out);
  (* The order of fields is not guaranteed, so check for both possible orderings, and expect uppercase keys *)
  DStrings.Init("CONTENT-TYPE: text/plain", expected); AppendCRLF(expected);
  DStrings.Init("X-TEST: foo", tmp); DStrings.Set(r, expected, DStrings.Length(expected)); DStrings.WriteDString(r, tmp); AppendCRLF(expected);
  match := DStrings.Equal(out, expected);
  IF ~match THEN
    DStrings.Init("X-TEST: foo", expected); AppendCRLF(expected);
    DStrings.Init("CONTENT-TYPE: text/plain", tmp); DStrings.Set(r, expected, DStrings.Length(expected)); DStrings.WriteDString(r, tmp); AppendCRLF(expected);
    match := DStrings.Equal(out, expected);
  END;
  IF ~match THEN
    DStrings.ToChars(out, buf, res);
    Out.String("Header: ["); Out.String(buf); Out.String("]"); Out.Ln;
    Tests.ExpectedBool(TRUE, FALSE, "ToString output does not match any expected order", pass)
  ELSE
    Tests.ExpectedBool(TRUE, TRUE, "ToString output matches expected order (uppercase)", pass)
  END;
  RETURN pass
END TestToString;

BEGIN
  Tests.Init(ts, "HTTP Header Tests");
  Tests.Add(ts, TestInit);
  Tests.Add(ts, TestSetGet);
  Tests.Add(ts, TestRemove);
  Tests.Add(ts, TestToString);
  ASSERT(Tests.Run(ts))
END HttpHeaderTest.
