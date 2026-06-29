import { useState } from "react";
import { ProviderIcon } from "../components/ProviderIcon";
import { useTranslate } from "../i18n";
import type { CredentialView, ProviderDefinition } from "../shared/types";
import { CredentialRow } from "./CredentialRow";

interface ProviderCredentialGroupProps {
  provider: ProviderDefinition;
  credentials: CredentialView[];
  onCopyCredential?: (credential: CredentialView) => void;
  onEditCredential?: (credential: CredentialView) => void;
}

export function ProviderCredentialGroup({
  provider,
  credentials,
  onCopyCredential,
  onEditCredential,
}: ProviderCredentialGroupProps) {
  const t = useTranslate();
  const [expanded, setExpanded] = useState(true);
  const activeCount = credentials.filter((credential) => credential.active).length;
  const categoryLabel = provider.category === "AI Search" ? t("category.aiSearch") : t("category.llm");

  return (
    <section className="credential-provider-group">
      <button
        className="credential-provider-banner"
        aria-label={`${provider.displayName} ${activeCount} ${t("credential.active")} ${credentials.length} ${t("quota.credential")}`}
        onClick={() => setExpanded((value) => !value)}
      >
        <ProviderIcon provider={provider} />
        <div className="credential-provider-title">
          <strong>{provider.displayName}</strong>
          <span>
            {categoryLabel}
            {provider.planType ? ` · ${provider.planType}` : ""}
          </span>
        </div>
        <span className="credential-provider-pill">
          {activeCount} {t("credential.active")}
        </span>
        <span className="credential-provider-pill">
          {credentials.length} {t("quota.credential")}
        </span>
      </button>
      {expanded ? (
        <div className="credential-row-list">
          {credentials.map((credential) => (
            <CredentialRow
              key={credential.id}
              credential={credential}
              onCopy={onCopyCredential}
              onEdit={onEditCredential}
            />
          ))}
        </div>
      ) : null}
    </section>
  );
}
