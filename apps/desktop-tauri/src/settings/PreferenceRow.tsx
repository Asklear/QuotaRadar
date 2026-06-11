import type { ReactNode } from "react";

interface PreferenceRowProps {
  label: string;
  description: string;
  control: ReactNode;
}

export function PreferenceRow({ label, description, control }: PreferenceRowProps) {
  return (
    <div className="preference-row">
      <div>
        <div className="preference-label">{label}</div>
        <p>{description}</p>
      </div>
      <div className="preference-control">{control}</div>
    </div>
  );
}
