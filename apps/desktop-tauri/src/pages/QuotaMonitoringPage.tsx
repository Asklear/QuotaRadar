import { ProviderCategorySection } from "../quota/ProviderCategorySection";
import { mockCredentials, providerRegistry } from "../shared/mockData";
import { buildProviderStats } from "../shared/selectors";
import type { CredentialView, ProviderCategory, ProviderDefinition } from "../shared/types";

const categoryOrder: ProviderCategory[] = ["AI Search", "LLM"];

interface QuotaMonitoringPageProps {
  providers?: ProviderDefinition[];
  credentials?: CredentialView[];
}

export function QuotaMonitoringPage({
  providers = providerRegistry,
  credentials = mockCredentials,
}: QuotaMonitoringPageProps) {
  const stats = buildProviderStats(providers, credentials);

  return (
    <div className="quota-page">
      {categoryOrder.map((category) => {
        const categoryStats = stats.filter((stat) => stat.provider.category === category);
        if (categoryStats.length === 0) {
          return null;
        }

        return <ProviderCategorySection key={category} category={category} stats={categoryStats} />;
      })}
    </div>
  );
}
