@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' show LatLng;
import 'package:web/web.dart' as web;
import 'package:runline/shared/widgets/runline_map_view.dart';

@JS('eval')
external JSAny? evaluate(String source);
int count(String expression) => (evaluate(expression) as JSNumber).toDartInt;

void main() {
  testWidgets(
    'JS bridge updates marker, colored paths, camera and releases SDK listeners',
    (tester) async {
      // SDK fixture only. No real key, API route or location provider is used.
      evaluate(r'''
      globalThis.__runlineMapFixture = {lines: [], centers: 0, bounds: 0, levels: 0, markers: [], listeners: {}};
      const f = globalThis.__runlineMapFixture;
      globalThis.kakao = {maps: {
        load: cb => cb(),
        LatLng: function(lat,lng) {this.lat=lat;this.lng=lng;},
        LatLngBounds: function() {this.extend = p => {};},
        Map: function(el, opts) {f.map=this;this.relayout=()=>{};
          this.getCenter=()=>opts.center;this.setCenter=p=>{f.centers++;f.center=p;};
          this.setBounds=b=>{f.bounds++;};this.setLevel=l=>{f.levels++;};},
        Polyline: function(opts) {this.opts=opts;f.lines.push(this);
          this.setMap=m=>{this.map=m;};this.setPath=p=>{this.path=p;};this.setOptions=o=>{this.opts=o;};},
        CustomOverlay: function(opts) {this.opts=opts;this.position=opts.position;f.markers.push(this);
          this.setMap=m=>{this.map=m;};this.setPosition=p=>{this.position=p;};},
        event: {addListener: (map,event,cb)=>{f.listeners[event]=cb;},
          removeListener: (map,event,cb)=>{delete f.listeners[event];}}
      }};
    ''');
      var gestures = 0;
      const route = [LatLng(37.5, 127.1), LatLng(37.501, 127.1)];
      Widget view({LatLng? position, bool follow = true, int recenter = 0}) =>
          MaterialApp(
            home: SizedBox(
              width: 400,
              height: 300,
              child: RunlineMapView(
                routeCoordinates: route,
                remainingRouteSegments: const [route],
                trackSegments: const [route],
                completedRouteSegments: const [route],
                routeRun: true,
                currentPosition: position,
                followLocation: follow,
                recenterToken: recenter,
                onUserGesture: () => gestures++,
              ),
            ),
          );
      await tester.pumpWidget(view(position: route.first));
      final script = web.document.querySelector(
        'script[src*="dapi.kakao.com"]',
      );
      expect(script, isNotNull);
      script!.dispatchEvent(web.Event('load'));
      for (
        var i = 0;
        i < 20 && count('globalThis.__runlineMapFixture.markers.length') == 0;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(count('globalThis.__runlineMapFixture.markers.length'), 1);
      expect(
        count('globalThis.__runlineMapFixture.lines.filter(l=>l.map).length'),
        3,
      );
      expect(
        (evaluate(
          'globalThis.__runlineMapFixture.lines.map(l=>l.opts.strokeColor).join(",")',
        ) as JSString).toDart,
        '#9c27b0,#3d5afe,#16854a',
      );
      final centers = count('globalThis.__runlineMapFixture.centers');
      await tester.pumpWidget(view(position: route.last));
      await tester.pump();
      expect(count('globalThis.__runlineMapFixture.centers'), centers + 1);
      expect(
        (evaluate(
          'globalThis.__runlineMapFixture.markers[0].position.lat',
        ) as JSNumber).toDartDouble,
        37.501,
      );
      evaluate('globalThis.__runlineMapFixture.listeners.dragstart()');
      expect(gestures, 1);
      await tester.pumpWidget(view(position: route.first, follow: false));
      await tester.pump();
      expect(count('globalThis.__runlineMapFixture.centers'), centers + 1);
      await tester.pumpWidget(view(position: route.last, recenter: 1));
      await tester.pump();
      expect(count('globalThis.__runlineMapFixture.centers'), centers + 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(
        count('Object.keys(globalThis.__runlineMapFixture.listeners).length'),
        0,
      );
      expect(
        count('globalThis.__runlineMapFixture.lines.filter(l=>l.map).length'),
        0,
      );
    },
  );
}
