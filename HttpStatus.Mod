(** HttpStatus.Mod - Common HTTP status code constants

Copyright (C) 2025 Artemis Project Contributors

Released under The 3-Clause BSD License.
*)

MODULE HttpStatus;

CONST
  StatusContinue* = 100;
  StatusSwitchingProtocols* = 101;
  StatusOK* = 200;
  StatusCreated* = 201;
  StatusAccepted* = 202;
  StatusNoContent* = 204;
  StatusMovedPermanently* = 301;
  StatusFound* = 302;
  StatusSeeOther* = 303;
  StatusNotModified* = 304;
  StatusBadRequest* = 400;
  StatusUnauthorized* = 401;
  StatusForbidden* = 403;
  StatusNotFound* = 404;
  StatusMethodNotAllowed* = 405;
  StatusRequestTimeout* = 408;
  StatusConflict* = 409;
  StatusGone* = 410;
  StatusLengthRequired* = 411;
  StatusPreconditionFailed* = 412;
  StatusPayloadTooLarge* = 413;
  StatusURITooLong* = 414;
  StatusUnsupportedMediaType* = 415;
  StatusExpectationFailed* = 417;
  StatusInternalServerError* = 500;
  StatusNotImplemented* = 501;
  StatusBadGateway* = 502;
  StatusServiceUnavailable* = 503;
  StatusGatewayTimeout* = 504;
  StatusHTTPVersionNotSupported* = 505;
END HttpStatus.
