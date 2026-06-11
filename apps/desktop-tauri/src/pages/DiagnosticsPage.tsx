import { DiagnosticProviderSection } from "../diagnostics/DiagnosticProviderSection";
import { mockCredentials, providerRegistry } from "../shared/mockData";
import type { CredentialView, ProviderCategory, ProviderDefinition } from "../shared/types";

const categoryOrder: ProviderCategory[] = ["AI Search", "LLM"];

interface DiagnosticsPageProps {
  providers?: ProviderDefinition[];
  credentials?: CredentialView[];
}

export function DiagnosticsPage({ providers = providerRegistry, credentials = mockCredentials }: DiagnosticsPageProps) {
  const groups = providers
    .map((provider) => ({
      provider,
      credentials: credentials.filter((credential) => credential.providerId === provider.id),
    }))
    .filter((group) => group.credentials.length > 0);

  return (
    <div className="diagnostics-page">
      {categoryOrder.map((category) => {
        const categoryGroups = groups.filter((group) => group.provider.category === category);
        if (categoryGroups.length === 0) {
          return null;
        }

        return (
          <section className="diagnostic-category" key={category}>
            <header className="diagnostic-category-header">
              <h1>{category}</h1>
              <p>Connectivity, authorization, and last request status only.</p>
            </header>
            {categoryGroups.map((group) => (
              <DiagnosticProviderSection
                key={group.provider.id}
                provider={group.provider}
                credentials={group.credentials}
              />
            ))}
          </section>
        );
      })}
    </div>
  );
}
