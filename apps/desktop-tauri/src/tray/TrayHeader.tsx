import { SlidersHorizontal } from "lucide-react";
import { AppMark } from "../components/AppMark";
import { useTranslate } from "../i18n";

interface TrayHeaderProps {
  onOpenSettings?: () => void;
}

export function TrayHeader({ onOpenSettings }: TrayHeaderProps) {
  const t = useTranslate();

  return (
    <header className="tray-header">
      <AppMark className="tray-mark" testId="tray-app-mark" />
      <div className="tray-title-block">
        <h1>{t("app.name")}</h1>
        <p>{t("tray.quote")}</p>
      </div>
      <button className="tray-settings-button" aria-label={t("nav.settings")} onClick={onOpenSettings}>
        <SlidersHorizontal size={16} strokeWidth={2.2} />
      </button>
    </header>
  );
}
