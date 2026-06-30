import { Radar } from "lucide-react";
import { useTranslate } from "../i18n";

export function AboutPage() {
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
    </div>
  );
}
