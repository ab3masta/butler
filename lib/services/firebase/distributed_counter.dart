import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

const SHARD_COLLECTION_ID = '_counter_shards_';

class DistributedCounter {
  /// Constructs a sharded counter object that references to a field
  /// in a document that is a counter.
  ///
  /// @param doc A reference to a document with a counter field.
  /// @param field A path to a counter field in the above document.
  DistributedCounter(
    this.doc,
    this.field,
  ) {
    this.shardId = Uuid().v4();
    final shardsRef = doc.collection(SHARD_COLLECTION_ID);
    shards[doc.path] = 0;
    shards[shardsRef.doc(shardId).path] = 0;
    shards[shardsRef.doc('\t' + shardId.substring(0, 4)).path] = 0;
    shards[shardsRef.doc('\t\t' + shardId.substring(0, 3)).path] = 0;
    shards[shardsRef.doc('\t\t\t' + shardId.substring(0, 2)).path] = 0;
    shards[shardsRef.doc('\t\t\t\t' + shardId.substring(0, 1)).path] = 0;
  }

  late final String shardId;

  final DocumentReference<Object?> doc;
  final String field;
  late Map<String, int> shards = {};
  late Stream<int> _snapshots;

  /// Get latency compensated view of the counter.
  ///
  /// All local increments will be reflected in the counter even if the main
  /// counter hasn't been updated yet.
  Future<int> get(
      {GetOptions options = const GetOptions(source: Source.server)}) async {
    final valuePromises = shards.keys.map((path) async {
      final shard = await doc.firestore.doc(path).get(options);
      final shardData = shard.data();
      if (shardData != null && shardData.containsKey(field)) {
        return shard.get(field) ?? 0;
      } else {
        return 0;
      }
    });
    final values = await Future.wait(valuePromises);
    return values.reduce((a, b) => a + b);
  }

  /// Listen to latency compensated view of the counter.
  ///
  /// All local increments to this counter will be immediately visible in the
  /// snapshot.
  Stream<int> onSnapshot() {
    return StreamGroup.mergeBroadcast<int>(shards.keys.map((path) =>
        doc.firestore.doc(path).snapshots().map<int>((DocumentSnapshot snap) {
          shards[snap.reference.path] = snap.exists ? snap.get(field) : 0;
          return shards.values.reduce((a, b) => a + b);
        })));
  }

  /// Increment the counter by a given value.
  ///
  /// e.g.
  /// final counter = DistributedCounter(db.doc('path/document'), 'counter');
  /// counter.incrementBy(1);
  Future<void> incrementBy(int val) {
    final increment = FieldValue.increment(val);
    final toFold = this.field.split('.').reversed;
    Map<String, dynamic> update = toFold
        .skip(1)
        .fold({toFold.elementAt(0): increment}, (value, name) => {name: value});
    return doc
        .collection(SHARD_COLLECTION_ID)
        .doc(shardId)
        .set(update, SetOptions(merge: true));
  }
}
