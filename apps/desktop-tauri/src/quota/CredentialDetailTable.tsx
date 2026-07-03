import {
  formatCompactDateTime,
  formatCredentialKind,
  formatCredentialStatus,
  formatSystemDisplayText,
  useLocale,
  useTranslate,
} from "../i18n";
import { RotateCcw } from "lucide-react";
import { credentialNeedsAttention } from "../shared/status";
import type { CredentialView } from "../shared/types";
import { QuotaWindowDetails } from "../components/QuotaWindowDetails";
import { StatusPill } from "../components/StatusPill";

interface CredentialDetailTableProps {
  credentials: CredentialView[];
  onResetCodexQuota?: (credentialId: string) => void | Promise<void>;
}

export function CredentialDetailTable({
  credentials,
  onResetCodexQuota,
}: CredentialDetailTableProps) {
  const locale = useLocale();
  const t = useTranslate();

  return (
    <div className="credential-detail">
      <table className="credential-table">
        <thead>
          <tr>
            <th>{t("quota.credential")}</th>
            <th>{t("quota.remaining")}</th>
            <th>{t("quota.status")}</th>
            <th>{t("quota.lastUpdated")}</th>
          </tr>
        </thead>
        <tbody>
          {credentials.map((credential) => (
            <tr key={credential.id}>
              <td>
                <div className="credential-name">{credential.name}</div>
                <div className="credential-subtitle">
                  {formatSystemDisplayText(credential.maskedValue, t)} · {formatCredentialKind(credential.kind, t)}
                </div>
                <QuotaWindowDetails windows={credential.quotaWindows} />
              </td>
              <td className="numeric-cell">{formatSystemDisplayText(credential.remainingBadgeText, t)}</td>
              <td>
                <StatusPill
                  tone={credentialNeedsAttention(credential) ? "attention" : "healthy"}
                  label={formatCredentialStatus(credential.status, t)}
                />
              </td>
              <td className="timing-cell">
                <div>
                  {credential.lastUpdated
                    ? formatCompactDateTime(credential.lastUpdated, locale)
                    : t("common.notAvailable")}
                </div>
                {credential.resetAt ? (
                  <small>
                    {t("time.nextReset")} {formatCompactDateTime(credential.resetAt, locale)}
                  </small>
                ) : null}
                {credential.planEndsAt ? (
                  <small>
                    {t("time.planEnds")} {formatCompactDateTime(credential.planEndsAt, locale)}
                  </small>
                ) : null}
                {typeof credential.codexResetCreditsRemaining === "number" ? (
                  <small className="codex-reset-credit-row">
                    <span>
                      {t("codexResetCredits.remaining").replace(
                        "{count}",
                        String(credential.codexResetCreditsRemaining),
                      )}
                    </span>
                    <button
                      className="codex-reset-credit-button"
                      disabled={credential.codexResetCreditsRemaining <= 0}
                      aria-label={`${credential.name} ${t("codexResetCredits.resetAction")}`}
                      onClick={() => {
                        void onResetCodexQuota?.(credential.id);
                      }}
                    >
                      <RotateCcw size={12} />
                      {t("codexResetCredits.resetAction")}
                    </button>
                  </small>
                ) : null}
                {credential.codexResetCreditsEarliestExpiresAt ? (
                  <small>
                    {t("codexResetCredits.earliestExpiry").replace(
                      "{time}",
                      formatCompactDateTime(
                        credential.codexResetCreditsEarliestExpiresAt,
                        locale,
                      ),
                    )}
                  </small>
                ) : null}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
