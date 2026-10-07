import 'headless_browser.dart';

enum ResolveFailure { notFound, timeout, loadFailed, network, unknown }

/// The outcome of resolving a play page: an ordered list of playable
/// candidates (best first) or a classified failure.
class ResolveResult {
  final List<MediaCandidate> candidates;
  final ResolveFailure? failure;

  const ResolveResult.success(this.candidates) : failure = null;
  const ResolveResult.failed(ResolveFailure this.failure) : candidates = const [];

  MediaCandidate? get candidate => candidates.isEmpty ? null : candidates.first;
  bool get ok => candidates.isNotEmpty;
}
