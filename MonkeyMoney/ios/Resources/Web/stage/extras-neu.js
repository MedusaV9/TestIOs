// Stage widgets of the new formats: speed (Affenzahn), survival (Der letzte Affe), schaukel (Affenschaukel), herde (Herdentrieb), memory (Kokos-Kopf).
// Contract (see stage/extras.js PLUG): export NEU = { kind: { placement(extra, wall) → "side"|"left"|"below"|null,
//   tiles(extra, scene, view) → { tags: { [playerId]: { text, cls, hot } }, locked: [playerId] },
//   Widget({ x, pm, scene, view, revealed, full }) } }. `pm` maps player id → PlayerRef (avatar wire, name, balance).
export const NEU = {};
