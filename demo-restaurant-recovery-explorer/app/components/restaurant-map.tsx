// Pair-programmed by SE Community + Cortex Code
"use client";
import { useState } from "react";
import {
  Minus,
  Plus,
  RotateCcw,
  ArrowLeft,
  ArrowRight,
  ArrowUp,
  ArrowDown,
} from "lucide-react";
import type { Exploration } from "../lib/analytics";

export default function RestaurantMap({
  result,
  select,
}: {
  result: Exploration;
  select: (id: string) => void;
}) {
  const [view, setView] = useState({ zoom: 1, horizontal: 0, vertical: 0 });
  const stores = result.market.stores;
  const latitudes = stores.map((row) => row.restaurant.latitude),
    longitudes = stores.map((row) => row.restaurant.longitude);
  const minLatitude = Math.min(...latitudes),
    maxLatitude = Math.max(...latitudes);
  const minLongitude = Math.min(...longitudes),
    maxLongitude = Math.max(...longitudes);
  const peers = new Set(result.peers.selected.map((row) => row.restaurant.id));
  const buttons = [
    {
      label: "Zoom in",
      Icon: Plus,
      click: () =>
        setView((previous) => ({
          ...previous,
          zoom: Math.min(2.5, previous.zoom + 0.25),
        })),
    },
    {
      label: "Zoom out",
      Icon: Minus,
      click: () =>
        setView((previous) => ({
          ...previous,
          zoom: Math.max(0.75, previous.zoom - 0.25),
        })),
    },
    {
      label: "Pan left",
      Icon: ArrowLeft,
      click: () =>
        setView((previous) => ({
          ...previous,
          horizontal: previous.horizontal - 30,
        })),
    },
    {
      label: "Pan right",
      Icon: ArrowRight,
      click: () =>
        setView((previous) => ({
          ...previous,
          horizontal: previous.horizontal + 30,
        })),
    },
    {
      label: "Pan up",
      Icon: ArrowUp,
      click: () =>
        setView((previous) => ({
          ...previous,
          vertical: previous.vertical - 25,
        })),
    },
    {
      label: "Pan down",
      Icon: ArrowDown,
      click: () =>
        setView((previous) => ({
          ...previous,
          vertical: previous.vertical + 25,
        })),
    },
    {
      label: "Reset map",
      Icon: RotateCcw,
      click: () => setView({ zoom: 1, horizontal: 0, vertical: 0 }),
    },
  ];
  return (
    <div className="map-shell">
      <div className="map-heading">
        <span>FICTIONAL GEOGRAPHY</span>
        <span>{stores.length} restaurants</span>
      </div>
      <svg
        viewBox="0 0 620 400"
        className="restaurant-map"
        aria-label="Fictional restaurant network map"
      >
        <defs>
          <pattern
            id="grid"
            width="32"
            height="32"
            patternUnits="userSpaceOnUse"
          >
            <path
              d="M32 0H0V32"
              fill="none"
              stroke="#d9e4e8"
              strokeWidth="0.8"
            />
          </pattern>
        </defs>
        <rect width="620" height="400" fill="#edf3f4" />
        <rect width="620" height="400" fill="url(#grid)" />
        <g
          transform={`translate(${310 + view.horizontal},${200 + view.vertical}) scale(${view.zoom}) translate(-310,-200)`}
        >
          <path
            d="M-20 290Q160 165 220 245T640 98"
            stroke="#c4e6ee"
            strokeWidth="37"
            fill="none"
          />
          <path
            d="M20 90L600 320M95 0L410 420M0 170L620 170M370 0L370 400"
            stroke="#fff"
            strokeWidth="9"
            fill="none"
          />
          <path
            d="M20 90L600 320M95 0L410 420M0 170L620 170M370 0L370 400"
            stroke="#d0dce0"
            strokeWidth="1"
            fill="none"
          />
          {stores.map((store) => {
            const restaurant = store.restaurant;
            const horizontal =
              65 +
              ((restaurant.longitude - minLongitude) /
                Math.max(maxLongitude - minLongitude, 0.1)) *
                490;
            const vertical =
              345 -
              ((restaurant.latitude - minLatitude) /
                Math.max(maxLatitude - minLatitude, 0.1)) *
                285;
            const selected = restaurant.id === result.selected.restaurant.id;
            return (
              <g
                key={restaurant.id}
                role="button"
                tabIndex={0}
                aria-label={`Select ${restaurant.name}`}
                aria-pressed={selected}
                onClick={() => select(restaurant.id)}
                onKeyDown={(event) => {
                  if (event.key === "Enter" || event.key === " ") {
                    event.preventDefault();
                    select(restaurant.id);
                  }
                }}
                className="map-point"
                transform={`translate(${horizontal},${vertical})`}
              >
                <title>
                  {restaurant.name}: {store.change.toLocaleString()} guest
                  occasions; {store.lifecycle}
                </title>
                {selected && <circle r="22" fill="#29b5e8" opacity="0.22" />}
                {peers.has(restaurant.id) && (
                  <rect
                    x="-17"
                    y="-17"
                    width="34"
                    height="34"
                    rx="5"
                    fill="none"
                    stroke="#197cac"
                    strokeWidth="2"
                    strokeDasharray="4 2"
                  />
                )}
                <circle
                  r={selected ? 13 : 10}
                  fill={
                    store.excluded
                      ? "#64748b"
                      : store.change < 0
                        ? "#bd4d43"
                        : "#238574"
                  }
                  stroke={selected ? "#12698d" : "white"}
                  strokeWidth="3"
                />
                <text
                  y="4"
                  textAnchor="middle"
                  fill="white"
                  fontSize="9"
                  fontWeight="700"
                >
                  {restaurant.id.slice(-2)}
                </text>
              </g>
            );
          })}
        </g>
      </svg>
      <div className="map-tools">
        {buttons.map(({ label, Icon, click }) => (
          <button key={label} aria-label={label} title={label} onClick={click}>
            <Icon size={16} />
          </button>
        ))}
      </div>
      <div className="map-legend">
        <span>
          <i className="decline-dot" />
          Decline
        </span>
        <span>
          <i className="gain-dot" />
          Gain
        </span>
        <span>
          <i className="missing-dot" />
          Incomplete
        </span>
        <span className="peer-legend">Matched peer</span>
      </div>
    </div>
  );
}
