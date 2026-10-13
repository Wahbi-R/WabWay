import 'package:flutter_test/flutter_test.dart';
import 'package:wabway/data/spot_data.dart';

void main() {
  test('legacy statuses fold into the one lifecycle (no data migration)', () {
    expect(SpotStatus.wantToGo.stage, SpotStage.idea);
    expect(SpotStatus.mustDo.stage, SpotStage.idea);
    expect(SpotStatus.idea.stage, SpotStage.idea);
    expect(SpotStatus.confirmed.stage, SpotStage.confirmed);
    expect(SpotStatus.booked.stage, SpotStage.planned);
    expect(SpotStatus.planned.stage, SpotStage.planned);
    expect(SpotStatus.visited.stage, SpotStage.visited);
    expect(SpotStatus.skipped.stage, SpotStage.skipped);
  });
}
