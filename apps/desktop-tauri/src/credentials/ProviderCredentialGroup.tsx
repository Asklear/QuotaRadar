import { useState } from "react";
import { ProviderIcon } from "../components/ProviderIcon";
import type { CredentialView, ProviderDefinition } from "../shared/types";
import { CredentialRow } from "./CredentialRow";

interface ProviderCredentialGroupProps {
  provider: ProviderDefinition;
  credentials: CredentialView[];
  onCopyCredential?: (credential: CredentialView) => void;
}

export function ProviderCredentialGroup({ provider, credentials, onCopyCredential }: ProviderCredentialGroupProps) {
  const [expanded, setExpanded] = useState(true);
  const activeCount = credentials.filter((credential) => credential.active).length;
  const credentialLabel = credentials.length === 1 ? "credential" : "credentials";

  return (
    <section className="credential-provider-group">
      <button
        className="credential-provider-banner"
        aria-label={`${provider.displayName} ${activeCount} active ${credentials.length} ${credentialLabel}`}
        onClick={() => setExpanded((value) => !value)}
      >
        <ProviderIcon provider={provider} />
        <div className="credential-provider-title">
          <strong>{provider.displayName}</strong>
          <span>
            {provider.category}
            {provider.planType ? ` · ${provider.planType}` : ""}
          </span>
        </div>
        <span className="credential-provider-pill">{activeCount} active</span>
        <span className="credential-provider-pill">{credentials.length} {credentialLabel}</span>
      </button>
      {expanded ? (
        <div className="credential-row-list">
          {credentials.map((credential) => (
            <CredentialRow key={credential.id} credential={credential} onCopy={onCopyCredential} />
          ))}
        </div>
      ) : null}
    </section>
  );
}
