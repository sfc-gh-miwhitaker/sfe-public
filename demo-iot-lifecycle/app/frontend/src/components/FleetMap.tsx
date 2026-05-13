import { useMemo } from 'react';
import DeckGL from '@deck.gl/react';
import { ScatterplotLayer, BitmapLayer } from '@deck.gl/layers';
import { TileLayer } from '@deck.gl/geo-layers';
import type { Position, Customer } from '../App';

const INITIAL_VIEW = {
  longitude: -84.38,
  latitude: 33.82,
  zoom: 10.5,
  pitch: 0,
  bearing: 0,
};

const DEPOT = { longitude: -84.3880, latitude: 33.7490 };

interface Props {
  positions: Position[];
  customers: Customer[];
}

function getVehicleColor(p: Position): [number, number, number, number] {
  if (p.speed_mph > 0) return [0, 220, 100, 240];
  if (p.engine_status === 'IDLE') return [255, 200, 0, 240];
  return [200, 60, 60, 240];
}

export default function FleetMap({ positions, customers }: Props) {
  const vehicleData = useMemo(
    () => positions.map(p => ({ ...p, color: getVehicleColor(p) })),
    [positions]
  );

  const layers = useMemo(() => [
    new TileLayer({
      id: 'base-map',
      data: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      minZoom: 0,
      maxZoom: 19,
      tileSize: 256,
      renderSubLayers: (props: any) => {
        const { boundingBox } = props.tile;
        return new BitmapLayer(props, {
          data: undefined,
          image: props.data,
          bounds: [boundingBox[0][0], boundingBox[0][1], boundingBox[1][0], boundingBox[1][1]],
        });
      },
    }),
    new ScatterplotLayer({
      id: 'customers',
      data: customers,
      getPosition: (d: Customer) => [d.longitude, d.latitude],
      getFillColor: [65, 105, 225, 140],
      getRadius: 150,
      radiusMinPixels: 4,
      pickable: true,
    }),
    new ScatterplotLayer({
      id: 'depot',
      data: [DEPOT],
      getPosition: (d: typeof DEPOT) => [d.longitude, d.latitude],
      getFillColor: [220, 20, 60, 220],
      getRadius: 350,
      radiusMinPixels: 8,
      stroked: true,
      getLineColor: [255, 255, 255, 180],
      lineWidthMinPixels: 2,
    }),
    new ScatterplotLayer({
      id: 'vehicles',
      data: vehicleData,
      getPosition: (d: Position & { color: number[] }) => [d.longitude, d.latitude],
      getFillColor: (d: Position & { color: number[] }) => d.color as any,
      getRadius: 250,
      radiusMinPixels: 8,
      pickable: true,
      transitions: {
        getPosition: 1000,
      },
    }),
  ], [vehicleData, customers]);

  return (
    <DeckGL
      initialViewState={INITIAL_VIEW}
      controller={true}
      layers={layers}
      getTooltip={({ object }: any) => {
        if (!object) return null;
        if ('customer_name' in object) {
          return { text: `${object.customer_name}\n${object.industry}` };
        }
        if ('vehicle_id' in object) {
          return { text: `${object.vehicle_id}\n${object.speed_mph} mph • ${object.engine_status}\n${object.timestamp}` };
        }
        return null;
      }}
    />
  );
}
