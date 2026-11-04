## What went wrong with a request, in words a person can act on, for every
## HTTPRequest.Result: a link a session gave came back "Could not fetch …
## (error 4)", and the LDraw files a carried part is drawn from "the network
## failed (4)" (urlfetch, 2026-11-03).
class_name FetchWords
extends RefCounted


## Why a request to [param host] that ended in [param result] fetched
## nothing: a phrase, "example.com did not answer within 90 s", never a
## code. [param seconds] is the request's time limit, said when it ran out.
static func of(result: int, host: String, seconds: float = 0.0) -> String:
	match result:
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "%s sent less of the file than it said it would; try again" % host
		HTTPRequest.RESULT_CANT_CONNECT:
			return "%s would not take a connection: the site may be down, or this computer offline" % host
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "there is no site called %s, or this computer is offline: check the link" % host
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "the connection to %s broke off before the file came%s; try again" % [host,
				" (or the site does not let a browser fetch its files)" if OS.has_feature("web") else ""]
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "%s's certificate could not be trusted, so nothing was fetched from it" % host
		HTTPRequest.RESULT_NO_RESPONSE:
			return "%s sent no answer" % host
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "the file from %s is larger than can be brought in" % host
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "%s sent the file packed in a way that could not be unpacked" % host
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "the request to %s could not be sent" % host
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "the file from %s could not be saved: its place on this computer would not open" % host
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "the file from %s could not be saved: writing it failed, and the disk may be full" % host
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "%s sent the request on from address to address too many times without reaching the file" % host
		HTTPRequest.RESULT_TIMEOUT:
			return ("%s did not answer within %d s" % [host, roundi(seconds)]) if seconds > 0.0 \
				else "%s took too long to answer" % host
	return "the request to %s failed, and this app does not know why" % host
