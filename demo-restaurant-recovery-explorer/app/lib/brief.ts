// Pair-programmed by SE Community + Cortex Code
import type { Exploration } from "./analytics";
import { ANALYSIS_VERSION } from "./analytics";

export type Evidence = {
  id: string;
  label: string;
  value: number | null;
  unit: string;
  formula: string;
  periods: string;
  coverage: string;
  source: string;
  population: string;
  analysisVersion: string;
};
export type Claim = { text: string; evidenceIds: string[] };
export type ActionBrief = {
  snapshot: string;
  status: string;
  sections: { title: string; claims: Claim[] }[];
  evidence: Evidence[];
  markdown: string;
};
const format = (value: number, digits = 0) =>
  value.toLocaleString("en-US", { maximumFractionDigits: digits });

export function buildBrief(result: Exploration): ActionBrief {
  const evidence: Evidence[] = [];
  const store = result.selected;
  if (!store.pairs)
    throw new Error(
      "No paired observations. Restore missing extracts before generating a brief.",
    );
  const add = (
    label: string,
    value: number | null,
    unit: string,
    formula: string,
    source = "Performance",
    coverage = `${store.pairs}/${store.expected} complete paired cells`,
    population = store.restaurant.id,
  ) => {
    const id = `${result.snapshot}-E${evidence.length + 1}`;
    evidence.push({
      id,
      label,
      value,
      unit,
      formula,
      source,
      coverage,
      population,
      periods: `${result.market.start} to ${result.market.end}; baseline ${result.market.baselineStart} to ${result.market.baselineEnd}`,
      analysisVersion: ANALYSIS_VERSION,
    });
    return id;
  };
  const changeId = add(
    "Guest change",
    store.change,
    "guest occasions",
    `${store.current} current - ${store.baseline} baseline; only complete aligned pairs`,
  );
  const percentId = add(
    "Guest change rate",
    store.percent,
    "%",
    "(current guests - baseline guests) / baseline guests * 100; undefined for zero baseline",
  );
  const peerId = add(
    "Descriptive peer gap",
    result.peers.gap,
    "percentage points",
    "Restaurant change rate minus equal-weight mean of matched restaurants' change rates",
    `Performance + ${result.peers.policy}`,
    result.peers.outcomeComplete
      ? "Complete outcomes and eligible pre-period cohort"
      : "Unavailable: match or outcome coverage insufficient",
    result.peers.selected.map((row) => row.restaurant.id).join(", ") ||
      "No adequate cohort",
  );
  const coverageId = add(
    "Excluded pairs",
    store.excluded,
    "cell pairs",
    "Expected aligned cells minus complete aligned cells",
  );
  const lowest = [...result.dayparts].sort(
    (left, right) => left.change - right.change,
  )[0];
  const daypartId = add(
    `${lowest.label} guest change`,
    lowest.change,
    "guest occasions",
    `${lowest.current} current - ${lowest.baseline} baseline`,
    "Performance",
    `${lowest.pairs}/${lowest.expected} paired cells`,
    `${store.restaurant.id} / ${lowest.label}`,
  );
  const hoursId = add(
    "Open-hours change",
    result.operations.currentHours !== null &&
      result.operations.baselineHours !== null
      ? result.operations.currentHours - result.operations.baselineHours
      : null,
    "hours",
    "Current open hours - baseline open hours; operational grain, all channels",
    "Operations",
    result.operations.complete
      ? "Complete selected daypart operations"
      : "Incomplete operations",
  );
  const rateId = add(
    "Guest occasions per open-hour change",
    result.operations.currentRate !== null &&
      result.operations.baselineRate !== null
      ? result.operations.currentRate - result.operations.baselineRate
      : null,
    "guest occasions/hour",
    "Current all-channel guests/current hours - baseline all-channel guests/baseline hours",
    "Performance + Operations",
    result.operations.currentRate !== null
      ? "All-channel paired guests and operations complete"
      : "Unavailable due to coverage or zero hours",
  );
  const peerCountId = add(
    "Eligible selected peers",
    result.peers.selected.length,
    "restaurants",
    "Up to five pre-period matches; at least three required",
    result.peers.policy,
    `26 pre-period weeks, ${result.peers.preStart} to ${result.peers.preEnd}`,
  );
  const laborId = add(
    "Labor-hours change",
    result.operations.currentLabor !== null &&
      result.operations.baselineLabor !== null
      ? result.operations.currentLabor - result.operations.baselineLabor
      : null,
    "hours",
    "Current labor hours - baseline labor hours; operational grain",
    "Operations",
    result.operations.complete
      ? "Complete selected daypart operations"
      : "Incomplete operations",
  );
  const staffingEvent = result.events.find(
    (row) =>
      row.type === "Staffing change" &&
      row.daypart === lowest.label &&
      row.start < result.market.start,
  );
  const eventId = staffingEvent
    ? add(
        "Staffing event before window",
        1,
        "record",
        `Recorded ${staffingEvent.start}; predates window start ${result.market.start}. Does not establish decline onset or causality.`,
        staffingEvent.source,
        "One dated synthetic event",
      )
    : null;
  const insufficient =
    store.excluded > 0 ||
    !result.peers.adequate ||
    !result.peers.outcomeComplete ||
    !result.operations.complete;
  const lifecycle = store.lifecycle !== "Comparable";
  const breakfast = result.breakfastOperations;
  const breakfastId = add(
    "Breakfast labor-hours change",
    breakfast.currentLabor !== null && breakfast.baselineLabor !== null
      ? breakfast.currentLabor - breakfast.baselineLabor
      : null,
    "hours",
    "Breakfast current labor hours - breakfast baseline labor hours",
    "Operations",
    breakfast.complete
      ? "Complete breakfast operations"
      : "Incomplete breakfast operations",
    `${store.restaurant.id} / Breakfast`,
  );
  const breakfastHoursId = add(
    "Breakfast open-hours change",
    breakfast.currentHours !== null && breakfast.baselineHours !== null
      ? breakfast.currentHours - breakfast.baselineHours
      : null,
    "hours",
    "Breakfast current open hours - breakfast baseline open hours",
    "Operations",
    breakfast.complete
      ? "Complete breakfast operations"
      : "Incomplete breakfast operations",
    `${store.restaurant.id} / Breakfast`,
  );
  const breakfastRateId = add(
    "Breakfast guest/open-hour change",
    breakfast.currentRate !== null && breakfast.baselineRate !== null
      ? breakfast.currentRate - breakfast.baselineRate
      : null,
    "guest occasions/hour",
    "All-channel breakfast current guest/open-hour rate - baseline rate",
    "Performance + Operations",
    breakfast.currentRate !== null
      ? "Complete breakfast paired guests and hours"
      : "Unavailable",
    `${store.restaurant.id} / Breakfast`,
  );
  const staffingCandidate =
    !insufficient &&
    !lifecycle &&
    lowest.label === "Breakfast" &&
    breakfast.complete &&
    result.filters.channel === "All" &&
    !!staffingEvent &&
    lowest.change < 0 &&
    result.peers.gap !== null &&
    result.peers.gap < -3 &&
    breakfast.currentHours === breakfast.baselineHours &&
    breakfast.currentLabor! < breakfast.baselineLabor! &&
    breakfast.currentRate !== null &&
    breakfast.baselineRate !== null &&
    breakfast.currentRate < breakfast.baselineRate;
  const sharedPattern =
    !insufficient &&
    !lifecycle &&
    store.change < 0 &&
    result.peers.peerPercent !== null &&
    result.peers.peerPercent < -3 &&
    Math.abs(result.peers.gap!) < 3;
  let status = "Investigate before selecting an intervention";
  let hypothesis =
    "The available patterns do not distinguish a specific operational explanation.";
  let action =
    "Validate period coverage and collect the missing operational evidence before choosing an intervention.";
  let counter =
    "Similar measured characteristics cannot rule out unmeasured differences in demand, pricing, promotions, or execution.";
  let links = [changeId, peerId];
  if (lifecycle) {
    status = "Lifecycle change: separate availability from demand";
    hypothesis =
      "Opening or closure changes alter the comparison population. A restaurant recovery conclusion is not warranted from this fleet contribution.";
    action =
      "Verify the lifecycle dates and availability bridge. Do not apply a traffic-recovery treatment to an opening or closed restaurant.";
    links = [changeId, hoursId];
  } else if (insufficient) {
    status = "Insufficient evidence: investigate before acting";
    hypothesis =
      "Incomplete paired observations, unsuitable peers, or missing operational inputs prevent a supported comparative explanation.";
    links = [coverageId, peerId, peerCountId];
  } else if (store.change >= 0) {
    status = "No observed net guest loss in this selection";
    hypothesis =
      "The selected period and occasions do not show an aggregate decline. Avoid inventing a recovery problem.";
    action =
      "Monitor the measured gains and inspect any declining subsegments separately. Do not prescribe a recovery intervention from a positive total.";
    links = [changeId];
  } else if (staffingCandidate) {
    status = "Candidate test: breakfast service coverage";
    hypothesis =
      "Reduced breakfast staffing is a candidate to investigate: the dated record precedes this window, breakfast guests fell, and selected traffic weakened more than matched peers while breakfast open hours were unchanged. This is not proof of cause or precise onset.";
    action =
      "Review shift-level service and staffing records. If confirmed operationally, propose a limited breakfast service-coverage pilot with manager approval.";
    counter =
      "Breakfast open hours did not fall, so reduced breakfast trading availability alone does not explain this pattern. Matching is observational; the event timestamp alone does not prove staffing caused the decline.";
    links = [
      daypartId,
      peerId,
      hoursId,
      rateId,
      laborId,
      breakfastId,
      breakfastHoursId,
      breakfastRateId,
      eventId!,
    ];
  } else if (sharedPattern) {
    status = "Shared decline: investigate broader demand";
    hypothesis =
      "The restaurant and matched peers weakened by similar amounts. A restaurant-specific staffing explanation is not distinguished by this comparison.";
    action =
      "Validate local demand, calendar, pricing, and promotional changes. If a demand intervention is justified, design a separate market-level test rather than assuming a store execution fix.";
    counter =
      "Peers share a decline, which contradicts a uniquely restaurant-specific explanation. It does not establish a market-wide external cause.";
    links = [changeId, peerId];
  } else if (
    result.operations.currentHours! < result.operations.baselineHours!
  ) {
    status = "Availability changed: investigate open hours";
    hypothesis =
      "Reduced open hours coincide with lower guest activity. Inspect guest occasions per open hour before treating all missing visits as weaker demand.";
    action =
      "Confirm the hours change and staffing feasibility. Consider a bounded hours-restoration test only after reviewing costs and operational constraints.";
    links = [changeId, hoursId, rateId];
  }
  const sections: ActionBrief["sections"] = [
    {
      title: "Observation",
      claims: [
        {
          text: `Observed paired guest change is ${format(store.change)} guest occasions${store.percent === null ? "; a change rate is undefined because baseline guests are zero" : ` (${format(store.percent, 1)}%)`}.`,
          evidenceIds: [changeId, percentId],
        },
        {
          text: `${lowest.label} contributes ${format(lowest.change)} guest occasions to that change.`,
          evidenceIds: [daypartId],
        },
      ],
    },
    {
      title: "Hypothesis, not a causal finding",
      claims: [{ text: hypothesis, evidenceIds: links }],
    },
    {
      title: "Counterevidence and limitations",
      claims: [
        {
          text: counter,
          evidenceIds: [peerId, staffingCandidate ? breakfastHoursId : hoursId],
        },
        {
          text: "Guest occasions are visits, not identified guests. This dataset cannot separate acquisition, retention, or guest migration.",
          evidenceIds: [],
        },
      ],
    },
    {
      title: "Recommended next step",
      claims: [{ text: action, evidenceIds: links }],
    },
    {
      title: "Missing evidence",
      claims: [
        {
          text: "Transaction-level timing, shift-level service observations, promotion exposure, contribution margin, and intervention costs remain unassessed. Synthetic history is not evidence about an actual business.",
          evidenceIds: [],
        },
      ],
    },
    {
      title: "Proposed evaluation, not measured results",
      claims: [
        {
          text:
            lifecycle || insufficient || store.change >= 0
              ? "Do not activate an experiment from this brief. Resolve eligibility and evidence gaps first; the following is a prospective design checklist only."
              : "Eligible units: active comparable restaurants with complete periods and the operational condition independently confirmed. Final eligibility requires a feasibility review.",
          evidenceIds: [coverageId, peerCountId],
        },
        {
          text: "Assignment: randomize eligible restaurants or clusters where feasible, with a holdout and a prespecified analysis. Analytical peers are not automatically experimental controls.",
          evidenceIds: [],
        },
        {
          text: "Windows: freeze a complete pre-intervention baseline and a non-overlapping post-launch measurement period before assignment. Choose duration and sample size from variability and a power assessment; neither is established here.",
          evidenceIds: [],
        },
        {
          text: "Primary outcome: incremental guest occasions against the prespecified holdout estimate. Operational guardrails: service time, staffing safety, complaint rates, and overtime. Contribution-margin guardrail is pending cost and margin inputs.",
          evidenceIds: [],
        },
        {
          text: "Contamination risks: nearby restaurant substitution, overlapping offers, calendar shifts, and cross-store staffing. Stop for safety issues, unusable data, or predefined operational breaches. No lift, ROI, or statistical significance is claimed.",
          evidenceIds: [],
        },
      ],
    },
  ];
  const ids = new Set(evidence.map((item) => item.id));
  if (
    sections.some((section) =>
      section.claims.some((claim) =>
        claim.evidenceIds.some((id) => !ids.has(id)),
      ),
    )
  )
    throw new Error(
      "Evidence validation failed. Recompute the analysis before generating a brief.",
    );
  const markdown = [
    `# ${store.restaurant.name}: action brief`,
    "",
    "Pair-programmed by SE Community + Cortex Code",
    "",
    "**Synthetic demonstration data. Template-generated, not AI-generated. No customer findings.**",
    "",
    `Snapshot: ${result.snapshot} | Dataset: ${result.revision} | Analysis: ${ANALYSIS_VERSION} | As of: ${result.metadata.asOf}`,
    `Filters: ${JSON.stringify(result.filters)}`,
    "",
    `**${status}**`,
    "",
    ...sections.flatMap((section) => [
      `## ${section.title}`,
      "",
      ...section.claims.map(
        (claim) =>
          `${claim.text}${claim.evidenceIds.map((id) => ` [${id}](#${id})`).join("")}`,
      ),
      "",
    ]),
    "## Evidence appendix",
    "",
    ...evidence.flatMap((item) => [
      `### ${item.id}`,
      `${item.label}: ${item.value === null ? "Not available" : item.value} ${item.unit}`,
      `Formula: ${item.formula}`,
      `Periods: ${item.periods}`,
      `Coverage: ${item.coverage}`,
      `Source: ${item.source}; population: ${item.population}; synthetic; analysis ${item.analysisVersion}`,
      "",
    ]),
  ].join("\n");
  return { snapshot: result.snapshot, status, sections, evidence, markdown };
}
