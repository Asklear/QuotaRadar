import { useState } from "react";
import { mockSettings, updateSettings } from "../lib/tauriClient";
import { ProviderOrderDialog } from "../settings/ProviderOrderDialog";
import { PreferenceRow } from "../settings/PreferenceRow";
import { SettingsSection } from "../settings/SettingsSection";
import type { AppSettings } from "../shared/types";
import { useTranslate } from "../i18n";
import type { MessageKey } from "../i18n";

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

const languageOptions: Array<{ value: string; labelKey: MessageKey }> = [
  { value: "en", labelKey: "language.en" },
  { value: "zh-Hans", labelKey: "language.zhHans" },
  { value: "zh-Hant", labelKey: "language.zhHant" },
  { value: "ja", labelKey: "language.ja" },
  { value: "ko", labelKey: "language.ko" },
];

export function SettingsPage({
  settings: controlledSettings,
  onSettingsChange,
  onMoveProvider,
  onResetProviderOrder,
}: SettingsPageProps = {}) {
  const t = useTranslate();
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
      <SettingsSection title={t("settings.general")}>
        <PreferenceRow
          label={t("settings.language")}
          description={t("settings.languageDescription")}
          control={
            <select
              value={settings.language}
              aria-label={t("settings.language")}
              onChange={(event) => applySettings({ ...settings, language: event.target.value })}
            >
              {languageOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {t(option.labelKey)}
                </option>
              ))}
            </select>
          }
        />
        <PreferenceRow
          label={t("settings.providerOrder")}
          description={t("settings.providerOrderDescription")}
          control={
            <button onClick={() => setProviderOrderOpen(true)} aria-label={t("settings.customizeProviderOrder")}>
              {t("settings.customize")}
            </button>
          }
        />
        <PreferenceRow
          label={t("settings.launchAtLogin")}
          description={t("settings.launchAtLoginDescription")}
          control={
            <MockSwitch
              enabled={settings.launchAtLogin}
              onChange={() =>
                applySettings({ ...settings, launchAtLogin: !settings.launchAtLogin })
              }
              label={t("settings.toggleLaunchAtLogin")}
            />
          }
        />
      </SettingsSection>

      <SettingsSection title={t("settings.updatesRefresh")}>
        <PreferenceRow
          label={t("settings.checkForUpdates")}
          description={t("settings.checkForUpdatesDescription")}
          control={
            <MockSwitch
              enabled={settings.updateCheck}
              onChange={() =>
                applySettings({ ...settings, updateCheck: !settings.updateCheck })
              }
              label={t("settings.toggleUpdateCheck")}
            />
          }
        />
        <PreferenceRow
          label={t("settings.autoRefresh")}
          description={t("settings.autoRefreshDescription")}
          control={
            <select
              value={settings.autoRefreshInterval}
              aria-label={t("settings.autoRefreshInterval")}
              onChange={(event) =>
                applySettings({
                  ...settings,
                  autoRefreshInterval: event.target
                    .value as AppSettings["autoRefreshInterval"],
                })
              }
            >
              <option value="off">{t("interval.off")}</option>
              <option value="30m">{t("interval.30m")}</option>
              <option value="1h">{t("interval.1h")}</option>
              <option value="6h">{t("interval.6h")}</option>
            </select>
          }
        />
        <PreferenceRow
          label={t("settings.costlyRefresh")}
          description={t("settings.costlyRefreshDescription")}
          control={
            <select
              value={settings.costlyRefreshInterval}
              aria-label={t("settings.costlyRefreshInterval")}
              onChange={(event) =>
                applySettings({
                  ...settings,
                  costlyRefreshInterval: event.target
                    .value as AppSettings["costlyRefreshInterval"],
                })
              }
            >
              <option value="off">{t("interval.off")}</option>
              <option value="1h">{t("interval.1h")}</option>
              <option value="6h">{t("interval.6h")}</option>
            </select>
          }
        />
      </SettingsSection>

      <SettingsSection title={t("settings.networkAppearance")}>
        <PreferenceRow
          label={t("settings.networkProxy")}
          description={t("settings.networkProxyDescription")}
          control={
            <select
              value={settings.proxy.mode}
              aria-label={t("settings.networkProxy")}
              onChange={(event) =>
                applySettings({
                  ...settings,
                  proxy: { ...settings.proxy, mode: event.target.value as AppSettings["proxy"]["mode"] },
                })
              }
            >
              <option value="system">{t("proxy.system")}</option>
              <option value="direct">{t("proxy.direct")}</option>
              <option value="custom">{t("proxy.custom")}</option>
            </select>
          }
        />
        <PreferenceRow
          label={t("settings.trayTransparency")}
          description={t("settings.trayTransparencyDescription")}
          control={
            <input
              aria-label={t("settings.trayTransparency")}
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
