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
