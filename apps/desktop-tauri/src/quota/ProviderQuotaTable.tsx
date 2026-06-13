import { useState } from "react";
import { useTranslate } from "../i18n";
import type { ProviderStats } from "../shared/types";
import { ProviderQuotaRow } from "./ProviderQuotaRow";

interface ProviderQuotaTableProps {
  stats: ProviderStats[];
  onRefreshProvider?: (providerId: string) => void | Promise<void>;
  onStartWebAuthorization?: (providerId: string, targetCredentialId?: string) => void | Promise<void>;
}

export function ProviderQuotaTable({
  stats,
  onRefreshProvider,
  onStartWebAuthorization,
}: ProviderQuotaTableProps) {
  const t = useTranslate();
  const [expandedProviderId, setExpandedProviderId] = useState<string | null>(null);

  return (
    <div className="provider-list" role="table">
      <div className="provider-list-header" role="row">
        <span>{t("quota.provider")}</span>
        <span>{t("quota.keyQuota")}</span>
        <span>{t("quota.credentialPool")}</span>
        <span>{t("quota.criticalTime")}</span>
        <span>{t("quota.status")}</span>
        <span>{t("quota.actions")}</span>
      </div>
      <div className="provider-list-body" role="rowgroup">
        {stats.map((stat) => (
          <ProviderQuotaRow
            key={stat.provider.id}
            stat={stat}
            expanded={expandedProviderId === stat.provider.id}
            onToggle={() =>
              setExpandedProviderId((current) => (current === stat.provider.id ? null : stat.provider.id))
            }
            onRefreshProvider={onRefreshProvider}
            onStartWebAuthorization={onStartWebAuthorization}
          />
        ))}
      </div>
    </div>
  );
}
