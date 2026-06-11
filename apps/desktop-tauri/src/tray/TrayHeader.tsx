import { Radar, SlidersHorizontal } from "lucide-react";
import { translate } from "../i18n";

export function TrayHeader() {
  return (
    <header className="tray-header">
      <div className="tray-mark" aria-hidden="true">
        <Radar size={21} strokeWidth={2.2} />
      </div>
      <div className="tray-title-block">
        <h1>{translate("app.name")}</h1>
        <p>{translate("tray.quote")}</p>
      </div>
      <button className="tray-settings-button" aria-label={translate("nav.settings")}>
        <SlidersHorizontal size={16} strokeWidth={2.2} />
      </button>
    </header>
  );
}
