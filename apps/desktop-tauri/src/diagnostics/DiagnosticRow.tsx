import { StatusPill } from "../components/StatusPill";
import {
  formatCompactDateTime,
  formatCredentialStatus,
  formatSystemDisplayText,
  useLocale,
  useTranslate,
} from "../i18n";
import { credentialNeedsAttention } from "../shared/status";
import type { CredentialView } from "../shared/types";

interface DiagnosticRowProps {
  credential: CredentialView;
}

function httpStatusLabel(status: number | undefined, t: ReturnType<typeof useTranslate>) {
  return typeof status === "number" ? `HTTP ${status}` : t("diagnostics.noRequest");
}

function formatDate(value: string | undefined, locale: ReturnType<typeof useLocale>, t: ReturnType<typeof useTranslate>) {
  if (!value) {
    return t("common.notUpdated");
  }

  return formatCompactDateTime(value, locale);
}

export function DiagnosticRow({ credential }: DiagnosticRowProps) {
  const locale = useLocale();
  const t = useTranslate();
  const tone = credentialNeedsAttention(credential) ? "attention" : "healthy";

  return (
    <tr className="diagnostic-row">
      <td>
        <div className="credential-name">{credential.name}</div>
        <div className="credential-subtitle">{formatSystemDisplayText(credential.maskedValue, t)}</div>
      </td>
      <td>
        <StatusPill tone={tone} label={formatCredentialStatus(credential.status, t)} />
      </td>
      <td className="numeric-cell">{httpStatusLabel(credential.lastHttpStatus, t)}</td>
      <td className="numeric-cell">{formatDate(credential.lastUpdated, locale, t)}</td>
      <td>{credential.diagnosticMessage ? formatSystemDisplayText(credential.diagnosticMessage, t) : t("common.ready")}</td>
    </tr>
  );
}
