import { useState } from "react";
import { mockSettings, updateSettings } from "../lib/tauriClient";
import { ProviderOrderDialog } from "../settings/ProviderOrderDialog";
import { PreferenceRow } from "../settings/PreferenceRow";
import { SettingsSection } from "../settings/SettingsSection";
import type { AppSettings } from "../shared/types";

function MockSwitch({
  enabled,
  onChange,
  label,
}: {
  enabled: boolean;
  onChange: () => void;
  label: string;
}) {
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

interface SettingsPageProps {
  settings?: AppSettings;
  onSettingsChange?: (settings: AppSettings) => void | Promise<void>;
  onMoveProvider?: (providerId: string, toIndex: number) => void | Promise<void>;
  onResetProviderOrder?: () => void | Promise<void>;
}

export function SettingsPage({
  settings: controlledSettings,
  onSettingsChange,
  onMoveProvider,
  onResetProviderOrder,
}: SettingsPageProps = {}) {
  const [providerOrderOpen, setProviderOrderOpen] = useState(false);
  const [localSettings, setLocalSettings] = useState(controlledSettings ?? mockSettings);
  const settings = controlledSettings ?? localSettings;

  function applySettings(nextSettings: AppSettings) {
    if (!controlledSettings) {
      setLocalSettings(nextSettings);
    }

    if (onSettingsChange) {
      void onSettingsChange(nextSettings);
      return;
    }

    void updateSettings(nextSettings).then(setLocalSettings);
  }

  return (
    <div className="settings-page">
      <SettingsSection title="General">
        <PreferenceRow
          label="Language"
          description="Select the interface language used by the desktop shell."
          control={
            <select
              value={settings.language}
              aria-label="Language"
              onChange={(event) => applySettings({ ...settings, language: event.target.value })}
            >
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
              enabled={settings.launchAtLogin}
              onChange={() =>
                applySettings({ ...settings, launchAtLogin: !settings.launchAtLogin })
              }
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
              enabled={settings.updateCheck}
              onChange={() =>
                applySettings({ ...settings, updateCheck: !settings.updateCheck })
              }
              label="Toggle update check"
            />
          }
        />
        <PreferenceRow
          label="Auto refresh"
          description="Refresh quota data on a schedule when the provider check is free."
          control={
            <select
              value={settings.autoRefreshInterval}
              aria-label="Auto refresh interval"
              onChange={(event) =>
                applySettings({
                  ...settings,
                  autoRefreshInterval: event.target
                    .value as AppSettings["autoRefreshInterval"],
                })
              }
            >
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
            <select
              value={settings.costlyRefreshInterval}
              aria-label="Costly refresh interval"
              onChange={(event) =>
                applySettings({
                  ...settings,
                  costlyRefreshInterval: event.target
                    .value as AppSettings["costlyRefreshInterval"],
                })
              }
            >
              <option value="off">Off</option>
              <option value="1h">Every hour</option>
              <option value="6h">Every 6 hours</option>
            </select>
          }
        />
      </SettingsSection>

      <SettingsSection title="Network and appearance">
        <PreferenceRow
          label="Network proxy"
          description="Choose direct, system, or custom proxy routing for provider requests."
          control={
            <select
              value={settings.proxy.mode}
              aria-label="Network proxy"
              onChange={(event) =>
                applySettings({
                  ...settings,
                  proxy: { ...settings.proxy, mode: event.target.value as AppSettings["proxy"]["mode"] },
                })
              }
            >
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
              value={settings.trayTransparency}
              onChange={(event) =>
                applySettings({ ...settings, trayTransparency: Number(event.target.value) })
              }
            />
          }
        />
      </SettingsSection>

      <ProviderOrderDialog
        open={providerOrderOpen}
        providerOrder={settings.providerOrder}
        onClose={() => setProviderOrderOpen(false)}
        onMoveProvider={onMoveProvider}
        onResetProviderOrder={onResetProviderOrder}
      />
    </div>
  );
}
