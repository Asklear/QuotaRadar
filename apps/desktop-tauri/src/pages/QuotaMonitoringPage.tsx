import { ProviderCategorySection } from "../quota/ProviderCategorySection";
import { useLocale, useTranslate } from "../i18n";
import { mockCredentials, providerRegistry } from "../shared/mockData";
import { buildProviderStats } from "../shared/selectors";
import type { CredentialView, ProviderCategory, ProviderDefinition } from "../shared/types";

const categoryOrder: ProviderCategory[] = ["AI Search", "LLM"];

interface QuotaMonitoringPageProps {
  providers?: ProviderDefinition[];
  credentials?: CredentialView[];
  onRefreshProvider?: (providerId: string) => void | Promise<void>;
  onStartWebAuthorization?: (providerId: string, targetCredentialId?: string) => void | Promise<void>;
}

export function QuotaMonitoringPage({
  providers = providerRegistry,
  credentials = mockCredentials,
  onRefreshProvider,
  onStartWebAuthorization,
}: QuotaMonitoringPageProps) {
  const locale = useLocale();
  const t = useTranslate();
  const stats = buildProviderStats(providers, credentials, locale);
  const supportedCount = providers.filter((provider) => !provider.hidden).length;
  const overviewSummary = t("quota.overviewSummary")
    .replace("{configured}", String(stats.length))
    .replace("{supported}", String(supportedCount));

  return (
    <div className="quota-page">
      <header className="quota-page-header">
        <h2>{t("quota.overviewTitle")}</h2>
        <p>{overviewSummary}</p>
      </header>
      {categoryOrder.map((category) => {
        const categoryStats = stats.filter((stat) => stat.provider.category === category);
        if (categoryStats.length === 0) {
          return null;
        }

        return (
          <ProviderCategorySection
            key={category}
            category={category}
            stats={categoryStats}
            onRefreshProvider={onRefreshProvider}
            onStartWebAuthorization={onStartWebAuthorization}
          />
        );
      })}
    </div>
  );
}
