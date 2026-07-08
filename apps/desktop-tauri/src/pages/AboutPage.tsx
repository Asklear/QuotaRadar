import { Radar, RefreshCw } from "lucide-react";
import { useTranslate } from "../i18n";
import { mockUpdateState } from "../lib/tauriClient";
import type { UpdateState } from "../shared/types";
import { updateStatusLabel } from "../shell/SidebarUpdateFooter";

interface AboutPageProps {
  updateState?: UpdateState;
  onCheckForUpdates?: () => void;
}

export function AboutPage({
  updateState = mockUpdateState,
  onCheckForUpdates,
}: AboutPageProps) {
  const t = useTranslate();

  return (
    <div className="about-page">
      <section className="about-card">
        <div className="about-mark" aria-hidden="true">
          <Radar size={34} strokeWidth={2.1} />
        </div>
        <div>
          <h1>{t("app.name")}</h1>
          <p>{t("about.subtitle")}</p>
        </div>
        <dl>
          <div>
            <dt>{t("about.platformTarget")}</dt>
            <dd>{t("about.platformTargetValue")}</dd>
          </div>
          <div>
            <dt>{t("about.implementationStage")}</dt>
            <dd>{t("about.implementationStageValue")}</dd>
          </div>
          <div>
            <dt>{t("about.dataPolicy")}</dt>
            <dd>{t("about.dataPolicyValue")}</dd>
          </div>
        </dl>
      </section>
      <section className="about-update-panel">
        <div>
          <h2>{t("settings.checkForUpdates")}</h2>
          <p>{t("settings.checkForUpdatesDescription")}</p>
        </div>
        <dl>
          <div>
            <dt>{t("update.versionPreview").replace("{version}", updateState.currentVersion)}</dt>
            <dd>{updateStatusLabel(updateState, t)}</dd>
          </div>
        </dl>
        <button type="button" onClick={onCheckForUpdates}>
          <RefreshCw size={15} />
          {t("update.check")}
        </button>
      </section>
    </div>
  );
}
