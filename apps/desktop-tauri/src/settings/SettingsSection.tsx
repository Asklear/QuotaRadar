import type { ReactNode } from "react";

interface SettingsSectionProps {
  title: string;
  children: ReactNode;
}

export function SettingsSection({ title, children }: SettingsSectionProps) {
  return (
    <section className="settings-section">
      <header>
        <h2>{title}</h2>
      </header>
      <div className="settings-section-body">{children}</div>
    </section>
  );
}
