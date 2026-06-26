export type ProviderCategory = "AI Search" | "LLM";

export type CredentialKind =
  | "apiKey"
  | "dashboardCookie"
  | "adminCredential"
  | "storedAPIKeyOnly";

export type CredentialStatus =
  | "healthy"
  | "failed"
  | "expired"
  | "usageLimitExceeded"
  | "disabled"
  | "unknownQuotaUsable"
  | "notChecked"
  | "unsupported"
  | "noSubscribedPlan"
  | "manualRefreshOnly";

export interface ProviderDefinition {
  id: string;
  displayName: string;
  familyName: string;
  category: ProviderCategory;
  planType?: string;
  icon: string;
  dashboardUrl?: string;
  supportsReauth: boolean;
  supportsRefresh: boolean;
  quotaCheckConsumesSearchQuota: boolean;
  hidden?: boolean;
}

export interface QuotaWindow {
  name: "5h" | "week" | "month" | string;
  percentRemaining?: number;
  remainingText?: string;
  resetAt?: string;
}

export interface CredentialView {
  id: string;
  providerId: string;
  name: string;
  kind: CredentialKind;
  maskedValue: string;
  copyable: boolean;
  active: boolean;
  status: CredentialStatus;
  remaining?: number;
  limit?: number;
  remainingBadgeText: string;
  quotaLabel?: string;
  quotaWindows: QuotaWindow[];
  resetAt?: string;
  planEndsAt?: string;
  lastUpdated?: string;
  lastHttpStatus?: number;
  diagnosticMessage?: string;
  note?: string;
  linkedAuthorizationId?: string;
}

export interface CredentialInput {
  id: string;
  providerId: string;
  name: string;
  kind: CredentialKind;
  secret: string;
  linkedAuthorizationId?: string;
  note?: string;
}

export interface CredentialImportSummary {
  added: number;
  updated: number;
  credentials: CredentialView[];
}

export interface WebAuthorizationSession {
  providerId: string;
  targetCredentialId?: string;
  loginUrl?: string;
  message: string;
}

export type StartWebAuthorizationHandler = (
  providerId: string,
  targetCredentialId?: string,
) => Promise<WebAuthorizationSession> | WebAuthorizationSession | void;

export interface CapturedWebAuthorization {
  providerId: string;
  targetCredentialId?: string;
  name?: string;
  capturedFields: Record<string, unknown>;
}

export interface ProviderStats {
  provider: ProviderDefinition;
  credentials: CredentialView[];
  keyQuotaText: string;
  credentialPoolText: string;
  criticalTimeText: string;
  statusText: string;
  needsAttention: boolean;
}

export interface MenuSummary {
  availableCount: number;
  lowCount: number;
  failedCount: number;
  totalActiveCount: number;
}

export interface AppState {
  providers: ProviderDefinition[];
  credentials: CredentialView[];
}

export type RefreshMode = "manual" | "automatic" | "costlyAutomatic";

export type RefreshInterval = "off" | "30m" | "1h" | "6h";

export type ProxyMode = "system" | "direct" | "custom";

export interface ProxySettings {
  mode: ProxyMode;
  customUrl?: string;
}

export interface AppSettings {
  language: string;
  launchAtLogin: boolean;
  updateCheck: boolean;
  autoRefreshInterval: RefreshInterval;
  costlyRefreshInterval: RefreshInterval;
  proxy: ProxySettings;
  trayTransparency: number;
  providerOrder: string[];
}

export type UpdateStatus =
  | "idle"
  | "checking"
  | "available"
  | "upToDate"
  | "error"
  | "notImplemented";

export interface UpdateState {
  currentVersion: string;
  latestVersion?: string;
  status: UpdateStatus;
  releaseNotes?: string;
  lastCheckedAt?: string;
  errorMessage?: string;
}
