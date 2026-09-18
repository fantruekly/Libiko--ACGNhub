import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/metadata/metadata_provider.dart';
import '../../core/metadata/metadata_service.dart';
import '../../core/models/work.dart';

final metadataServiceProvider =
    Provider<MetadataService>((ref) => MetadataService());

final animeFeedProvider =
    FutureProvider.family<List<Work>, AnimeFeed>((ref, feed) {
  return ref.watch(metadataServiceProvider).feed(feed);
});
