// Stage widgets of the next format batch.
// Contract (see stage/extras.js PLUG): export NEU2 = { kind: { placement(extra, wall) → "side"|"left"|"below"|null,
//   tiles(extra, scene, view) → { tags: { [playerId]: { text, cls, hot } }, locked: [playerId] },
//   Widget({ x, pm, scene, view, revealed, full }) } }. `pm` maps player id → PlayerRef (avatar wire, name, balance).
export const NEU2 = {};
