import { ExternalLink, Eye, X } from "lucide-react";
import { useMemo, useState } from "react";
import { useTranslate } from "../i18n";
import { providerRegistry } from "../shared/mockData";
import type {
  CredentialInput,
  CredentialKind,
  ProviderDefinition,
  StartWebAuthorizationHandler,
} from "../shared/types";

interface CredentialEditorDialogProps {
  open: boolean;
  onClose: () => void;
  providers?: ProviderDefinition[];
  onSave?: (input: CredentialInput) => Promise<void> | void;
  onStartWebAuthorization?: StartWebAuthorizationHandler;
}

export function CredentialEditorDialog({
  open,
  onClose,
  providers = providerRegistry,
  onSave,
  onStartWebAuthorization,
}: CredentialEditorDialogProps) {
  const t = useTranslate();
  const [providerId, setProviderId] = useState(providers[0]?.id ?? "");
  const [name, setName] = useState("");
  const [apiKey, setApiKey] = useState("");
  const [authorization, setAuthorization] = useState("");
  const [note, setNote] = useState("");
  const [revealed, setRevealed] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string>();
  const [authenticating, setAuthenticating] = useState(false);
  const [authorizationStatus, setAuthorizationStatus] = useState<{
    tone: "success" | "error";
    text: string;
  }>();
  const selectedProvider = useMemo(
    () => providers.find((provider) => provider.id === providerId) ?? providers[0],
    [providerId, providers],
  );

  if (!open) {
    return null;
  }

  const credentialKind: CredentialKind = authorization.trim() ? "dashboardCookie" : "apiKey";
  const secret = authorization.trim() || apiKey.trim();
  const defaultName = selectedProvider
    ? t("credentialEditor.defaultName").replace("{provider}", selectedProvider.displayName)
    : t("quota.credential");

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedProvider || !secret || saving) {
      return;
    }

    const credentialName = name.trim() || defaultName;
    setSaving(true);
    setSaveError(undefined);
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
    } catch (error) {
      setSaveError(`${t("credentialEditor.saveFailed")} ${errorMessage(error)}`);
    } finally {
      setSaving(false);
    }
  }

  async function handleStartWebAuthorization() {
    if (!selectedProvider || !onStartWebAuthorization || authenticating) {
      return;
    }

    setAuthenticating(true);
    setAuthorizationStatus(undefined);
    try {
      const credentialName = name.trim() || defaultName;
      const session = await onStartWebAuthorization(
        selectedProvider.id,
        makeCredentialId(selectedProvider.id, credentialName),
        credentialName,
      );
      if (session?.message) {
        setAuthorizationStatus({ tone: "success", text: session.message });
      }
    } catch (error) {
      setAuthorizationStatus({
        tone: "error",
        text: `${t("credentialEditor.webAuthorizationFailed")} ${
          error instanceof Error ? error.message : String(error)
        }`,
      });
    } finally {
      setAuthenticating(false);
    }
  }

  return (
    <div className="dialog-backdrop">
      <section className="credential-dialog" role="dialog" aria-label={t("credentialEditor.title")}>
        <header className="credential-dialog-header">
          <div>
            <h2>{t("credentialEditor.title")}</h2>
            <p>{t("credentialEditor.description")}</p>
          </div>
          <button aria-label={t("credentialEditor.close")} onClick={onClose}>
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
              {t("credentialEditor.name")}
              <input
                placeholder={defaultName}
                value={name}
                onChange={(event) => setName(event.target.value)}
              />
            </label>
            <label>
              {t("credentialEditor.apiKey")}
              <div className="secret-input">
                <input
                  aria-label={t("credentialEditor.apiKey")}
                  type={revealed ? "text" : "password"}
                  placeholder={t("credentialEditor.apiKeyPlaceholder")}
                  value={apiKey}
                  onChange={(event) => setApiKey(event.target.value)}
                />
                <button type="button" aria-label={t("credentialEditor.revealApiKey")} onClick={() => setRevealed((value) => !value)}>
                  <Eye size={15} />
                </button>
              </div>
            </label>
            <div className="credential-dialog-field">
              <div className="credential-auth-row">
                <span>{t("credentialEditor.webAuthorization")}</span>
                {selectedProvider?.supportsReauth ? (
                  <button
                    aria-label={`${t("credentialEditor.openWebLogin")} ${selectedProvider.displayName}`}
                    className="credential-auth-button"
                    disabled={authenticating}
                    onClick={handleStartWebAuthorization}
                    type="button"
                  >
                    <ExternalLink size={14} />
                    {authenticating
                      ? t("credentialEditor.openingWebLogin")
                      : t("credentialEditor.openWebLogin")}
                  </button>
                ) : null}
              </div>
              <textarea
                aria-label={t("credentialEditor.webAuthorization")}
                placeholder={t("credentialEditor.webAuthorizationPlaceholder")}
                value={authorization}
                onChange={(event) => setAuthorization(event.target.value)}
              />
              {authorizationStatus ? (
                <span
                  className="credential-auth-status"
                  data-tone={authorizationStatus.tone}
                  role="status"
                >
                  {authorizationStatus.text}
                </span>
              ) : null}
            </div>
            <label>
              {t("credentialEditor.note")}
              <input placeholder={t("credentialEditor.optional")} value={note} onChange={(event) => setNote(event.target.value)} />
            </label>
          </form>
        </div>
        {saveError ? (
          <div className="credential-save-status" data-tone="error" role="alert">
            {saveError}
          </div>
        ) : null}
        <footer className="credential-dialog-footer">
          <button onClick={onClose}>{t("credentialEditor.cancel")}</button>
          <button className="primary-button" disabled={!secret || saving} form="credential-editor-form" type="submit">
            {saving ? t("credentialEditor.saving") : t("credentials.add")}
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

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}
