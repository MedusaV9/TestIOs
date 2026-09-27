// Shared stage context (commands to the room, host state, toasts).
export const StageCtx = { cmd: () => {}, host: null, refreshHost: async () => null, toast: () => {}, openDrawer: () => {}, ask: (text, yes) => yes() };
