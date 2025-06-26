MODULE HttpHeaderTest;

IMPORT HttpHeader, Tests, DStrings;

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

PROCEDURE TestToString*(): BOOLEAN;
VAR
  pass: BOOLEAN;
  h: HttpHeader.Header;
  out, expected: DStrings.String;
  ok: BOOLEAN;
BEGIN
  pass := TRUE;
  HttpHeader.Init(h);
  ok := HttpHeader.Set(h, "Content-Type", "text/plain");
  ok := HttpHeader.Set(h, "X-Test", "foo");
  ok := HttpHeader.ToString(h, out);
  (* The order of fields is not guaranteed, so check for both possible orderings *)
  DStrings.Init("Content-Type: text/plain\r\nX-Test: foo\r\n", expected);
  IF DStrings.Equal(out, expected) THEN
    Tests.ExpectedBool(TRUE, TRUE, "ToString output matches (order 1)", pass)
  ELSE
    DStrings.Init("X-Test: foo\r\nContent-Type: text/plain\r\n", expected);
    Tests.ExpectedBool(DStrings.Equal(out, expected), TRUE, "ToString output matches (order 2)", pass)
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
