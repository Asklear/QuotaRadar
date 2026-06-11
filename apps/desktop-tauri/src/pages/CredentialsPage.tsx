import { useEffect, useMemo, useState } from "react";
import { Download, Plus } from "lucide-react";
import { CredentialEditorDialog } from "../credentials/CredentialEditorDialog";
import { ProviderCredentialGroup } from "../credentials/ProviderCredentialGroup";
import { copyCredentialValue, createCredential, isTauriRuntime, listCredentials } from "../lib/tauriClient";
import { mockCredentials, providerRegistry } from "../shared/mockData";
import type { CredentialInput, CredentialView, ProviderDefinition } from "../shared/types";

interface CredentialsPageProps {
  providers?: ProviderDefinition[];
  credentials?: CredentialView[];
}

export function CredentialsPage({ providers = providerRegistry, credentials = mockCredentials }: CredentialsPageProps) {
  const [editorOpen, setEditorOpen] = useState(false);
  const [visibleCredentials, setVisibleCredentials] = useState(credentials);

  useEffect(() => {
    if (!isTauriRuntime()) {
      setVisibleCredentials(credentials);
      return;
    }

    let cancelled = false;

    void listCredentials().then((storedCredentials) => {
      if (!cancelled) {
        setVisibleCredentials(storedCredentials.length > 0 ? storedCredentials : credentials);
      }
    });

    return () => {
      cancelled = true;
    };
  }, [credentials]);

  const configuredProviders = useMemo(
    () =>
      providers
        .map((provider) => ({
          provider,
          credentials: visibleCredentials.filter((credential) => credential.providerId === provider.id),
        }))
        .filter((group) => group.credentials.length > 0),
    [providers, visibleCredentials],
  );

  async function handleSaveCredential(input: CredentialInput) {
    const saved = await createCredential(input);

    if (isTauriRuntime()) {
      const storedCredentials = await listCredentials();
      setVisibleCredentials(storedCredentials.length > 0 ? storedCredentials : [saved]);
      return;
    }

    setVisibleCredentials((currentCredentials) => {
      const nextCredentials = currentCredentials.filter((credential) => credential.id !== saved.id);
      return [...nextCredentials, saved];
    });
  }

  async function handleCopyCredential(credential: CredentialView) {
    const secret = await copyCredentialValue(credential.id);
    await navigator.clipboard?.writeText(secret);
  }

  return (
    <div className="credentials-page">
      <section className="credential-action-panel">
        <div>
          <h2>Credentials</h2>
          <p>Add credentials, import environment files, and manage copy-safe API keys.</p>
          <div className="credential-kind-legend" aria-label="Credential types">
            <span>Web Login Authorization</span>
            <span>Companion API Key</span>
            <span>API Key</span>
          </div>
        </div>
        <div className="credential-action-buttons">
          <button onClick={() => setEditorOpen(true)}>
            <Plus size={15} />
            Add Credential
          </button>
          <button>
            <Download size={15} />
            Import .env
          </button>
        </div>
      </section>
      <div className="credential-provider-list">
        {configuredProviders.map((group) => (
          <ProviderCredentialGroup
            key={group.provider.id}
            provider={group.provider}
            credentials={group.credentials}
            onCopyCredential={handleCopyCredential}
          />
        ))}
      </div>
      <CredentialEditorDialog
        open={editorOpen}
        onClose={() => setEditorOpen(false)}
        onSave={handleSaveCredential}
        providers={providers}
      />
    </div>
  );
}
