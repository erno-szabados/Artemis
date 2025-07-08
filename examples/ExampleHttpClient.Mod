(** ExampleHttpClient.Mod - Minimal example for HttpClient.Mod

Copyright (C) 2025 Artemis Project Contributors

Released under The 3-Clause BSD License.
*)
MODULE ExampleHttpClient;
IMPORT HttpClient, HttpResponse, HttpHeader, DStrings, Log, artSleep;

CONST
  WaitMs = 100;

VAR
  client: HttpClient.HttpClient;
  logger: Log.Logger;
  h : HttpHeader.Header;
  body: DStrings.String;
  resp: HttpResponse.HttpResponse;
  done, ok: BOOLEAN;
  buf : ARRAY 1024 OF CHAR;
  truncated : INTEGER;

BEGIN
  logger := Log.New(Log.DEBUG, Log.CONSOLE, "");
  Log.Info(logger, "Starting ExampleHttpClient");

  DStrings.Init("", body);

  HttpHeader.Init(h);
  ok := HttpHeader.Set(h, "User-Agent", "artemis/1.0");
  ok := HttpHeader.Set(h, "X-Test", "foo");

  HttpClient.Init(client);
  HttpClient.StartRequest(client, "GET", "http://localhost:5000/", h, body);

  done := FALSE;
  WHILE ~done DO
    IF HttpClient.Step(client) THEN
      artSleep.Millis(WaitMs)
    ELSE
      done := TRUE
    END
  END;

  IF HttpClient.GetResponse(client, resp) THEN
    Log.Info(logger, "Request complete, response received.");
    (* Optionally print status, headers, body *)
    DStrings.ToChars(resp.body, buf, truncated);
    Log.Debug(logger, buf);
  ELSE
    Log.Error(logger, "Request failed or no response.")
  END;

  Log.Close(logger)
END ExampleHttpClient.