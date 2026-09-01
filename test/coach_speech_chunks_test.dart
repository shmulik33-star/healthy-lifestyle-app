import 'package:flutter_test/flutter_test.dart';

import 'package:healthy_lifestyle_stage9/features/coach/coach_screen.dart';

void main() {
  test('a short reply is spoken as a single chunk', () {
    expect(splitReplyIntoSpeechChunks('כל הכבוד על היום!'), ['כל הכבוד על היום!']);
  });

  test('splits on sentence boundaries so each utterance stays short', () {
    final chunks = splitReplyIntoSpeechChunks('משפט ראשון. משפט שני! משפט שלישי?');
    expect(chunks, ['משפט ראשון.', 'משפט שני!', 'משפט שלישי?']);
  });

  test(
    'a reply over Chrome\'s speech-synthesis cutoff length is split into chunks '
    'that each stay at or under the limit, so the whole reply is actually heard '
    '-- this is the bug the chunking exists to work around',
    () {
      final longSentence = List.generate(60, (i) => 'מילה$i').join(' ');
      expect(longSentence.length, greaterThan(maxSpeechChunkLength));

      final chunks = splitReplyIntoSpeechChunks('$longSentence.');

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(maxSpeechChunkLength));
      }
      // No words dropped in the process of wrapping.
      expect(chunks.join(' ').replaceAll('.', ''), longSentence);
    },
  );

  test('empty text produces no chunks', () {
    expect(splitReplyIntoSpeechChunks(''), isEmpty);
  });
}
