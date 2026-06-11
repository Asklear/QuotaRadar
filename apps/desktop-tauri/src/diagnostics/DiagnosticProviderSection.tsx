import { ProviderIcon } from "../components/ProviderIcon";
import type { CredentialView, ProviderDefinition } from "../shared/types";
import { DiagnosticRow } from "./DiagnosticRow";

interface DiagnosticProviderSectionProps {
  provider: ProviderDefinition;
  credentials: CredentialView[];
}

export function DiagnosticProviderSection({ provider, credentials }: DiagnosticProviderSectionProps) {
  return (
    <section className="diagnostic-provider-section" aria-label={`${provider.displayName} diagnostics`}>
      <header className="diagnostic-provider-header">
        <div className="provider-cell">
          <ProviderIcon provider={provider} />
          <div>
            <h2>{provider.displayName}</h2>
            <p>
              {provider.category}
              {provider.planType ? ` · ${provider.planType}` : ""}
            </p>
          </div>
        </div>
        <span>{credentials.length} credential{credentials.length === 1 ? "" : "s"}</span>
      </header>
      <table className="diagnostic-table">
        <thead>
          <tr>
            <th>Credential</th>
            <th>Health</th>
            <th>HTTP</th>
            <th>Updated</th>
            <th>Message</th>
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
