# Data Model: HTTP File Transfer

## FileUploadRequest

- `url`: Absolute destination URL.
- `method`: Caller-selected HTTP method.
- `headers`: Caller-owned headers; bearer authorization is applied explicitly afterward.
- `authorization`: Optional generic bearer value.
- `body`: Raw file or multipart form.
- `acceptedStatus`: Status policy checked before successful completion.
- `timeout`: Optional request timeout.

Validation: URL must be usable by `URLRequest`; every source URL must identify a readable regular file. Header names/values are passed through without application policy.

## FileUploadBody

- `file(url, contentType)`: Existing regular file uploaded directly.
- `multipart(form)`: Ordered parts written to one task-owned temporary file before network execution.

## MultipartFormData

- `boundary`: Explicit testable value or generated random value.
- `parts`: Ordered `text`, `data`, and `file` values.

Validation: Boundary, part names, filenames, and content types contain no CR or LF. File parts are readable regular files. Text and small data are copied incrementally into the temporary multipart file; file bytes are copied with bounded buffers.

## FileDownloadRequest

- `url`: Absolute source URL.
- `headers`: Caller-owned headers.
- `authorization`: Optional generic bearer value.
- `destinationURL`: Caller-selected final file URL.
- `acceptedStatus`: Status policy checked before publication.
- `timeout`: Optional request timeout.

Validation: The destination parent must exist and be a writable directory. The existing destination, if any, is never touched before accepted content is completely staged.

## HTTPTransferProgress

- `completedByteCount`: Nonnegative count that never decreases across emitted events.
- `totalByteCount`: Nonnegative expected total or `nil` when unavailable.

## HTTPTransferResult

- `response`: Status, headers, and at most 65,536 bytes. Accepted downloads always carry empty response data.
- `fileURL`: `nil` for uploads; exactly `destinationURL` for accepted downloads.

## Transfer Lifecycle

```text
created -> preparing -> running -> completed
                  \-> failed
                  \-> cancelled
```

Only the first transition into `completed`, `failed`, or `cancelled` wins. That transition cleans up owned temporary files once, ends the stream once, and makes later cancellation a no-op.
