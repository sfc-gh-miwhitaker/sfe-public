import { useMemo } from 'react';
import DeckGL from '@deck.gl/react';
import { TripsLayer, ScatterplotLayer } from '@deck.gl/geo-layers';
import { Map } from 'react-map-gl/maplibre';
import type { Trip, Customer } from '../App';

const INITIAL_VIEW = {
  longitude: -84.38,
  latitude: 33.82,
  zoom: 10.5,
  pitch: 45,
  bearing: -10,
};

const DEPOT = { longitude: -84.3880, latitude: 33.7490 };
const MAP_STYLE = 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';

interface Props {
  trips: Trip[];
  customers: Customer[];
  currentTime: number;
  minTime: number;
}

export default function FleetMap({ trips, customers, currentTime, minTime }: Props) {
  const trailLength = 600;

  const layers = useMemo(() => [
    new TripsLayer({
      id: 'trips',
      data: trips,
      getPath: (d: Trip) => d.waypoints.map(w => w.coordinates),
      getTimestamps: (d: Trip) => d.waypoints.map(w => w.timestamp - minTime),
      getColor: (d: Trip) => d.color,
      currentTime: currentTime - minTime,
      trailLength,
      fadeTrail: true,
      capRounded: true,
      jointRounded: true,
      widthMinPixels: 6,
      opacity: 0.9,
    }),
    new ScatterplotLayer({
      id: 'customers',
      data: customers,
      getPosition: (d: Customer) => [d.longitude, d.latitude],
      getFillColor: [65, 105, 225, 180],
      getRadius: 120,
      radiusMinPixels: 4,
      pickable: true,
    }),
    new ScatterplotLayer({
      id: 'depot',
      data: [DEPOT],
      getPosition: (d: typeof DEPOT) => [d.longitude, d.latitude],
      getFillColor: [220, 20, 60, 240],
      getRadius: 300,
      radiusMinPixels: 8,
      stroked: true,
      getLineColor: [255, 255, 255, 200],
      lineWidthMinPixels: 2,
    }),
  ], [trips, customers, currentTime, minTime, trailLength]);

  return (
    <DeckGL
      initialViewState={INITIAL_VIEW}
      controller={true}
      layers={layers}
      getTooltip={({ object }: { object?: Customer }) =>
        object && 'customer_name' in object
          ? { text: `${object.customer_name}\n${object.industry}` }
          : null
      }
    >
      <Map mapStyle={MAP_STYLE} />
    </DeckGL>
  );
}
