# Data Model: HTTP Transport

## HTTPRequest<Response>

- Ordered path components, method, query items, headers, optional authorization, body, timeout.
- Accepted status policy and phantom expected response type.
- Each component is one semantic path segment.

## HTTPResponse

- Raw body bytes.
- Integer status code.
- Case-insensitive header lookup over normalized string pairs.

## AcceptedHTTPStatus

The inclusive 200...299 range plus a set of consumer-provided values.

## HTTPTransportError

Offline, cancelled, timed out, invalid response, invalid URL, encoding, decoding, unsuccessful
response, or other transport failure. Only the unsuccessful case retains a complete response.
