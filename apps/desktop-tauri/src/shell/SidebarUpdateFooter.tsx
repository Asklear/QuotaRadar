import { RefreshCw } from "lucide-react";

export function SidebarUpdateFooter() {
  return (
    <footer className="sidebar-footer">
      <div>
        <div className="sidebar-version">v0.0.0 preview</div>
        <div className="sidebar-update-status">Up to date</div>
      </div>
      <button className="sidebar-icon-button" aria-label="Check for updates" title="Check for updates">
        <RefreshCw size={15} strokeWidth={2.2} />
      </button>
    </footer>
  );
}
