import { StatusPill } from "../components/StatusPill";
import { credentialNeedsAttention } from "../shared/status";
import type { CredentialView } from "../shared/types";

interface DiagnosticRowProps {
  credential: CredentialView;
}

function statusLabel(status: CredentialView["status"]) {
  switch (status) {
    case "healthy":
      return "Healthy";
    case "failed":
      return "Failed";
    case "expired":
      return "Expired";
    case "usageLimitExceeded":
      return "Usage limit";
    case "disabled":
      return "Disabled";
    case "unknownQuotaUsable":
      return "Usable";
    case "notChecked":
      return "Not checked";
    case "unsupported":
      return "Unsupported";
    case "noSubscribedPlan":
      return "No plan";
    case "manualRefreshOnly":
      return "Manual";
    default:
      return status;
  }
}

function httpStatusLabel(status?: number) {
  return typeof status === "number" ? `HTTP ${status}` : "No request";
}

function formatDate(value?: string) {
  if (!value) {
    return "Not updated";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}

export function DiagnosticRow({ credential }: DiagnosticRowProps) {
  const tone = credentialNeedsAttention(credential) ? "attention" : "healthy";

  return (
    <tr className="diagnostic-row">
      <td>
        <div className="credential-name">{credential.name}</div>
        <div className="credential-subtitle">{credential.maskedValue}</div>
      </td>
      <td>
        <StatusPill tone={tone} label={statusLabel(credential.status)} />
      </td>
      <td className="numeric-cell">{httpStatusLabel(credential.lastHttpStatus)}</td>
      <td className="numeric-cell">{formatDate(credential.lastUpdated)}</td>
      <td>{credential.diagnosticMessage ?? "Ready"}</td>
    </tr>
  );
}
