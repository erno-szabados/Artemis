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

BEGIN
  Tests.Init(ts, "HTTP Header Tests");
  Tests.Add(ts, TestInit);
  Tests.Add(ts, TestSetGet);
  Tests.Add(ts, TestRemove);
  ASSERT(Tests.Run(ts))
END HttpHeaderTest.
