import { Eye, X } from "lucide-react";
import { useMemo, useState } from "react";
import { providerRegistry } from "../shared/mockData";
import type { CredentialInput, CredentialKind, ProviderDefinition } from "../shared/types";

interface CredentialEditorDialogProps {
  open: boolean;
  onClose: () => void;
  providers?: ProviderDefinition[];
  onSave?: (input: CredentialInput) => Promise<void> | void;
}

export function CredentialEditorDialog({
  open,
  onClose,
  providers = providerRegistry,
  onSave,
}: CredentialEditorDialogProps) {
  const [providerId, setProviderId] = useState(providers[0]?.id ?? "");
  const [name, setName] = useState("");
  const [apiKey, setApiKey] = useState("");
  const [authorization, setAuthorization] = useState("");
  const [note, setNote] = useState("");
  const [revealed, setRevealed] = useState(false);
  const [saving, setSaving] = useState(false);
  const selectedProvider = useMemo(
    () => providers.find((provider) => provider.id === providerId) ?? providers[0],
    [providerId, providers],
  );

  if (!open) {
    return null;
  }

  const credentialKind: CredentialKind = authorization.trim() ? "dashboardCookie" : "apiKey";
  const secret = authorization.trim() || apiKey.trim();
  const defaultName = selectedProvider ? `${selectedProvider.displayName} Credential` : "Credential";

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedProvider || !secret || saving) {
      return;
    }

    const credentialName = name.trim() || defaultName;
    setSaving(true);
    try {
      await onSave?.({
        id: makeCredentialId(selectedProvider.id, credentialName),
        providerId: selectedProvider.id,
        name: credentialName,
        kind: credentialKind,
        secret,
        note: note.trim() || undefined,
      });
      onClose();
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="dialog-backdrop">
      <section className="credential-dialog" role="dialog" aria-label="Add Credential">
        <header className="credential-dialog-header">
          <div>
            <h2>Add Credential</h2>
            <p>Choose a provider and save the credential used by Quota Radar.</p>
          </div>
          <button aria-label="Close editor" onClick={onClose}>
            <X size={16} />
          </button>
        </header>
        <div className="credential-dialog-body">
          <aside className="credential-dialog-provider-list">
            {providers.map((provider) => (
              <button
                key={provider.id}
                data-selected={provider.id === selectedProvider?.id}
                onClick={() => setProviderId(provider.id)}
                type="button"
              >
                {provider.displayName}
              </button>
            ))}
          </aside>
          <form className="credential-dialog-form" id="credential-editor-form" onSubmit={handleSubmit}>
            <label>
              Credential name
              <input
                placeholder={defaultName}
                value={name}
                onChange={(event) => setName(event.target.value)}
              />
            </label>
            <label>
              API key
              <div className="secret-input">
                <input
                  aria-label="API key"
                  type={revealed ? "text" : "password"}
                  placeholder="Paste API key"
                  value={apiKey}
                  onChange={(event) => setApiKey(event.target.value)}
                />
                <button type="button" aria-label="Reveal API key" onClick={() => setRevealed((value) => !value)}>
                  <Eye size={15} />
                </button>
              </div>
            </label>
            <label>
              Web login authorization
              <textarea
                placeholder="Paste captured authorization data or authenticate in a later backend phase"
                value={authorization}
                onChange={(event) => setAuthorization(event.target.value)}
              />
            </label>
            <label>
              Note
              <input placeholder="Optional" value={note} onChange={(event) => setNote(event.target.value)} />
            </label>
          </form>
        </div>
        <footer className="credential-dialog-footer">
          <button onClick={onClose}>Cancel</button>
          <button className="primary-button" disabled={!secret || saving} form="credential-editor-form" type="submit">
            {saving ? "Saving" : "Add"}
          </button>
        </footer>
      </section>
    </div>
  );
}

function makeCredentialId(providerId: string, name: string) {
  const slug = name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
  return `${providerId}-${slug || "credential"}`;
}
