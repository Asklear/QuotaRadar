import { ProviderIcon } from "../components/ProviderIcon";
import { formatProviderPlanType, useTranslate } from "../i18n";
import type { CredentialView, ProviderDefinition } from "../shared/types";
import { DiagnosticRow } from "./DiagnosticRow";

interface DiagnosticProviderSectionProps {
  provider: ProviderDefinition;
  credentials: CredentialView[];
}

export function DiagnosticProviderSection({ provider, credentials }: DiagnosticProviderSectionProps) {
  const t = useTranslate();
  const categoryLabel = provider.category === "AI Search" ? t("category.aiSearch") : t("category.llm");

  return (
    <section className="diagnostic-provider-section" aria-label={`${provider.displayName} diagnostics`}>
      <header className="diagnostic-provider-header">
        <div className="provider-cell">
          <ProviderIcon provider={provider} />
          <div>
            <h2>{provider.displayName}</h2>
            <p>
              {categoryLabel}
              {provider.planType ? ` · ${formatProviderPlanType(provider.planType, t)}` : ""}
            </p>
          </div>
        </div>
        <span>
          {credentials.length} {t("quota.credential")}
        </span>
      </header>
      <table className="diagnostic-table">
        <thead>
          <tr>
            <th>{t("quota.credential")}</th>
            <th>{t("diagnostics.health")}</th>
            <th>{t("diagnostics.http")}</th>
            <th>{t("diagnostics.updated")}</th>
            <th>{t("diagnostics.message")}</th>
          </tr>
        </thead>
        <tbody>
          {credentials.map((credential) => (
            <DiagnosticRow key={credential.id} credential={credential} />
          ))}
        </tbody>
      </table>
    </section>
  );
}
