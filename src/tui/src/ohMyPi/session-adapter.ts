export type EditMode = "hashline" | "replace" | "auto";

export interface OhMyPiSession {
  cwd: string;
  hasEditTool: boolean;
  editMode: EditMode;
}

function parseEditMode(raw: string | undefined): EditMode {
  if (raw === "hashline" || raw === "replace" || raw === "auto") return raw;
  return "hashline";
}

export function createOhMyPiSession(cwd: string): OhMyPiSession {
  const editMode = parseEditMode(process.env.EDIT_MODE);
  return {
    cwd,
    hasEditTool: editMode === "hashline" || editMode === "auto",
    editMode,
  };
}
