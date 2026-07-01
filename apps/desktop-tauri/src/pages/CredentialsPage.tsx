import { useEffect, useMemo, useRef, useState } from "react";
import { Download, Plus } from "lucide-react";
import { CredentialEditorDialog } from "../credentials/CredentialEditorDialog";
import { ProviderCredentialGroup } from "../credentials/ProviderCredentialGroup";
import { formatSystemErrorMessage, useTranslate } from "../i18n";
import {
  copyCredentialValue,
  createCredential,
  deleteCredential,
  importClaudeSettings,
  isTauriRuntime,
  listCredentials,
  updateCredential,
} from "../lib/tauriClient";
import { mockCredentials, providerRegistry } from "../shared/mockData";
import type {
  CredentialInput,
  CredentialUpdateInput,
  CredentialView,
  ProviderDefinition,
  StartWebAuthorizationHandler,
} from "../shared/types";

interface CredentialsPageProps {
  providers?: ProviderDefinition[];
  credentials?: CredentialView[];
  lastWebAuthorizationSaved?: CredentialView;
  onCredentialsChanged?: (credentials: CredentialView[]) => void;
  onStartWebAuthorization?: StartWebAuthorizationHandler;
}

export function CredentialsPage({
  providers = providerRegistry,
  credentials = mockCredentials,
  lastWebAuthorizationSaved,
  onCredentialsChanged,
  onStartWebAuthorization,
}: CredentialsPageProps) {
  const t = useTranslate();
  const [editorOpen, setEditorOpen] = useState(false);
  const [editingCredential, setEditingCredential] = useState<CredentialView>();
  const [visibleCredentials, setVisibleCredentials] = useState(credentials);
  const [importing, setImporting] = useState(false);
  const [importStatus, setImportStatus] = useState<{ tone: "success" | "error"; text: string }>();
  const handledSavedAuthorizationId = useRef<string>();

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

  useEffect(() => {
    if (!lastWebAuthorizationSaved || handledSavedAuthorizationId.current === lastWebAuthorizationSaved.id) {
      return;
    }

    handledSavedAuthorizationId.current = lastWebAuthorizationSaved.id;
    setVisibleCredentials((currentCredentials) => {
      const nextCredentials = currentCredentials.filter(
        (credential) => credential.id !== lastWebAuthorizationSaved.id,
      );
      return [...nextCredentials, lastWebAuthorizationSaved];
    });
    closeEditor();
  }, [lastWebAuthorizationSaved]);

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

  function openAddCredentialEditor() {
    setEditingCredential(undefined);
    setEditorOpen(true);
  }

  function openEditCredentialEditor(credential: CredentialView) {
    setEditingCredential(credential);
    setEditorOpen(true);
  }

  function closeEditor() {
    setEditorOpen(false);
    setEditingCredential(undefined);
  }

  async function handleSaveCredential(input: CredentialInput | CredentialUpdateInput) {
    const saved = editingCredential
      ? await updateCredential(input)
      : await createCredential(input as CredentialInput);

    if (isTauriRuntime()) {
      const storedCredentials = await listCredentials();
      const nextCredentials = storedCredentials.length > 0 ? storedCredentials : [saved];
      setVisibleCredentials(nextCredentials);
      onCredentialsChanged?.(nextCredentials);
      return;
    }

    const nextCredentials = visibleCredentials.filter((credential) => credential.id !== saved.id);
    const updatedCredentials = [...nextCredentials, saved];
    setVisibleCredentials(updatedCredentials);
    onCredentialsChanged?.(updatedCredentials);
  }

  async function handleCopyCredential(credential: CredentialView) {
    const secret = await copyCredentialValue(credential.id);
    await navigator.clipboard?.writeText(secret);
  }

  async function handleDeleteCredential(credential: CredentialView) {
    if (isTauriRuntime()) {
      const nextCredentials = await deleteCredential(credential.id);
      setVisibleCredentials(nextCredentials);
      onCredentialsChanged?.(nextCredentials);
      return;
    }

    const nextCredentials = visibleCredentials.filter((currentCredential) => currentCredential.id !== credential.id);
    setVisibleCredentials(nextCredentials);
    onCredentialsChanged?.(nextCredentials);
  }

  async function handleImportClaudeSettings() {
    setImporting(true);
    setImportStatus(undefined);
    try {
      const summary = await importClaudeSettings();
      if (summary.credentials.length > 0) {
        setVisibleCredentials(summary.credentials);
        onCredentialsChanged?.(summary.credentials);
      }
      setImportStatus({
        tone: "success",
        text: `${t("credentials.importSuccess")} ${t("credentials.importAdded")} ${summary.added}, ${t("credentials.importUpdated")} ${summary.updated}.`,
      });
    } catch (error) {
      setImportStatus({
        tone: "error",
        text: formatSystemErrorMessage(t("credentials.importFailed"), error, t),
      });
    } finally {
      setImporting(false);
    }
  }

  return (
    <div className="credentials-page">
      <section className="credential-action-panel">
        <div>
          <h2>{t("credentials.title")}</h2>
          <p>{t("credentials.description")}</p>
          <div className="credential-kind-legend" aria-label={t("credentials.types")}>
            <span>{t("credentialKind.webAuthorization")}</span>
            <span>{t("credentialKind.companionApiKey")}</span>
            <span>{t("credentialKind.apiKey")}</span>
          </div>
        </div>
        <div className="credential-action-buttons">
          <button onClick={openAddCredentialEditor}>
            <Plus size={15} />
            {t("credentials.add")}
          </button>
          <button onClick={handleImportClaudeSettings} disabled={importing}>
            <Download size={15} />
            {importing ? t("credentials.importing") : t("credentials.importClaudeSettings")}
          </button>
        </div>
      </section>
      {importStatus ? (
        <div className="credential-import-status" data-tone={importStatus.tone} role="status" aria-live="polite">
          {importStatus.text}
        </div>
      ) : null}
      <div className="credential-provider-list">
        {configuredProviders.map((group) => (
          <ProviderCredentialGroup
            key={group.provider.id}
            provider={group.provider}
            credentials={group.credentials}
            onCopyCredential={handleCopyCredential}
            onEditCredential={openEditCredentialEditor}
          />
        ))}
      </div>
      <CredentialEditorDialog
        open={editorOpen}
        onClose={closeEditor}
        credential={editingCredential}
        onDelete={handleDeleteCredential}
        onSave={handleSaveCredential}
        onStartWebAuthorization={onStartWebAuthorization}
        providers={providers}
      />
    </div>
  );
}
