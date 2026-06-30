import { RefreshCw } from "lucide-react";
import { useTranslate } from "../i18n";
import { mockUpdateState } from "../lib/tauriClient";
import type { UpdateState } from "../shared/types";

interface SidebarUpdateFooterProps {
  updateState?: UpdateState;
  onCheckForUpdates?: () => void;
}

export function SidebarUpdateFooter({
  updateState = mockUpdateState,
  onCheckForUpdates,
}: SidebarUpdateFooterProps) {
  const t = useTranslate();
  const buildLabel = import.meta.env.VITE_QUOTARADAR_BUILD_LABEL?.trim();

  return (
    <footer className="sidebar-footer">
      <div>
        <div className="sidebar-version">{t("update.versionPreview").replace("{version}", updateState.currentVersion)}</div>
        {buildLabel ? <div className="sidebar-build-label">{buildLabel}</div> : null}
        <div className="sidebar-update-status">{updateStatusLabel(updateState, t)}</div>
      </div>
      <button
        className="sidebar-icon-button"
        aria-label={t("update.check")}
        title={t("update.check")}
        onClick={onCheckForUpdates}
      >
        <RefreshCw size={15} strokeWidth={2.2} />
      </button>
    </footer>
  );
}

function updateStatusLabel(updateState: UpdateState, t: ReturnType<typeof useTranslate>) {
  switch (updateState.status) {
    case "available":
      return t("update.available").replace("{version}", updateState.latestVersion ?? "").trim();
    case "checking":
      return t("update.checking");
    case "error":
      return updateState.errorMessage ?? t("update.error");
    case "notImplemented":
      return t("update.installerPending");
    case "idle":
      return t("update.notChecked");
    case "upToDate":
    default:
      return t("update.upToDate");
  }
}
