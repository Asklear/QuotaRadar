import { DiagnosticProviderSection } from "../diagnostics/DiagnosticProviderSection";
import { mockCredentials, providerRegistry } from "../shared/mockData";
import type { ProviderCategory } from "../shared/types";

const categoryOrder: ProviderCategory[] = ["AI Search", "LLM"];

export function DiagnosticsPage() {
  const groups = providerRegistry
    .map((provider) => ({
      provider,
      credentials: mockCredentials.filter((credential) => credential.providerId === provider.id),
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
