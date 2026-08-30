#!/usr/bin/env bash
set -euo pipefail

factory="ios/App/Insights"
models="ios/App/Models.swift"
views="ios/App/Insights"

expected_ids=(
  natal-interpretation emotional-needs love-connection career-direction strengths-growth element-balance house-emphasis chart-signature planet-placements key-aspects
  sky-overview moon-now aspect-pattern planetary-motion sign-changes element-climate upcoming-7-days
  current-story current-cycles transit-timeline planet-paths life-areas active-transits
  developmental-chapter progressed-moon identity-development turning-points areas-maturing timeline
  year-theme year-anchors priority-areas year-dynamics year-timeline natal-overlay year-aspects
  relationship-overview perspectives emotional-connection communication chemistry commitment house-overlays key-inter-aspects
)

for id in "${expected_ids[@]}"; do
  if ! rg -q "\"$id\"" "$factory"; then
    echo "Missing iOS insight card: $id" >&2
    exit 1
  fi
done

required_manifests=(
  '.natal: ["natal-interpretation", "emotional-needs", "love-connection", "career-direction", "strengths-growth", "element-balance", "house-emphasis", "chart-signature", "planet-placements", "key-aspects"]'
  '.currentSky: ["sky-overview", "moon-now", "aspect-pattern", "planetary-motion", "sign-changes", "element-climate", "upcoming-7-days"]'
  '.transit: ["current-story", "current-cycles", "transit-timeline", "planet-paths", "life-areas", "active-transits"]'
  '.secondary: ["developmental-chapter", "progressed-moon", "identity-development", "turning-points", "areas-maturing", "timeline"]'
  '.solarReturn: ["year-theme", "year-anchors", "priority-areas", "year-dynamics", "year-timeline", "natal-overlay", "year-aspects"]'
  '.synastry: ["relationship-overview", "perspectives", "emotional-connection", "communication", "chemistry", "commitment", "house-overlays", "key-inter-aspects"]'
)

for manifest in "${required_manifests[@]}"; do
  if ! rg -Fq "$manifest" "$factory"; then
    echo "Missing or reordered iOS card manifest: $manifest" >&2
    exit 1
  fi
done

required_visuals=(
  natalCore rankedThemes strengthOrbit blindSpot growthPath
  skyOverview themeCards eventTimeline structureMap domainBars observation evolution planetTable
  activityGauge transitOverview gantt balanceRing houseRadar actionGuidance arcTimeline doubleRing calendar
  progressedStage progressedThemes turningTimeline comparison
  signatureTrio placementList aspectList storyWeave cycleTabs positionRows areaRows phaseDial motionList elementRows
  stageFlow moonProgress identityCompare turningRows yearOrbit anchorGrid dualInsight quarterTabs overlayCompare
  bondOrbit perspectiveTabs synastryConnectionGrid synastryPathFlow synastryHouseOverlayRows synastryInterAspectRows
)

for visual in "${required_visuals[@]}"; do
  if ! rg -q "case (let )?\\.$visual|case $visual" "$views" "$models"; then
    echo "Missing iOS insight visual: $visual" >&2
    exit 1
  fi
done

for removed in core-structure strongest-themes core-strengths blind-spot growth-direction daily-activity current-stage change-themes stage-advice natal-link; do
  if rg -q "id: \"$removed\"" "$factory"; then
    echo "Obsolete card still present: $removed" >&2
    exit 1
  fi
done

rg -q 'let calculatedValue: String' "$models"
rg -q 'let interpretationKey: String?' "$models"
rg -q 'let sourceFactIDs: \[String\]' "$models"
rg -q 'let conclusionKey: String?' "$models"

if rg -q 'paddedFacts|No close signal|Nothing close enough to display' "$factory"; then
  echo "Placeholder or padded facts remain in the iOS card builder." >&2
  exit 1
fi

if rg -qi 'composite' "$factory" "$models" ios/ContentSchema/card-contracts.json; then
  echo "Composite must remain outside the v6 chart/card contract." >&2
  exit 1
fi

for phrase in \
  "当前适合观察公共讨论与制度调整" \
  "个人感受仍需结合本命盘判断" \
  "行星位置与运行状态提供当前天象的基础事实" \
  "不同公共领域承载着密度不同的当前天象信号" \
  "不能预测具体社会事件" \
  "被反复触发的本命点与宫位形成当前核心主题"
do
  if rg -q "$phrase" ios/App --glob '*.swift'; then
    echo "Internal editorial wording leaked into consumer Swift: $phrase" >&2
    exit 1
  fi
done

echo "iOS card contract check passed."
