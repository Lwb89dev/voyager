import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voyager/plugins/podcast/podcast_repository.dart';
import 'package:voyager/utils/bounded_client.dart';

const _sampleFeed = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel>
  <title>Sample Show</title>
  <item>
    <title>Episode 1</title>
    <guid>ep-1</guid>
    <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
  </item>
</channel></rss>
''';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('voyager_podcast_test');
    Hive.init(hiveDir.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() => Hive.box('settings').clear());

  test('reads a normal feed through the bounded fetch path', () async {
    final repo = PodcastRepository(
      httpClient: BoundedClient(
        client: MockClient((_) async => http.Response(_sampleFeed, 200)),
      ),
    );

    final subscription = await repo.describe('https://example.com/feed.xml');
    expect(subscription.title, 'Sample Show');
  });

  test('refuses a feed response past the size cap instead of buffering it',
      () async {
    // podcast_search's own Feed.loadFeed has no cap of its own — this is the
    // regression test for routing feed fetches through BoundedClient first.
    final repo = PodcastRepository(
      httpClient: BoundedClient(
        client: MockClient((_) async => http.Response(
              'x' * (21 * 1024 * 1024),
              200,
            )),
      ),
    );

    expect(
      () => repo.describe('https://example.com/huge-feed.xml'),
      throwsA(isA<ResponseTooLarge>()),
    );
  });
}
