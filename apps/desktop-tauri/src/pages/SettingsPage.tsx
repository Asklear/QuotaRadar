import { useState } from "react";
import { ProviderOrderDialog } from "../settings/ProviderOrderDialog";
import { PreferenceRow } from "../settings/PreferenceRow";
import { SettingsSection } from "../settings/SettingsSection";

function MockSwitch({ enabled, onChange, label }: { enabled: boolean; onChange: () => void; label: string }) {
  return (
    <button
      className="settings-switch"
      role="switch"
      aria-checked={enabled}
      aria-label={label}
      data-enabled={enabled}
      onClick={onChange}
    >
      <span aria-hidden="true" />
    </button>
  );
}

export function SettingsPage() {
  const [providerOrderOpen, setProviderOrderOpen] = useState(false);
  const [launchAtLogin, setLaunchAtLogin] = useState(true);
  const [updateCheck, setUpdateCheck] = useState(true);
  const [autoRefresh, setAutoRefresh] = useState(false);
  const [costlyRefresh, setCostlyRefresh] = useState(false);
  const [transparency, setTransparency] = useState(82);

  return (
    <div className="settings-page">
      <SettingsSection title="General">
        <PreferenceRow
          label="Language"
          description="Select the interface language used by the desktop shell."
          control={
            <select defaultValue="en" aria-label="Language">
              <option value="en">English</option>
              <option value="zh-Hans">简体中文</option>
              <option value="zh-Hant">繁體中文</option>
              <option value="ja">日本語</option>
              <option value="ko">한국어</option>
            </select>
          }
        />
        <PreferenceRow
          label="Custom provider order"
          description="Keep the same provider order across monitoring, credentials, diagnostics, and tray views."
          control={
            <button onClick={() => setProviderOrderOpen(true)} aria-label="Customize provider order">
              Customize
            </button>
          }
        />
        <PreferenceRow
          label="Launch at login"
          description="Open Quota Radar automatically when the desktop session starts."
          control={
            <MockSwitch
              enabled={launchAtLogin}
              onChange={() => setLaunchAtLogin((value) => !value)}
              label="Toggle launch at login"
            />
          }
        />
      </SettingsSection>

      <SettingsSection title="Updates and refresh">
        <PreferenceRow
          label="Check for updates"
          description="Check GitHub Releases and show release notes before installing."
          control={
            <MockSwitch
              enabled={updateCheck}
              onChange={() => setUpdateCheck((value) => !value)}
              label="Toggle update check"
            />
          }
        />
        <PreferenceRow
          label="Auto refresh"
          description="Refresh quota data on a schedule when the provider check is free."
          control={
            <select defaultValue={autoRefresh ? "30m" : "off"} aria-label="Auto refresh interval" onChange={(event) => setAutoRefresh(event.target.value !== "off")}>
              <option value="off">Off</option>
              <option value="30m">Every 30 minutes</option>
              <option value="1h">Every hour</option>
              <option value="6h">Every 6 hours</option>
            </select>
          }
        />
        <PreferenceRow
          label="Costly refresh"
          description="Allow scheduled checks for providers where refresh can consume search quota."
          control={
            <MockSwitch
              enabled={costlyRefresh}
              onChange={() => setCostlyRefresh((value) => !value)}
              label="Toggle costly refresh"
            />
          }
        />
      </SettingsSection>

      <SettingsSection title="Network and appearance">
        <PreferenceRow
          label="Network proxy"
          description="Choose direct, system, or custom proxy routing for provider requests."
          control={
            <select defaultValue="system" aria-label="Network proxy">
              <option value="system">Follow system</option>
              <option value="direct">Direct</option>
              <option value="custom">Custom</option>
            </select>
          }
        />
        <PreferenceRow
          label="Menu bar transparency"
          description="Adjust the tray popover material opacity."
          control={
            <input
              aria-label="Menu bar transparency"
              type="range"
              min="60"
              max="100"
              value={transparency}
              onChange={(event) => setTransparency(Number(event.target.value))}
            />
          }
        />
      </SettingsSection>

      <ProviderOrderDialog open={providerOrderOpen} onClose={() => setProviderOrderOpen(false)} />
    </div>
  );
}
