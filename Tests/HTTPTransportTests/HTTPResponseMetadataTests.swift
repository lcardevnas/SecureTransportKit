import Foundation
import HTTPTransport
import Testing

struct HTTPResponseMetadataTests {
    @Test func parsesRetryAfterDeltaSeconds() {
        #expect(HTTPResponse(data: Data(), statusCode: 429, headers: ["retry-after": "12"]).retryAfter == 12)
        #expect(HTTPResponse(data: Data(), statusCode: 429, headers: ["Retry-After": "-1"]).retryAfter == nil)
        #expect(HTTPResponse(data: Data(), statusCode: 429, headers: ["Retry-After": "1.5"]).retryAfter == nil)
    }

    @Test func acceptsStandardHistoricalHTTPDateForms() {
        for value in [
            "Sun, 06 Nov 1994 08:49:37 GMT",
            "Sunday, 06-Nov-94 08:49:37 GMT",
            "Sun Nov  6 08:49:37 1994",
        ] {
            #expect(HTTPResponse(data: Data(), statusCode: 503, headers: ["Retry-After": value]).retryAfter != nil)
        }
    }

    @Test func parsesRetryAfterHTTPDates() throws {
        let future = Date(timeIntervalSinceNow: 120)
        for format in [
            "EEE',' dd MMM yyyy HH':'mm':'ss z",
            "EEEE',' dd-MMM-yy HH':'mm':'ss z",
            "EEE MMM d HH':'mm':'ss yyyy",
        ] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            let response = HTTPResponse(
                data: Data(),
                statusCode: 503,
                headers: ["Retry-After": formatter.string(from: future)]
            )
            let interval = try #require(response.retryAfter)
            #expect(interval > 115 && interval <= 120)
        }
    }

    @Test func malformedAndMissingRetryAfterAreNil() {
        #expect(HTTPResponse(data: Data(), statusCode: 200).retryAfter == nil)
        #expect(HTTPResponse(data: Data(), statusCode: 200, headers: ["Retry-After": "later"]).retryAfter == nil)
    }

    @Test func findsRequestIdentifierCaseInsensitively() {
        let response = HTTPResponse(
            data: Data(),
            statusCode: 200,
            headers: ["x-CoRrElAtIoN-iD": "correlation-123"]
        )
        #expect(response.requestID == "correlation-123")
        #expect(HTTPResponse(data: Data(), statusCode: 200).requestID == nil)
    }

    @Test func transportErrorDescriptionsRedactAssociatedValues() {
        let secret = "secret-marker"
        let response = HTTPResponse(data: Data(secret.utf8), statusCode: 401, headers: ["X-Secret": secret])
        let errors: [HTTPTransportError] = [
            .encoding(secret),
            .decoding(secret),
            .transport(secret),
            .unsuccessful(response),
        ]

        for error in errors {
            #expect(!String(describing: error).contains(secret))
        }
    }
}
