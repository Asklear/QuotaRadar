import type { ReactNode } from "react";

interface SidebarNavItemProps {
  icon: ReactNode;
  label: string;
  active?: boolean;
}

export function SidebarNavItem({ icon, label, active = false }: SidebarNavItemProps) {
  return (
    <button className="sidebar-nav-item" data-active={active}>
      <span className="sidebar-nav-icon" aria-hidden="true">
        {icon}
      </span>
      <span>{label}</span>
    </button>
  );
}
