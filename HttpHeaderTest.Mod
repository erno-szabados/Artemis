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

BEGIN
  Tests.Init(ts, "HTTP Header Tests");
  Tests.Add(ts, TestInit);
  ASSERT(Tests.Run(ts))
END HttpHeaderTest.
