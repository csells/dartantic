import 'dart:async';
import 'package:http/http.dart' as http;

/// An [http.Client] that wraps an inner client and exposes a single
/// [abort] method to cancel the currently in-flight request.
///
/// Designed for turn-based usage where at most one request is in flight
/// at a time. Each [send] creates a fresh abort trigger and a fresh
/// abortable request, so aborting one turn does not affect the next.
///
/// Supports all standard [http.BaseRequest] subtypes:
/// - [http.Request]                  → [http.AbortableRequest]
/// - [http.StreamedRequest]          → [http.AbortableStreamedRequest]
/// - [http.MultipartRequest]         → [http.AbortableMultipartRequest]
///
/// Any other request subtype throws [UnsupportedError]. This is
/// deliberate: silently dropping the abort trigger would produce a
/// request that looks abortable but isn't.
///
/// The abort trigger is only honored if the inner client supports
/// aborting requests. `IOClient` and `RetryClient` do; some clients
/// (e.g. `BrowserClient`) may not.
///
/// ## Combining abort with retry
///
/// To get both abort and retry, compose this client with
/// `package:http`'s `RetryClient`. **Abort must be the outer layer**
/// so that `RetryClient` never sees the abort as a failure it should
/// retry:
///
/// ```dart
/// import 'package:http/http.dart' as http;
/// import 'package:http/retry.dart';
///
/// final client = AbortHttpClient(
///   inner: RetryClient(
///     http.Client(),
///     retries: 3,
///     when: (response) => response.statusCode == 429,
///   ),
///   name: 'gemini',
/// );
///
/// // To abort the current turn:
/// client.abort();
///
/// // When done with the client entirely:
/// client.close();
/// ```
///
/// `RetryClient` explicitly recognizes `RequestAbortedException` and
/// will not retry an aborted request, so the outer abort layer is
/// sufficient to guarantee prompt cancellation.
///
/// ## Ownership of `inner`
///
/// - If `inner` is **omitted**, a default `http.Client()` is created
///   internally and this client owns it.
/// - If `inner` is **provided**, ownership depends on `transferInner`:
///   - When `transferInner` is `null` (default), the caller retains
///     ownership. This client will not close `inner`.
///   - When `transferInner` is `true`, ownership is transferred to
///     this client. `close` will close `inner`, and the caller must
///     not use it afterward.
class AbortHttpClient extends http.BaseClient {
  /// Creates a new [AbortHttpClient].
  ///
  /// [inner] is the client that performs the actual HTTP work. If
  /// omitted, a default `http.Client()` is created and owned by this
  /// instance.
  ///
  /// [transferInner] controls whether [close] will close [inner].
  /// - `null` (default): ownership is inferred. This client owns
  ///   [inner] only if it created it (i.e. `inner == null`). A
  ///   caller-provided [inner] is left untouched by [close].
  /// - `true`: ownership is transferred to this client, which will
  ///   close [inner] on [close]. The caller must not use [inner]
  ///   after calling [close].
  /// - `false`: this client will never close [inner], even if it
  ///   created it. Only meaningful when [inner] is omitted; useful
  ///   for cases where the default client should outlive this wrapper.
  ///
  /// [name] is used only for diagnostics.
  AbortHttpClient({required this.name, http.Client? inner, bool? transferInner})
    : _inner = inner ?? http.Client(),
      _ownsInner = transferInner ?? (inner == null);

  final http.Client _inner;
  final bool _ownsInner;

  /// A human-readable label for diagnostics.
  final String name;

  /// Completer for the currently in-flight request. Null between turns.
  Completer<void>? _abort;

  /// Latched abort flag. Set by [abort] when no request is in flight,
  /// consumed by the next [send].
  bool _abortRequested = false;

  /// Requests abort of the in-flight request, if any.
  ///
  /// Safe to call multiple times. If no request is in flight, the abort
  /// is latched and the next [send] fails immediately with
  /// [http.RequestAbortedException].
  void abort() {
    final completer = _abort;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
      return;
    }
    _abortRequested = true;
  }

  /// Whether an abort has been requested for the current or next turn.
  bool get isAborted => _abort?.isCompleted ?? _abortRequested;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_abortRequested) {
      _abortRequested = false;
      throw http.RequestAbortedException(request.url);
    }

    final abortCompleter = Completer<void>();
    _abort = abortCompleter;

    final abortable = _asAbortable(request, abortCompleter.future);

    try {
      return await _inner.send(abortable);
    } on http.RequestAbortedException {
      rethrow; // Normal abort path; propagate as-is.
    } finally {
      if (identical(_abort, abortCompleter)) {
        _abort = null;
      }
    }
  }

  /// Builds an abortable version of [request], preserving the body
  /// for standard, streamed, and multipart request types.
  ///
  /// Throws [UnsupportedError] if [request] is not one of the recognized
  /// [http.BaseRequest] subtypes.
  http.BaseRequest _asAbortable(
    http.BaseRequest request,
    Future<void> abortTrigger,
  ) {
    // 1. Standard Request (JSON body, etc.)
    if (request is http.Request) {
      return http.AbortableRequest(
          request.method,
          request.url,
          abortTrigger: abortTrigger,
        )
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes
        ..encoding = request.encoding;
    }

    // 2. StreamedRequest: pipe the original body stream into the
    //    AbortableStreamedRequest's sink to preserve the body.
    if (request is http.StreamedRequest) {
      final abortable = http.AbortableStreamedRequest(
        request.method,
        request.url,
        abortTrigger: abortTrigger,
      )..headers.addAll(request.headers);

      // Pipe the original body stream into the abortable request's sink.
      // Errors and completion propagate so the sink closes properly.
      // The subscription is intentionally not held: it stays alive on
      // its own for the duration of the body stream.
      request.finalize().listen(
        abortable.sink.add,
        onError: abortable.sink.addError,
        onDone: abortable.sink.close,
      );

      return abortable;
    }

    // 3. MultipartRequest: copy fields and files directly. Unlike a
    //    StreamedRequest, the body parts are already materialized on the
    //    original request and can be reattached to the abortable wrapper.
    if (request is http.MultipartRequest) {
      return http.AbortableMultipartRequest(
          request.method,
          request.url,
          abortTrigger: abortTrigger,
        )
        ..headers.addAll(request.headers)
        ..fields.addAll(request.fields)
        ..files.addAll(request.files);
    }

    // 4. Unrecognized subtype: fail loudly rather than silently dropping
    //    the abort trigger. Callers can extend this client if they need
    //    to support a custom request type.
    throw UnsupportedError(
      'AbortHttpClient cannot make ${request.runtimeType} abortable. '
      'Supported types: Request, StreamedRequest, MultipartRequest.',
    );
  }

  @override
  void close() {
    // Abort any in-flight request, then close the inner client only if
    // we own it. If the caller retained ownership, they handle its
    // lifecycle separately.
    abort();
    if (_ownsInner) {
      _inner.close();
    }
    super.close();
  }
}
