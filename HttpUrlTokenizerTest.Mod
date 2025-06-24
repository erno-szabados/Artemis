MODULE HttpUrlTokenizerTest;

IMPORT HttpUrlTokenizer, Tests;

VAR 
    ts : Tests.TestSet;

PROCEDURE TestBasicScheme*(): BOOLEAN;
VAR
    pass: BOOLEAN;
    tokenizer: HttpUrlTokenizer.Tokenizer;
    token: HttpUrlTokenizer.Token;
BEGIN
    pass := TRUE;
    
    HttpUrlTokenizer.Init(tokenizer, "http:");
    
    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.SchemeToken, token.type, "Scheme token type", pass);
    Tests.ExpectedString("http", token.value, "Scheme token value", pass);
    
    RETURN pass
END TestBasicScheme;

PROCEDURE TestSlashSlash*(): BOOLEAN;
VAR
    pass: BOOLEAN;
    tokenizer: HttpUrlTokenizer.Tokenizer;
    token: HttpUrlTokenizer.Token;
BEGIN
    pass := TRUE;
    
    HttpUrlTokenizer.Init(tokenizer, "//example.com");
    
    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.SlashSlashToken, token.type, "SlashSlash token type", pass);
    Tests.ExpectedString("//", token.value, "SlashSlash token value", pass);
    
    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.HostToken, token.type, "Host token type", pass);
    Tests.ExpectedString("example.com", token.value, "Host token value", pass);
    
    RETURN pass
END TestSlashSlash;

PROCEDURE TestSimpleHost*(): BOOLEAN;
VAR
    pass: BOOLEAN;
    tokenizer: HttpUrlTokenizer.Tokenizer;
    token: HttpUrlTokenizer.Token;
BEGIN
    pass := TRUE;
    
    HttpUrlTokenizer.Init(tokenizer, "example.com");
    
    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.HostToken, token.type, "Simple host token type", pass);
    Tests.ExpectedString("example.com", token.value, "Simple host token value", pass);
    
    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.EofToken, token.type, "EOF after host", pass);
    
    RETURN pass
END TestSimpleHost;

PROCEDURE TestPathOnly*(): BOOLEAN;
VAR
    pass: BOOLEAN;
    tokenizer: HttpUrlTokenizer.Tokenizer;
    token: HttpUrlTokenizer.Token;
BEGIN
    pass := TRUE;
    
    HttpUrlTokenizer.Init(tokenizer, "/path/to/file");
    
    HttpUrlTokenizer.NextToken(tokenizer, token);
    Tests.ExpectedInt(HttpUrlTokenizer.PathToken, token.type, "Path only token type", pass);
    Tests.ExpectedString("/path/to/file", token.value, "Path only token value", pass);
    
    RETURN pass
END TestPathOnly;

PROCEDURE TestUtilityFunctions*(): BOOLEAN;
VAR
    pass: BOOLEAN;
    tokenizer: HttpUrlTokenizer.Tokenizer;
BEGIN
    pass := TRUE;
    
    HttpUrlTokenizer.Init(tokenizer, "http://example.com");
    
    Tests.ExpectedBool(FALSE, HttpUrlTokenizer.AtEof(tokenizer), "Not at EOF initially", pass);
    Tests.ExpectedInt(0, HttpUrlTokenizer.GetPos(tokenizer), "Initial position", pass);
    Tests.ExpectedInt(HttpUrlTokenizer.NoError, HttpUrlTokenizer.GetError(tokenizer), "No error initially", pass);
    
    RETURN pass
END TestUtilityFunctions;

BEGIN
  Tests.Init(ts, "HTTP URL Tokenizer Tests");
  Tests.Add(ts, TestBasicScheme);
  Tests.Add(ts, TestSlashSlash);
  Tests.Add(ts, TestSimpleHost);
  Tests.Add(ts, TestPathOnly);
  Tests.Add(ts, TestUtilityFunctions);
  ASSERT(Tests.Run(ts))
END HttpUrlTokenizerTest.