// Pair-programmed by SE Community + Cortex Code
"use client";
import { useEffect, useRef, useState } from "react";
import {
  ArrowRight,
  Download,
  FileText,
  MapPin,
  RefreshCw,
  Utensils,
} from "lucide-react";
import { CHANNELS, DAYPARTS } from "../contracts/dataset";
import type { Exploration, Filters } from "../lib/analytics";
import type { ActionBrief } from "../lib/brief";
import RestaurantMap from "./restaurant-map";
import TrendChart from "./trend";

const number = (value: number | null, digits = 0) =>
  value === null
    ? "Not available"
    : value.toLocaleString("en-US", { maximumFractionDigits: digits });
const signed = (value: number | null, suffix = "") =>
  value === null
    ? "Not available"
    : `${value > 0 ? "+" : ""}${number(value, suffix ? 1 : 0)}${suffix}`;
const money = (value: number) =>
  new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0,
  }).format(value);

export default function Explorer() {
  const [filters, setFilters] = useState<Filters>({
    market: "Mesa Vale",
    weeks: 8,
    daypart: "All",
    channel: "All",
  });
  const [restaurant, setRestaurant] = useState("R001");
  const [result, setResult] = useState<Exploration | null>(null);
  const [tab, setTab] = useState("Breakdown");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [brief, setBrief] = useState<ActionBrief | null>(null);
  const [generating, setGenerating] = useState(false);
  const [briefError, setBriefError] = useState("");
  const [retry, setRetry] = useState(0);
  const generation = useRef(0);
  const query = new URLSearchParams({
    ...filters,
    weeks: String(filters.weeks),
    restaurant,
  }).toString();
  useEffect(() => {
    const controller = new AbortController();
    generation.current++;
    setLoading(true);
    setBrief(null);
    setGenerating(false);
    setBriefError("");
    setError("");
    fetch(`/api/explore?${query}`, { signal: controller.signal })
      .then(async (response) => {
        const body = await response.json();
        if (!response.ok) throw new Error(body.error);
        if (!controller.signal.aborted) setResult(body);
      })
      .catch((reason) => {
        if (reason.name !== "AbortError") setError(reason.message);
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });
    return () => controller.abort();
  }, [query, retry]);
  const invalidate = () => {
    generation.current++;
    setLoading(true);
    setBrief(null);
    setBriefError("");
  };
  const select = (id: string) => {
    if (id !== restaurant) {
      invalidate();
      setRestaurant(id);
    }
  };
  const filter = (key: keyof Filters, value: string | number) => {
    invalidate();
    setFilters((previous) => ({ ...previous, [key]: value }));
  };
  const generate = async () => {
    const requestGeneration = ++generation.current;
    setGenerating(true);
    setBriefError("");
    try {
      const response = await fetch(`/api/brief?${query}`, { method: "POST" });
      const body = await response.json();
      if (!response.ok) throw new Error(body.error);
      if (requestGeneration === generation.current) setBrief(body);
    } catch (reason) {
      if (requestGeneration === generation.current)
        setBriefError(
          reason instanceof Error
            ? reason.message
            : "Brief unavailable. Retry generation.",
        );
    } finally {
      if (requestGeneration === generation.current) setGenerating(false);
    }
  };
  const download = () => {
    if (!brief) return;
    const url = URL.createObjectURL(
      new Blob([brief.markdown], { type: "text/markdown;charset=utf-8" }),
    );
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `recovery-${result!.selected.restaurant.id}-${brief.snapshot}.md`;
    anchor.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  };
  return (
    <main>
      <header className="app-header">
        <div className="brand-mark">
          <Utensils size={22} />
        </div>
        <div>
          <p className="eyebrow">OPERATIONS INTELLIGENCE / DEMO</p>
          <h1>Restaurant Recovery Explorer</h1>
        </div>
        <span className="synthetic">Synthetic demonstration data</span>
      </header>
      <div className="intro">
        <div>
          <p className="eyebrow">FROM LOST VISITS TO A TESTABLE NEXT STEP</p>
          <h2>Find the pattern. Follow the evidence.</h2>
        </div>
        <span className="dataset-note">
          48 fictional restaurants
          <br />
          104 weeks / no customer data
        </span>
      </div>
      <form className="filters" onSubmit={(event) => event.preventDefault()}>
        <label>
          Market
          <select
            aria-label="Market"
            value={filters.market}
            onChange={(event) => filter("market", event.target.value)}
          >
            {["All", "Mesa Vale", "Juniper Coast", "Cedar Basin"].map(
              (value) => (
                <option key={value}>{value}</option>
              ),
            )}
          </select>
        </label>
        <label>
          Analysis window
          <select
            aria-label="Analysis window"
            value={filters.weeks}
            onChange={(event) => filter("weeks", Number(event.target.value))}
          >
            <option value="8">Latest 8 weeks</option>
            <option value="4">Latest 4 weeks</option>
          </select>
        </label>
        <label>
          Daypart
          <select
            aria-label="Daypart"
            value={filters.daypart}
            onChange={(event) => filter("daypart", event.target.value)}
          >
            {["All", ...DAYPARTS].map((value) => (
              <option key={value}>{value}</option>
            ))}
          </select>
        </label>
        <label>
          Channel
          <select
            aria-label="Channel"
            value={filters.channel}
            onChange={(event) => filter("channel", event.target.value)}
          >
            {["All", ...CHANNELS].map((value) => (
              <option key={value}>{value}</option>
            ))}
          </select>
        </label>
        <div className="comparison-label">
          COMPARISON<span>Aligned prior-year weeks</span>
        </div>
      </form>
      {error ? (
        <div role="alert" className="notice">
          {error}{" "}
          <button onClick={() => setRetry((previous) => previous + 1)}>
            <RefreshCw size={16} />
            Retry
          </button>
        </div>
      ) : loading || !result ? (
        <div role="status" className="loading">
          <RefreshCw size={20} />
          Calculating aligned visits and matching pre-period peers...
        </div>
      ) : (
        <>
          <div className="period-line">
            Weeks starting {result.market.start} through {result.market.end}{" "}
            <span>
              Baseline: {result.market.baselineStart} through{" "}
              {result.market.baselineEnd}
            </span>
          </div>
          <div className="period-line">
            <span>
              Comparable restaurants:{" "}
              {signed(
                result.market.bridge.find((row) => row.label === "Comparable")
                  ?.change ?? 0,
              )}{" "}
              guest occasions
            </span>
            <span>
              Fleet totals below include openings and closures; excluded pairs
              are not estimated.
            </span>
          </div>
          <section className="metrics" aria-label="Market metrics">
            <div>
              <p>NET GUEST CHANGE</p>
              <strong
                className={result.market.change < 0 ? "negative" : "positive"}
              >
                {signed(result.market.change)}
              </strong>
              <small>
                {signed(result.market.percent, "%")} vs aligned baseline
              </small>
            </div>
            <div>
              <p>GROSS RESTAURANT LOSSES</p>
              <strong>{number(result.market.grossLoss)}</strong>
              <small>Guest occasions at declining restaurants</small>
            </div>
            <div>
              <p>OFFSETTING GAINS</p>
              <strong className="positive">
                +{number(result.market.gains)}
              </strong>
              <small>Gains offset losses, not extra explanations</small>
            </div>
            <div>
              <p>PAIRED DATA COVERAGE</p>
              <strong>
                {number(
                  ((result.market.expected - result.market.excluded) /
                    Math.max(result.market.expected, 1)) *
                    100,
                  1,
                )}
                %
              </strong>
              <small>
                {number(result.market.excluded)} excluded cell pairs
              </small>
            </div>
          </section>
          <section className="workspace">
            <div className="network">
              <div className="section-title">
                <h3>
                  <MapPin size={17} />
                  {filters.market === "All"
                    ? "Restaurant network"
                    : filters.market}
                </h3>
                <span>Loss concentration</span>
              </div>
              <RestaurantMap
                key={filters.market}
                result={result}
                select={select}
              />
              <div className="section-title ranking-title">
                <h3>Where visits changed</h3>
                <span>Absolute guest change</span>
              </div>
              <div
                className="ranking"
                role="region"
                aria-label="Restaurant ranking"
              >
                <table>
                  <thead>
                    <tr>
                      <th>Restaurant</th>
                      <th>Change</th>
                      <th>Loss share</th>
                    </tr>
                  </thead>
                  <tbody>
                    {result.market.stores.map((store) => (
                      <tr
                        key={store.restaurant.id}
                        className={
                          store.restaurant.id === result.selected.restaurant.id
                            ? "selected-row"
                            : ""
                        }
                      >
                        <td>
                          <button
                            aria-pressed={
                              store.restaurant.id ===
                              result.selected.restaurant.id
                            }
                            onClick={() => select(store.restaurant.id)}
                          >
                            {store.restaurant.name}
                            <small>
                              {store.restaurant.id} /{" "}
                              {store.excluded ? "Incomplete" : store.lifecycle}
                            </small>
                          </button>
                        </td>
                        <td
                          className={store.change < 0 ? "negative" : "positive"}
                        >
                          {signed(store.change)}
                        </td>
                        <td>{number(store.lossShare, 1)}%</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <details className="bridge">
                <summary>Fleet reconciliation and exclusions</summary>
                {result.market.bridge.map((row) => (
                  <p key={row.label}>
                    {row.label} ({row.count})
                    <strong>{signed(row.change)}</strong>
                  </p>
                ))}
                <p>
                  Net paired change
                  <strong>{signed(result.market.change)}</strong>
                </p>
                <small>
                  Incomplete pairs are excluded, not imputed. Bridge subtotals
                  describe observed paired cells; they are not a complete fleet
                  estimate when coverage is below 100%.
                </small>
              </details>
            </div>
            <article className="restaurant-detail">
              <div className="detail-heading">
                <div>
                  <p className="eyebrow">
                    {result.selected.restaurant.id} /{" "}
                    {result.selected.restaurant.market}
                  </p>
                  <h2>{result.selected.restaurant.name}</h2>
                  <p>
                    {result.selected.lifecycle} /{" "}
                    {result.selected.restaurant.format}
                  </p>
                </div>
                <span className="quality">
                  {result.selected.excluded
                    ? "Incomplete observations"
                    : "Complete paired observations"}
                </span>
              </div>
              <nav className="tabs" aria-label="Restaurant views">
                {["Breakdown", "Comparisons", "Action Brief"].map((value) => (
                  <button
                    key={value}
                    aria-current={tab === value ? "page" : undefined}
                    onClick={() => setTab(value)}
                  >
                    {value}
                  </button>
                ))}
              </nav>
              <div className="detail-metrics">
                <div>
                  <span>Guest change</span>
                  <strong
                    className={
                      result.selected.change < 0 ? "negative" : "positive"
                    }
                  >
                    {signed(result.selected.change)}
                  </strong>
                </div>
                <div>
                  <span>Change rate</span>
                  <strong>{signed(result.selected.percent, "%")}</strong>
                </div>
                <div>
                  <span>Net sales change</span>
                  <strong>
                    {money(
                      result.selected.salesCurrent -
                        result.selected.salesBaseline,
                    )}
                  </strong>
                </div>
              </div>
              {tab === "Breakdown" && (
                <>
                  <TrendChart result={result} />
                  <div className="breakdowns">
                    {[
                      { title: "By daypart", rows: result.dayparts },
                      { title: "By channel", rows: result.channels },
                    ].map((group) => (
                      <section key={group.title}>
                        <h3>{group.title}</h3>
                        {group.rows.map((row) => (
                          <div className="contribution" key={row.label}>
                            <div>
                              <span>{row.label}</span>
                              <strong
                                className={
                                  row.change < 0 ? "negative" : "positive"
                                }
                              >
                                {signed(row.change)}
                              </strong>
                            </div>
                            <div className="bar-track">
                              <span
                                style={{
                                  width: `${Math.max(1, (Math.abs(row.change) / Math.max(...group.rows.map((item) => Math.abs(item.change)), 1)) * 100)}%`,
                                  background:
                                    row.change < 0 ? "#bd4d43" : "#238574",
                                }}
                              />
                            </div>
                          </div>
                        ))}
                      </section>
                    ))}
                  </div>
                  <p className="footnote">
                    Alternative breakdowns of the same change. Guest occasions
                    are visits, not unique people.
                  </p>
                  <details>
                    <summary>Daypart / channel cells</summary>
                    <div className="table-scroll">
                      <table>
                        <thead>
                          <tr>
                            <th>Daypart</th>
                            <th>Channel</th>
                            <th>Baseline</th>
                            <th>Current</th>
                            <th>Change</th>
                          </tr>
                        </thead>
                        <tbody>
                          {result.cells.map((row) => (
                            <tr key={`${row.daypart}-${row.channel}`}>
                              <td>{row.daypart}</td>
                              <td>{row.channel}</td>
                              <td>{number(row.baseline)}</td>
                              <td>{number(row.current)}</td>
                              <td>{signed(row.change)}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </details>
                  <div className="section-title">
                    <h3>Operational context</h3>
                    <span>Selected dayparts / all channels</span>
                  </div>
                  <div className="operations">
                    <p>
                      Open hours
                      <span>
                        {number(result.operations.baselineHours, 1)}{" "}
                        <ArrowRight size={13} />{" "}
                        {number(result.operations.currentHours, 1)}
                      </span>
                    </p>
                    <p>
                      Guest occasions / open hour
                      <span>
                        {number(result.operations.baselineRate, 1)}{" "}
                        <ArrowRight size={13} />{" "}
                        {number(result.operations.currentRate, 1)}
                      </span>
                    </p>
                  </div>
                  <p className="footnote">
                    Hours are counted once per restaurant, week, and daypart.
                    Association is not causation.
                  </p>
                  {result.events.map((event) => (
                    <p className="event" key={event.id}>
                      <span>{event.start}</span>
                      {event.type} / {event.daypart ?? "All dayparts"}
                      <small>{event.source}</small>
                    </p>
                  ))}
                </>
              )}
              {tab === "Comparisons" && (
                <>
                  <div className="section-title">
                    <h3>Matched before the analysis window</h3>
                    <span>{result.peers.policy}</span>
                  </div>
                  <p>
                    26 weeks: {result.peers.preStart} through{" "}
                    {result.peers.preEnd}. Format, volume, occasion mix, open
                    hours, and historical trend.
                  </p>
                  {!result.peers.adequate ? (
                    <div className="notice">
                      Insufficient comparable peers. At least three eligible
                      restaurants are required; no benchmark is reported.
                    </div>
                  ) : (
                    <>
                      <div className="peer-summary">
                        <strong>{signed(result.peers.gap, " pp")}</strong>
                        <span>
                          Restaurant change minus equal-weight peer change
                          <br />
                          {result.peers.outcomeComplete
                            ? `Peer change: ${signed(result.peers.peerPercent, "%")}`
                            : "Outcome coverage is incomplete; comparison withheld"}
                        </span>
                      </div>
                      <p className="footnote">
                        Descriptive comparison only. Not causal impact or
                        recoverable demand.
                      </p>
                      <TrendChart result={result} />
                      <div className="table-scroll">
                        <table>
                          <thead>
                            <tr>
                              <th>Matched restaurant</th>
                              <th>Market</th>
                              <th>Distance</th>
                              <th>Pre-period volume gap</th>
                            </tr>
                          </thead>
                          <tbody>
                            {result.peers.selected.map((peer) => (
                              <tr key={peer.restaurant.id}>
                                <td>{peer.restaurant.name}</td>
                                <td>{peer.restaurant.market}</td>
                                <td>{number(peer.score, 3)}</td>
                                <td>{number(peer.differences[0], 1)} / week</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </>
                  )}
                  <details>
                    <summary>
                      Matching rules, differences, and exclusions
                    </summary>
                    <p>
                      Lower distance is closer. Maximum 1.0; up to five peers.
                      Weights: volume 30%, breakfast 20%, delivery 15%, open
                      hours 20%, trend 15%. Denominators are pre-period
                      population standard deviations with documented floors.
                    </p>
                    {result.peers.candidates.map((peer) => (
                      <p key={peer.restaurant.id} className="candidate">
                        <strong>{peer.restaurant.name}</strong>
                        <span>
                          {peer.reason} / distance {number(peer.score, 3)}
                        </span>
                        {peer.differences.length > 0 && (
                          <small>
                            Absolute gaps: volume{" "}
                            {number(peer.differences[0], 1)}, breakfast{" "}
                            {number(peer.differences[1] * 100, 2)} pp, delivery{" "}
                            {number(peer.differences[2] * 100, 2)} pp, hours{" "}
                            {number(peer.differences[3], 1)}, trend{" "}
                            {number(peer.differences[4] * 100, 2)} pp.
                          </small>
                        )}
                      </p>
                    ))}
                  </details>
                </>
              )}
              {tab === "Action Brief" && (
                <section className="brief">
                  <div className="section-title">
                    <h3>From evidence to a proposed test</h3>
                    <span>Template-generated / no AI calls</span>
                  </div>
                  <div className="brief-actions">
                    <button
                      className="primary"
                      onClick={generate}
                      disabled={generating}
                    >
                      <FileText size={17} />
                      {generating
                        ? "Generating..."
                        : brief
                          ? "Regenerate brief"
                          : "Generate action brief"}
                    </button>
                    {brief && (
                      <button onClick={download}>
                        <Download size={17} />
                        Export Markdown
                      </button>
                    )}
                  </div>
                  {briefError && (
                    <p role="alert" className="notice">
                      {briefError}
                    </p>
                  )}
                  {brief && (
                    <div data-testid="brief-content">
                      <p className="brief-status">{brief.status}</p>
                      {brief.sections.map((section) => (
                        <section className="brief-section" key={section.title}>
                          <h3>{section.title}</h3>
                          {section.claims.map((claim, index) => (
                            <p key={index}>
                              {claim.text}
                              {claim.evidenceIds.map((id) => (
                                <a
                                  key={id}
                                  href={`#evidence-${id}`}
                                  className="citation"
                                  aria-label={`Evidence ${id}`}
                                >
                                  [{id.split("-").at(-1)}]
                                </a>
                              ))}
                            </p>
                          ))}
                        </section>
                      ))}
                      <h3>Evidence ledger</h3>
                      {brief.evidence.map((item) => (
                        <details
                          key={item.id}
                          id={`evidence-${item.id}`}
                          className="evidence"
                        >
                          <summary>
                            {item.label}: {number(item.value, 2)} {item.unit}
                          </summary>
                          <p>{item.formula}</p>
                          <p>
                            {item.periods} / {item.coverage}
                          </p>
                          <p>
                            Source: {item.source} / {item.population}
                          </p>
                          <small>
                            Snapshot {brief.snapshot} / analysis{" "}
                            {item.analysisVersion} / synthetic
                          </small>
                        </details>
                      ))}
                    </div>
                  )}
                </section>
              )}
            </article>
          </section>
          <footer>
            Pair-programmed by SE Community + Cortex Code
            <span>
              As of {result.metadata.asOf} / Synthetic data v
              {result.metadata.version} / No causal conclusions
            </span>
          </footer>
        </>
      )}
    </main>
  );
}
