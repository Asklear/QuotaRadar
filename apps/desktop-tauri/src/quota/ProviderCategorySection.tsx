import { useState } from "react";
import { Cpu, Search } from "lucide-react";
import { useTranslate } from "../i18n";
import type { ProviderCategory, ProviderStats, StartWebAuthorizationHandler } from "../shared/types";
import { ProviderQuotaTable } from "./ProviderQuotaTable";

interface ProviderCategorySectionProps {
  category: ProviderCategory;
  stats: ProviderStats[];
  onRefreshProvider?: (providerId: string) => void | Promise<void>;
  onStartWebAuthorization?: StartWebAuthorizationHandler;
}

export function ProviderCategorySection({
  category,
  stats,
  onRefreshProvider,
  onStartWebAuthorization,
}: ProviderCategorySectionProps) {
  const t = useTranslate();
  const [expanded, setExpanded] = useState(true);
  const credentialCount = stats.reduce((total, stat) => total + stat.credentials.length, 0);
  const activeCount = stats.reduce(
    (total, stat) => total + stat.credentials.filter((credential) => credential.active).length,
    0,
  );
  const categoryTitle = category === "AI Search" ? t("category.aiSearch") : t("category.llm");
  const summary = t("quota.categorySummary")
    .replace("{providers}", String(stats.length))
    .replace("{credentials}", String(credentialCount));
  const activeSummary = t("quota.categoryActiveSummary").replace("{active}", String(activeCount));
  const icon = category === "AI Search" ? <Search size={17} /> : <Cpu size={17} />;

  return (
    <section className="quota-category" data-expanded={expanded}>
      <button className="quota-category-banner" onClick={() => setExpanded((value) => !value)}>
        <div className="quota-category-banner-content">
          <span className="quota-category-icon" aria-hidden="true">
            {icon}
          </span>
          <div>
            <h2>{categoryTitle}</h2>
            <p>{summary}</p>
          </div>
        </div>
        <span className="quota-category-active">{activeSummary}</span>
      </button>
      {expanded ? (
        <ProviderQuotaTable
          stats={stats}
          onRefreshProvider={onRefreshProvider}
          onStartWebAuthorization={onStartWebAuthorization}
        />
      ) : null}
    </section>
  );
}
