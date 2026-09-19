// 경로 지도의 도보 연결선을 뽑는 규칙을 본다.
//
// 그리는 쪽과 보행 경로를 조회하는 쪽이 이 한 함수를 같이 쓴다. 여기서 순서나
// 끝점이 틀리면 받아 온 보행 경로가 엉뚱한 연결선에 그려진다.
import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/api/transit_route_options_service.dart';
import 'package:map_service_client/core/maps/map_types.dart';
import 'package:map_service_client/features/trip/screens/transit_route_map_screen.dart';

TransitRouteLeg _leg(TransitLegType type, List<List<double>> geometry) =>
    TransitRouteLeg(
      type: type,
      startName: 'a',
      endName: 'b',
      sectionTimeMinutes: 5,
      geometry: geometry,
      stopNames: const [],
    );

const _origin = MapCoordinate(37.5700, 126.9800);
const _destination = MapCoordinate(37.5200, 126.9200);

void main() {
  test('출발지 → 구간들 → 도착지를 순서대로 잇고, 좌표 없는 도보 구간은 건너뛴다', () {
    final legs = [
      _leg(TransitLegType.walk, const []),
      _leg(TransitLegType.subway, const [
        [37.5665, 126.9780],
        [37.5500, 126.9500],
      ]),
      _leg(TransitLegType.walk, const []),
      _leg(TransitLegType.bus, const [
        [37.5490, 126.9490],
        [37.5228, 126.9227],
      ]),
      _leg(TransitLegType.walk, const []),
    ];

    final connectors = transitConnectors(_origin, _destination, legs);

    expect(connectors.map((c) => c.id), ['connector_1', 'connector_3', 'connector_end']);
    // 출발지 → 지하철 시작
    expect(connectors[0].from.latitude, 37.5700);
    expect(connectors[0].to.latitude, 37.5665);
    // 지하철 끝 → 버스 시작(환승 걷기)
    expect(connectors[1].from.latitude, 37.5500);
    expect(connectors[1].to.latitude, 37.5490);
    // 버스 끝 → 도착지
    expect(connectors[2].from.latitude, 37.5228);
    expect(connectors[2].to.latitude, 37.5200);
  });

  test('좌표 있는 구간이 없으면 출발지 → 도착지 하나만 남는다', () {
    final connectors = transitConnectors(
      _origin,
      _destination,
      [_leg(TransitLegType.walk, const [])],
    );

    expect(connectors, hasLength(1));
    expect(connectors.single.id, 'connector_end');
    expect(connectors.single.from.latitude, 37.5700);
    expect(connectors.single.to.latitude, 37.5200);
  });
}
